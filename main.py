#!/usr/bin/env python3

import jinja2

if __name__ == "__main__":
    env = jinja2.Environment(
        loader = jinja2.PackageLoader(__name__, "templates"),
    )

    hello_template = env.get_template("template.lds")

    default_values = {
        "memories" : [
            {
                "name" : "ram",
                "permissions" : "wxa!ri)",
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
                "name" : "ram_init",
                "type" : "PT_LOAD",
            },
            {
                "name" : "itim_init",
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
        "text_in_itim" : False,
        "ramrodata" : False,
        "num_harts" : 1,
        "boot_hart" : 1,
        "chicken_bit" : 0,
        "init" : {
            "vma" : "flash",
            "lma" : "flash",
            "phdr" : "flash",
        },
        "text" : {
            "vma" : "flash",
            "lma" : "flash",
            "phdr" : "flash",
        },
        "rodata" : {
            "vma" : "flash",
            "lma" : "flash",
            "phdr" : "flash",
        },
        "ctors" : {
            "vma" : "flash",
            "lma" : "flash",
            "phdr" : "flash",
        },
        "itim" : {
            "vma" : "ram",
            "lma" : "flash",
            "source_phdr" : "flash",
            "dest_phdr" : "itim_init",
        },
        "data" : {
            "vma" : "ram",
            "lma" : "flash",
            "source_phdr" : "flash",
            "dest_phdr" : "ram_init",
        },
        "bss" : {
            "vma" : "ram",
            "lma" : "flash",
            "phdr" : "ram_init",
        },
        "stack" : {
            "vma" : "ram",
            "lma" : "flash",
            "phdr" : "ram_init",
        },
        "heap" : {
            "vma" : "ram",
            "lma" : "flash",
            "phdr" : "ram_init",
        },
    }

    print(hello_template.render(default_values))

