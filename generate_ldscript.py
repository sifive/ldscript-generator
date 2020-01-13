#!/usr/bin/env python3
# Copyright (c) 2020 SiFive Inc.
# SPDX-License-Identifier: Apache-2.0

"""
Generate linker scripts from devicetree source files
"""

import argparse
import sys

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

class Region:
    """Describes a memory region requested by the Devicetree"""
    # pylint: disable=too-few-public-methods
    def __init__(self, node, base, size, name):
        self.node = node
        self.base = base
        self.size = size
        self.name = name

    def template_value(self, permissions):
        """Format as a dict for templating"""
        return {
            "name": self.name,
            "permissions": permissions,
            "base": "0x%x" % self.base,
            "size": "0x%x" % self.size,
        }

def get_chosen_region(dts, chosen_property_name, name):
    """Extract the requested address region from the chosen property"""
    chosen_property = dts.chosen(chosen_property_name)

    if chosen_property:
        chosen_node = dts.get_by_reference(chosen_property[0])
        chosen_range = chosen_property[1]
        chosen_offset = chosen_property[2]

        reg = chosen_node.get_reg()[chosen_range]

        base = reg[0] - chosen_offset
        size = reg[1] - chosen_offset

        return Region(chosen_node, base, size, name)
    return None

def get_ram(dts):
    """
    Get the RAM from the devicetree, if one is chosen
    """
    region = get_chosen_region(dts, "metal,ram", RAM_MEMORY_NAME)
    if region is not None:
        path = region.node.get_path()
        print("\tRAM:  0x%08x-0x%08x (%s)" % (region.base, region.base+region.size, path))
    return region

def get_itim(dts):
    """
    Get the ITIM from the devicetree, if one is chosen
    """
    region = get_chosen_region(dts, "metal,itim", ITIM_MEMORY_NAME)
    if region is not None:
        path = region.node.get_path()
        print("\tITIM: 0x%08x-0x%08x (%s)" % (region.base, region.base+region.size, path))
    return region

def get_itim_size(dts):
    """Get the size of the ITIM from the Devicetree"""
    region = get_chosen_region(dts, "metal,itim", ITIM_MEMORY_NAME)
    if region is not None:
        return region.size
    return 0

def get_rom(dts):
    """
    Get the ROM from the devicetree, if one is chosen
    """
    region = get_chosen_region(dts, "metal,entry", ROM_MEMORY_NAME)
    if region is not None:
        path = region.node.get_path()
        print("\tROM:  0x%08x-0x%08x (%s)" % (region.base, region.base+region.size, path))
    return region

def get_memories(dts):
    """
    Extract the memory regions and turn them into the mapping to implement
    in the linker script.
    """
    # pylint: disable=too-many-branches
    regions = [x for x in [get_ram(dts), get_itim(dts), get_rom(dts)] if x is not None]

    if len(regions) == 0:
        print("No memory regions are available")
        sys.exit(1)
    elif len(regions) == 1:
        region = regions[0]
        if region.name != RAM_MEMORY_NAME:
            # If we only have one region, it has to be RAM
            region.name = RAM_MEMORY_NAME
        ram, rom, itim = [{
            "vma": region.name,
            "lma": region.name
        }] * 3
        return [region.template_value("rwaxi")], ram, rom, itim
    elif len(regions) == 2:
        memories = []
        for region in regions:
            if region.name == ROM_MEMORY_NAME:
                memories.append(region.template_value("rxai!w"))
                rom = {
                    "lma": region.name,
                    "vma": region.name
                }
            elif region.name == RAM_MEMORY_NAME:
                memories.append(region.template_value("rwai!x"))
                ram, itim = [{
                    "lma": ROM_MEMORY_NAME,
                    "vma": region.name
                }] * 2
            else:
                print("RAM or ROM missing")
                sys.exit(1)
        return memories, ram, rom, itim
    else:
        memories = []
        for region in regions:
            if region.name == ROM_MEMORY_NAME:
                memories.append(region.template_value("rxai!w"))
                rom = {
                    "lma": region.name,
                    "vma": region.name
                }
            elif region.name == RAM_MEMORY_NAME:
                memories.append(region.template_value("rwai!x"))
                ram = {
                    "lma": ROM_MEMORY_NAME,
                    "vma": region.name
                }
            elif region.name == ITIM_MEMORY_NAME:
                memories.append(region.template_value("rwxai"))
                itim = {
                    "lma": ROM_MEMORY_NAME,
                    "vma": region.name
                }
        return memories, ram, rom, itim

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
        layout = "ramrodata"
    elif parsed_args.scratchpad:
        layout = "scratchpad"
    else:
        layout = "default"

    template = env.get_template("%s.lds" % layout)
    print("Generating linker script with %s layout" % layout)

    return template

def main(argv):
    """
    Parse arguments, extract data, and render the linker script to file
    """
    parsed_args = parse_arguments(argv)

    template = get_template(parsed_args)

    dts = pydevicetree.Devicetree.parseFile(parsed_args.dts, followIncludes=True)

    print("Selected memories in design:")
    memories, ram, rom, itim = get_memories(dts)

    text_in_itim = False
    if parsed_args.ramrodata and get_itim_size(dts) >= MAGIC_RAMRODATA_TEXT_THRESHOLD:
        text_in_itim = True
        print(".text section included in ITIM")
    elif parsed_args.ramrodata:
        print(".text section included in ROM")

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
    main(sys.argv[1:])
