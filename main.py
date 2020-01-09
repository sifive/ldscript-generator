#!/usr/bin/env python3

import jinja2

if __name__ == "__main__":
    env = jinja2.Environment(
        loader = jinja2.PackageLoader(__name__, "templates"),
    )

    default_template = env.get_template("default.lds")
    ramrodata_template = env.get_template("ramrodata.lds")
    scratchpad_template = env.get_template("scratchpad.lds")

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

    print(default_template.render(values))
