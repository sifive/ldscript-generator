/* Copyright (c) 2020 SiFive Inc. */
/* SPDX-License-Identifier: Apache-2.0 */
{# Checks to make sure that required template values are provided #}
{% if rom.vma is undefined %}
    {{ missingvalue("Cannot render linker script, romable regions don't specify lma/vma!") }}
{% endif %}
{% if itim.lma is undefined or itim.vma is undefined %}
    {{ missingvalue("Cannot render linker script, itimable regions don't specify lma/vma!") }}
{% endif %}
{% if ram.lma is undefined or ram.vma is undefined %}
    {{ missingvalue("Cannot render linker script, ramable regions don't specify lma/vma!") }}
{% endif %}
{% if num_harts is undefined %}
    {{ missingvalue("Cannot render linker script, num_harts is not specified!") }}
{% endif %}
OUTPUT_ARCH("riscv")

{% block description %}{% endblock %}

ENTRY(_enter)

MEMORY
{
{% for memory in memories %}
    {{ memory.name }} ({{ memory.attributes }}) : ORIGIN = {{ memory.base_hex }}, LENGTH = {{ memory.length_hex }}
{% else %}
    {{ missingvalue("No memories are defined, cannot render linker script!") }}
{% endfor %}
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
    __stack_size = DEFINED(__stack_size) ? __stack_size : {{ default_stack_size|default("0x400") }};
    PROVIDE(__stack_size = __stack_size);

    /* The size of the heap can be overriden at build-time by adding the
     * following to CFLAGS:
     *
     *     -Xlinker --defsym=__heap_size=0xf00
     *
     * where 0xf00 can be replaced with the value of your choice.
     *
     * Altertatively, the heap can be grown to fill the entire remaining region
     * of RAM by adding the following to CFLAGS:
     *
     *     -Xlinker --defsym=__heap_max=1
     *
     * Note that depending on the memory layout, the bitness (32/64bit) of the
     * target, and the code model in use, this might cause a relocation error.
     */
    __heap_size = DEFINED(__heap_size) ? __heap_size : {{ default_heap_size|default("0x800") }};

    /* The boot hart sets which hart runs the pre-main initialization routines,
     * including copying .data into RAM, zeroing the BSS region, running
     * constructors, etc. After initialization, the boot hart is also the only
     * hart which runs application code unless the application overrides the
     * secondary_main() function to start execution on secondary harts.
     */
    PROVIDE(__metal_boot_hart = {{ boot_hart|default(0) }});

    /* The chicken bit is used by pre-main initialization to enable/disable
     * certain core features */
    PROVIDE(__metal_chicken_bit = {{ chicken_bit|default(0) }});

    /* ROM SECTION
     *
     * The following sections contain data which lives in read-only memory, if
     * such memory is present in the design, for the entire duration of program
     * execution.
     */

    .init : {
        /* The _enter symbol is placed in the .text.metal.init.enter section
         * and must be placed at the beginning of the program */
        KEEP (*(.text.metal.init.enter))
        KEEP (*(.text.metal.init.*))
        KEEP (*(SORT_NONE(.init)))
        KEEP (*(.text.libgloss.start))
    } >{{ rom.vma }}

{% if not text_in_itim %}
    .text : {
        *(.text.unlikely .text.unlikely.*)
        *(.text.startup .text.startup.*)
        *(.text .text.*)
        *(.gnu.linkonce.t.*)
    } >{{ rom.vma }}
{% endif %}

    .fini : {
        KEEP (*(SORT_NONE(.fini)))
    } >{{ rom.vma }}

{% if not ramrodata %}
    .rodata : {
        *(.rdata)
        *(.rodata .rodata.*)
        *(.gnu.linkonce.r.*)
        . = ALIGN(8);
        *(.srodata.cst16)
        *(.srodata.cst8)
        *(.srodata.cst4)
        *(.srodata.cst2)
        *(.srodata .srodata.*)
    } >{{ rom.vma }}
{% endif %}

    .preinit_array : ALIGN(8) {
        PROVIDE_HIDDEN (__preinit_array_start = .);
        KEEP (*(.preinit_array))
        PROVIDE_HIDDEN (__preinit_array_end = .);
    } >{{ rom.vma }}

    .init_array : ALIGN(8) {
        PROVIDE_HIDDEN (__init_array_start = .);
        KEEP (*(SORT_BY_INIT_PRIORITY(.init_array.*) SORT_BY_INIT_PRIORITY(.ctors.*)))
        KEEP (*(.init_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .ctors))
        PROVIDE_HIDDEN (__init_array_end = .);
        PROVIDE_HIDDEN ( metal_constructors_start = .);
        KEEP (*(SORT_BY_INIT_PRIORITY(.metal.init_array.*)));
        KEEP (*(.metal.init_array));
        PROVIDE_HIDDEN ( metal_constructors_end = .);
    } >{{ rom.vma }}

    .fini_array : ALIGN(8) {
        PROVIDE_HIDDEN (__fini_array_start = .);
        KEEP (*(SORT_BY_INIT_PRIORITY(.fini_array.*) SORT_BY_INIT_PRIORITY(.dtors.*)))
        KEEP (*(.fini_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .dtors))
        PROVIDE_HIDDEN (__fini_array_end = .);
        PROVIDE_HIDDEN ( metal_destructors_start = .);
        KEEP (*(SORT_BY_INIT_PRIORITY(.metal.fini_array.*)));
        KEEP (*(.metal.fini_array));
        PROVIDE_HIDDEN ( metal_destructors_end = .);
    } >{{ rom.vma }}

    .ctors : {
        KEEP (*crtbegin.o(.ctors))
        KEEP (*crtbegin?.o(.ctors))
        KEEP (*(EXCLUDE_FILE (*crtend.o *crtend?.o ) .ctors))
        KEEP (*(SORT(.ctors.*)))
        KEEP (*(.ctors))
        KEEP (*(.metal.ctors .metal.ctors.*))
    } >{{ rom.vma }}

    .dtors : {
        KEEP (*crtbegin.o(.dtors))
        KEEP (*crtbegin?.o(.dtors))
        KEEP (*(EXCLUDE_FILE (*crtend.o *crtend?.o ) .dtors))
        KEEP (*(SORT(.dtors.*)))
        KEEP (*(.dtors))
        KEEP (*(.metal.dtors .metal.dtors.*))
    } >{{ rom.vma }}

    /* ITIM SECTION
     *
     * The following sections contain data which is copied from read-only
     * memory into an instruction tightly-integrated memory (ITIM), if one
     * is present in the design, during pre-main program initialization.
     *
     * Generally, the data copied into the ITIM should be performance-critical
     * functions which benefit from low instruction-fetch latency.
     */

    .itim : ALIGN(8) {
{% if text_in_itim %}
        /* The .text sections are placed in the ITIM to improve the performance
         * of all post-init and non-constructor application code. Note that
         * this may cause the program to fail to link if the ITIM is not large
         * enough to contain the entire .text section. */
        *(.text.unlikely .text.unlikely.*)
        *(.text.startup .text.startup.*)
        *(.text .text.*)
        *(.gnu.linkonce.t.*)
{% endif %}
        *(.itim .itim.*)
    } >{{ itim.vma }} AT>{{ itim.lma }}

    PROVIDE( metal_segment_itim_source_start = LOADADDR(.itim) );
    PROVIDE( metal_segment_itim_target_start = ADDR(.itim) );
    PROVIDE( metal_segment_itim_target_end = ADDR(.itim) + SIZEOF(.itim) );

    /* RAM SECTION
     *
     * The following sections contain data which is copied from read-only
     * memory into a read-write-capable memory such as data tightly-integrated
     * memory (DTIM) or another main memory, as well as the BSS, stack, and
     * heap.
     */

    .data : ALIGN(8) {
        *(.data .data.*)
        *(.gnu.linkonce.d.*)
{% if ramrodata %}
        /* Read-only data is placed in RAM to improve performance, since
         * read-only memory generally has higher latency than RAM */
        *(.rdata)
        *(.rodata .rodata.*)
        *(.gnu.linkonce.r.*)
{% endif %}
        . = ALIGN(8);
        PROVIDE( __global_pointer$ = . + 0x800 );
        *(.sdata .sdata.* .sdata2.*)
        *(.gnu.linkonce.s.*)
        . = ALIGN(8);
{% if ramrodata %}
        *(.srodata.cst16)
        *(.srodata.cst8)
        *(.srodata.cst4)
        *(.srodata.cst2)
        *(.srodata .srodata.*)
{% endif %}
    } >{{ ram.vma }} AT>{{ ram.lma }}

    PROVIDE( metal_segment_data_source_start = LOADADDR(.data) );
    PROVIDE( metal_segment_data_target_start = ADDR(.data) );
    PROVIDE( metal_segment_data_target_end = ADDR(.data) + SIZEOF(.data) );

    .bss : ALIGN(8) {
        *(.sbss*)
        *(.gnu.linkonce.sb.*)
        *(.bss .bss.*)
        *(.gnu.linkonce.b.*)
        *(COMMON)
    } >{{ ram.vma }}

    PROVIDE( metal_segment_bss_source_start = LOADADDR(.bss) );
    PROVIDE( metal_segment_bss_target_start = ADDR(.bss) );
    PROVIDE( metal_segment_bss_target_end = ADDR(.bss) + SIZEOF(.bss) );

    .stack : {
        PROVIDE(metal_segment_stack_begin = .);
        . = __stack_size; /* Hart 0 */
        PROVIDE( _sp = . );
{% for hart in range(num_harts - 1) %}
        . = __stack_size; /* Hart {{ hart + 1 }} */
{% endfor %}
        PROVIDE(metal_segment_stack_end = .);
    } >{{ ram.vma }}

    .heap : {
        PROVIDE( metal_segment_heap_target_start = . );
        /* If __heap_max is defined, grow the heap to use the rest of RAM,
         * otherwise set the heap size to __heap_size */
        . = DEFINED(__heap_max) ? MIN( LENGTH(ram) - ( . - ORIGIN(ram)) , 0x10000000) : __heap_size;
        PROVIDE( metal_segment_heap_target_end = . );
        PROVIDE( _heap_end = . );
    } >{{ ram.vma }}
}
