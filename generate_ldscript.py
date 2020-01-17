#!/usr/bin/env python3
# Copyright (c) 2020 SiFive Inc.
# SPDX-License-Identifier: Apache-2.0

"""Generate linker scripts from devicetree source files"""

import argparse
import sys

import jinja2
import pydevicetree

from memory_map import get_memories, get_load_map

TEMPLATES_PATH = "templates"

# Sets the threshold size of the ITIM at or above which the "ramrodata" layout
# places the text section into the ITIM
MAGIC_RAMRODATA_TEXT_THRESHOLD = 0x8000

def missingvalue(message):
    """
    Raise an UndefinedError
    This function is made available to the template so that it can report
    when required values are not present and cause template rendering to
    fail.
    """
    raise jinja2.UndefinedError(message)

def parse_arguments(argv):
    """Parse the arguments into a dictionary with argparse"""
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
    """Initialize jinja2 and return the right template"""
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

def print_memories(memories):
    """Report chosen memories to stdout"""
    print("Using layout:")
    for _, memory in memories.items():
        end = memory["base"] + memory["length"] - 1
        print("\t%4s: 0x%08x-0x%08x (%s)" % (memory["name"], memory["base"], end, memory["path"]))

def get_itim_length(memories):
    """Get the length of the itim, if it exists"""
    if "itim" in memories and "length" in memories["itim"]:
        return memories["itim"]["length"]
    return 0

def main(argv):
    """Parse arguments, extract data, and render the linker script to file"""
    parsed_args = parse_arguments(argv)

    template = get_template(parsed_args)

    dts = pydevicetree.Devicetree.parseFile(parsed_args.dts, followIncludes=True)

    memories = get_memories(dts)
    print_memories(memories)

    ram, rom, itim = get_load_map(memories)

    if parsed_args.scratchpad:
        # Put all rom contents in ram
        ram["lma"] = "ram"
        itim["lma"] = "ram"
        rom = ram

    text_in_itim = False
    if parsed_args.ramrodata and get_itim_length(memories) >= MAGIC_RAMRODATA_TEXT_THRESHOLD:
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
        "memories" : list(memories.values()),
        "default_stack_size" : "0x400",
        "default_heap_size" : "0x800",
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
