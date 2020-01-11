#!/usr/bin/env python3
# Copyright (c) 2020 SiFive Inc.
# SPDX-License-Identifier: Apache-2.0

"""
Generate linker scripts from devicetree source files
"""

import argparse
import jinja2
import pydevicetree

TEMPLATES_PATH = "templates"

# Sets the threshold size of the ITIM at or above which the "ramrodata" layout
# places the text section into the ITIM
MAGIC_RAMRODATA_TEXT_THRESHOLD = 0x8000

ROM_MEMORY_NAME = "rom"
RAM_MEMORY_NAME = "ram"
ITIM_MEMORY_NAME = "itim"

def missingvalue(message):
    """ Raise an UndefinedError
        This function is made available to the template so that it can report
        when required values are not present and cause template rendering to
        fail.
    """
    raise jinja2.UndefinedError(message)

def get_ram(dts):
    """
    Get the RAM from the devicetree, if one is chosen
    """
    metal_ram = dts.chosen("metal,ram")
    if metal_ram:
        ram = metal_ram[0]
        chosen_range = metal_ram[1]
        chosen_offset = metal_ram[2]
        reg_array = dts.get_by_reference(ram).get_reg()
        reg = reg_array[chosen_range]
        return {
            "name" : RAM_MEMORY_NAME,
            "permissions" : "wxa!ri",
            "base" : "0x%x" % (reg[0] + chosen_offset),
            "size" : "0x%x" % (reg[1] - chosen_offset)
            }
    return None

def get_itim(dts):
    """
    Get the ITIM from the devicetree, if one is chosen
    """
    metal_itim = dts.chosen("metal,itim")
    if metal_itim:
        itim = metal_itim[0]
        chosen_range = metal_itim[1]
        chosen_offset = metal_itim[2]
        reg_array = dts.get_by_reference(itim).get_reg()
        reg = reg_array[chosen_range]
        return {
            "name" : ITIM_MEMORY_NAME,
            "permissions" : "wxa!ri",
            "base" : "0x%x" % (reg[0] + chosen_offset),
            "size" : "0x%x" % (reg[1] - chosen_offset)
            }
    return None

def get_itim_size(dts):
    """
    Get the size of the ITIM, if it exists
    """
    metal_itim = dts.chosen("metal,itim")
    if metal_itim:
        itim = metal_itim[0]
        chosen_range = metal_itim[1]
        chosen_offset = metal_itim[2]
        reg_array = dts.get_by_reference(itim).get_reg()
        reg = reg_array[chosen_range]
        return reg[1] - chosen_offset
    return 0

def get_rom(dts):
    """
    Get the ROM from the devicetree, if one is chosen
    """
    metal_entry = dts.chosen("metal,entry")
    if metal_entry:
        rom = metal_entry[0]
        chosen_range = metal_entry[1]
        chosen_offset = metal_entry[2]
        reg_array = dts.get_by_reference(rom).get_reg()
        reg = reg_array[chosen_range]
        return {
            "name" : ROM_MEMORY_NAME,
            "permissions" : "rxa!wi",
            "base" : "0x%x" % (reg[0] + chosen_offset),
            "size" : "0x%x" % (reg[1] - chosen_offset)
            }
    return None

def parse_arguments(argv):
    """
    Parse the arguments into a dictionary with argparse
    """
    arg_parser = argparse.ArgumentParser(description="Generate linker scripts from Devicetrees")

    arg_parser.add_argument("-d", "--dts", required=True,
                            help="The path to the Devicetree for the target")
    arg_parser.add_argument("-o", "--output", required=True,
                            type=argparse.FileType('w'),
                            help="The path of the linker script file to output")
    group = arg_parser.add_mutually_exclusive_group()
    group.add_argument("--scratchpad", action="store_true",
                       help="Emits a linker script with the scratchpad layout")
    group.add_argument("--ramrodata", action="store_true",
                       help="Emits a linker script with the ramrodata layout")

    return arg_parser.parse_args(argv)

def get_template(parsed_args):
    """
    Initialize jinja2 and return the right template
    """
    env = jinja2.Environment(
        loader=jinja2.PackageLoader(__name__, TEMPLATES_PATH),
        )
    # Make the missingvalue() function available in the template so that the
    # template fails to render if we don't provide the values it needs.
    env.globals["missingvalue"] = missingvalue

    if parsed_args.ramrodata:
        template = env.get_template("ramrodata.lds")
    elif parsed_args.scratchpad:
        template = env.get_template("scratchpad.lds")
    else:
        template = env.get_template("default.lds")

    return template

def main(argv):
    """
    Parse arguments, extract data, and render the linker script to file
    """
    parsed_args = parse_arguments(argv)

    template = get_template(parsed_args)

    dts = pydevicetree.Devicetree.parseFile(parsed_args.dts, followIncludes=True)

    memories = [x for x in [get_ram(dts), get_itim(dts), get_rom(dts)] if x is not None]

    if get_rom(dts) is not None:
        rom = {"vma": ROM_MEMORY_NAME, "lma": ROM_MEMORY_NAME}
        ram = {"vma": RAM_MEMORY_NAME, "lma": ROM_MEMORY_NAME}
    else:
        rom = {"vma": RAM_MEMORY_NAME, "lma": RAM_MEMORY_NAME}
        ram = {"vma": RAM_MEMORY_NAME, "lma": RAM_MEMORY_NAME}

    text_in_itim = False
    if get_itim(dts) is not None:
        itim = {"vma": ITIM_MEMORY_NAME, "lma": "itim"}
    if parsed_args.ramrodata and get_itim_size(dts) >= MAGIC_RAMRODATA_TEXT_THRESHOLD:
        text_in_itim = True
    else:
        itim = {"vma": RAM_MEMORY_NAME, "lma": RAM_MEMORY_NAME}

    harts = dts.get_by_path("/cpus").children
    chosenboothart = dts.chosen("metal,boothart")
    if chosenboothart:
        boot_hart = dts.get_by_reference(chosenboothart[0]).get_reg()[0][0]
    elif len(harts) > 1:
        boot_hart = 1
    else:
        boot_hart = 0

    values = {
        "memories" : memories,
        "default_stack_size" : "0x400",
        "default_heap_size" : "0x400",
        "num_harts" : len(harts),
        "boot_hart" : boot_hart,
        "chicken_bit" : 1,
        "text_in_itim" : text_in_itim,
        "rom" : rom,
        "itim" : itim,
        "ram" : ram,
    }

    parsed_args.output.write(template.render(values))
    parsed_args.output.close()

if __name__ == "__main__":
    import sys
    main(sys.argv[1:])
