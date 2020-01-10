#!/usr/bin/env python3

import argparse
import jinja2
import pydevicetree

TEMPLATES_PATH = "templates"

def missingvalue(message):
    """ Raise an UndefinedError
        This function is made available to the template so that it can report
        when required values are not present and cause template rendering to
        fail.
    """
    raise jinja2.UndefinedError(message)

def get_ram(dts):
    pass

def get_itim(dts):
    pass

def get_rom(dts):
    pass

def render_default(env, values):
    default_template = env.get_template("default.lds")

    return default_template.render(values)

def main(argv):
    arg_parser = argparse.ArgumentParser(description="Generate linker scripts from Devicetrees")

    arg_parser.add_argument("-d", "--dts", required=True,
                            help="The path to the Devicetree for the target")
    arg_parser.add_argument("-l", "--linker", required=True,
                            type=argparse.FileType('w'),
                            help="The path of the linker script to output")
    arg_parser.add_argument("--scratchpad", help="Emits a linker script with the scratchpad layout")
    arg_parser.add_argument("--ramrodata", help="Emits a linker script with the ramrodata layout")

    parsed_args = arg_parser.parse_args(argv)

    env = jinja2.Environment(
        loader = jinja2.PackageLoader(__name__, TEMPLATES_PATH),
    )
    # Make the missingvalue() function available in the template so that the
    # template fails to render if we don't provide the values it needs.
    env.globals["missingvalue"] = missingvalue

    memories = [
            {
                "name" : "ram",
                "permissions" : "wxa!ri",
                "base" : "0x80000000",
                "size" : "0x4000",
            },
            {
                "name" : "flash",
                "permissions" : "rxai!w",
                "base" : "0x20010000",
                "size" : "0x6a120",
            },
        ]

    values = {
        "memories" : memories,
        "default_stack_size" : "0x400",
        "default_heap_size" : "0x400",
        "num_harts" : 1,
        "boot_hart" : 0,
        "chicken_bit" : 1,
        "rom" : {
            "vma" : "flash",
            "lma" : "flash",
        },
        "itim" : {
            "vma" : "ram",
            "lma" : "flash",
        },
        "ram" : {
            "vma" : "ram",
            "lma" : "flash",
        },
    }

    parsed_args.linker.write(render_default(env, values))
    parsed_args.linker.close()

if __name__ == "__main__":
    import sys
    main(sys.argv[1:])
