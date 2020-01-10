#!/usr/bin/env python3

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
        reg_array = dts.get_by_reference(ram).get_reg()
        reg = reg_array[0]
        return {
            "name" : RAM_MEMORY_NAME,
            "permissions" : "wxa!ri",
            "base" : "0x%x" % reg[0],
            "size" : "0x%x" % reg[1]
            }
    return None

def get_itim(dts):
    """
    Get the ITIM from the devicetree, if one is chosen
    """
    metal_ram = dts.chosen("metal,itim")
    if metal_ram:
        ram = metal_ram[0]
        reg_array = dts.get_by_reference(ram).get_reg()
        reg = reg_array[0]
        return {
            "name" : ITIM_MEMORY_NAME,
            "permissions" : "wxa!ri",
            "base" : "0x%x" % reg[0],
            "size" : "0x%x" % reg[1]
            }
    return None

def get_rom(dts):
    """
    Get the ROM from the devicetree, if one is chosen
    """
    metal_ram = dts.chosen("metal,rom")
    if metal_ram:
        ram = metal_ram[0]
        reg_array = dts.get_by_reference(ram).get_reg()
        reg = reg_array[0]
        return {
            "name" : ROM_MEMORY_NAME,
            "permissions" : "rxa!wi",
            "base" : "0x%x" % reg[0],
            "size" : "0x%x" % reg[1]
            }
    return None

def render_default(env, values):
    """
    Render the default linker script
    """
    default_template = env.get_template("default.lds")

    return default_template.render(values)

def render_ramrodata(env, values):
    """
    Render the ramrodata linker script
    """
    ramrodata_template = env.get_template("ramrodata.lds")

    return ramrodata_template.render(values)

def render_scratchpad(env, values):
    """
    Render the scratchpad linker script
    """
    scratchpad_template = env.get_template("scratchpad.lds")

    return scratchpad_template.render(values)

def main(argv):
    """
    Parse arguments, extract data, and render the linker script to file
    """
    arg_parser = argparse.ArgumentParser(description="Generate linker scripts from Devicetrees")

    arg_parser.add_argument("-d", "--dts", required=True,
                            help="The path to the Devicetree for the target")
    arg_parser.add_argument("-l", "--linker", required=True,
                            type=argparse.FileType('w'),
                            help="The path of the linker script to output")
    group = arg_parser.add_mutually_exclusive_group()
    group.add_argument("--scratchpad", action="store_true",
                       help="Emits a linker script with the scratchpad layout")
    group.add_argument("--ramrodata", action="store_true",
                       help="Emits a linker script with the ramrodata layout")

    parsed_args = arg_parser.parse_args(argv)

    env = jinja2.Environment(
        loader=jinja2.PackageLoader(__name__, TEMPLATES_PATH),
        )
    # Make the missingvalue() function available in the template so that the
    # template fails to render if we don't provide the values it needs.
    env.globals["missingvalue"] = missingvalue

    dts = pydevicetree.Devicetree.parseFile(parsed_args.dts, followIncludes=True)

    memories = [x for x in [get_ram(dts), get_itim(dts), get_rom(dts)] if x is not None]

    if get_rom(dts) is not None:
        rom = {"vma": ROM_MEMORY_NAME, "lma": ROM_MEMORY_NAME}
        ram = {"vma": RAM_MEMORY_NAME, "lma": ROM_MEMORY_NAME}
    else:
        rom = {"vma": RAM_MEMORY_NAME, "lma": RAM_MEMORY_NAME}
        ram = {"vma": RAM_MEMORY_NAME, "lma": RAM_MEMORY_NAME}

    if get_itim(dts) is not None:
        itim = {"vma": ITIM_MEMORY_NAME, "lma": "itim"}
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
        "text_in_itim" : False,
        "rom" : rom,
        "itim" : itim,
        "ram" : ram,
    }

    if parsed_args.ramrodata:
        itim = get_itim(dts)
        if int(itim["size"], base=16) >= MAGIC_RAMRODATA_TEXT_THRESHOLD:
            values["text_in_itim"] = True
        parsed_args.linker.write(render_ramrodata(env, values))
    elif parsed_args.scratchpad:
        parsed_args.linker.write(render_scratchpad(env, values))
    else:
        parsed_args.linker.write(render_default(env, values))
    parsed_args.linker.close()

if __name__ == "__main__":
    import sys
    main(sys.argv[1:])
