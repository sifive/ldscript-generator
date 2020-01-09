OUTPUT_ARCH("riscv")

ENTRY(_enter)

MEMORY
{
    {%- for memory in memories %}
        {{ memory.name }} ({{ memory.permissions }}) : ORIGIN = {{ memory.base }}, LENGTH = {{ memory.size }}
    {%- endfor %}
}

PHDRS
{
    {%- for phdr in phdrs %}
        {{ phdr.name }} {{ phdr.type }}
    {%- endfor %}
}

SECTIONS
{
    /* Each hart is allocated its own stack of size __stack_size. This value
     * can be overriden at build-time by adding the following to CFLAGS:
     *
     *     -Xlinker --defsym=__stack_size=0xf00
     *
     * where 0xf00 can be replaced with the value of your choice.
     *
     * __stack_size is PROVIDE-ed as a symbol so that initialization code
     * initializes the stack pointers for each hart at the right offset from
     * the _sp symbol.
     */
    __stack_size = DEFINED(__stack_size) ? __stack_size : {{ default_stack_size }};
    PROVIDE(__stack_size = __stack_size);

    /* The size of the heap can be overriden at build-time by adding the
     * following to CFLAGS:
     *
     *     -Xlinker --defsym=__heap_size=0xf00
     *
     * where 0xf00 can be replaced with the value of your choice.
     */
    __heap_size = DEFINED(__heap_size) ? __heap_size : {{ default_heap_size }};

    /* The boot hart sets which hart runs the pre-main initialization routines,
     * including copying .data into RAM, zeroing the BSS region, running
     * constructors, etc. After initialization, the boot hart is also the only
     * hart which runs application code unless the application overrides the
     * secondary_main() function to start execution on secondary harts.
     */
    PROVIDE(__metal_boot_hart = {{ boot_hart }});

    /* The chicken bit is used by pre-main initialization to enable/disable
     * certain core features */
    PROVIDE(__metal_chicken_bit = {{ chicken_bit }});

    {% block rom %}

    {% block itim %}

    {% block ram %}
}
