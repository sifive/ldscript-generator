# ldscript-generator

This is a python tool based on pydevicetree
([GitHub](https://github.com/sifive/pydevicetree)/[PyPI](https://pypi.org/project/pydevicetree/))
which generates linker scripts for Freedom Metal applications.

## Usage

```
usage: generate_ldscript.py [-h] -d DTS -o OUTPUT [--scratchpad | --ramrodata]

Generate linker scripts from Devicetrees

optional arguments:
  -h, --help            show this help message and exit
  -d DTS, --dts DTS     The path to the Devicetree for the target
  -o OUTPUT, --output OUTPUT
                        The path of the linker script file to output
  --scratchpad          Emits a linker script with the scratchpad layout
  --ramrodata           Emits a linker script with the ramrodata layout
```

## Copyright and License

Copyright (c) 2019 SiFive Inc.

The contents of this repository are distributed according to the terms described in the LICENSE
file.
