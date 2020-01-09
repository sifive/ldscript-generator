#!/usr/bin/env python3

import jinja2

if __name__ == "__main__":
    env = jinja2.Environment(
        loader = jinja2.PackageLoader(__name__, "templates"),
    )

    default_template = env.get_template("default.lds")
    ramrodata_template = env.get_template("ramrodata.lds")
    scratchpad_template = env.get_template("scratchpad.lds")

    values = {
        "memories" : [
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
        ],
        "phdrs" : [
            {
                "name" : "flash",
                "type" : "PT_LOAD",
            },
            {
                "name" : "ram",
                "type" : "PT_LOAD",
            },
            {
                "name" : "itim",
                "type" : "PT_LOAD",
            },
        ],
        "default_stack_size" : "0x400",
        "default_heap_size" : "0x400",
        "num_harts" : 2,
        "boot_hart" : 0,
        "chicken_bit" : 0,
        "rom" : {
            "vma" : "flash",
            "lma" : "flash",
            "phdr" : "flash",
        },
        "itim" : {
            "vma" : "ram",
            "lma" : "flash",
            "source_phdr" : "flash",
            "dest_phdr" : "itim",
        },
        "ram" : {
            "vma" : "ram",
            "lma" : "flash",
            "source_phdr" : "flash",
            "dest_phdr" : "ram",
        },
    }

    print("Default:")
    print(default_template.render(values))
    print("\nramrodata:")
    print(ramrodata_template.render(values))
    print("\nscratchpad:")
    print(scratchpad_template.render(values))
