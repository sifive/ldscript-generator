OUTPUT_ARCH("riscv")

{% block description %}{% endblock %}

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
    } >{{ rom.vma }} AT>{{ rom.lma }} :{{ rom.phdr }}

{% if not text_in_itim %}
    .text : {
	*(.text.unlikely .text.unlikely.*)
	*(.text.startup .text.startup.*)
	*(.text .text.*)
	*(.gnu.linkonce.t.*)
    } >{{ rom.vma }} AT>{{ rom.lma }} :{{ rom.phdr }}
{% endif %}

    .fini : {
	KEEP (*(SORT_NONE(.fini)))
    } >{{ rom.vma }} AT>{{ rom.lma }} :{{ rom.phdr }}

    PROVIDE (__etext = .);
    PROVIDE (_etext = .);
    PROVIDE (etext = .);

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
    } >{{ rom.vma }} AT>{{ rom.lma }} :{{ rom.phdr }}
{% endif %}

    .preinit_array : {
	. = ALIGN(8);
	PROVIDE_HIDDEN (__preinit_array_start = .);
	KEEP (*(.preinit_array))
	PROVIDE_HIDDEN (__preinit_array_end = .);
    } >{{ rom.vma }} AT>{{ rom.lma }} :{{ rom.phdr }}

    .init_array : {
	PROVIDE_HIDDEN (__init_array_start = .);
	KEEP (*(SORT_BY_INIT_PRIORITY(.init_array.*) SORT_BY_INIT_PRIORITY(.ctors.*)))
	KEEP (*(.init_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .ctors))
	PROVIDE_HIDDEN (__init_array_end = .);
    } >{{ rom.vma }} AT>{{ rom.lma }} :{{ rom.phdr }}

    .fini_array : {
	PROVIDE_HIDDEN (__fini_array_start = .);
	KEEP (*(SORT_BY_INIT_PRIORITY(.fini_array.*) SORT_BY_INIT_PRIORITY(.dtors.*)))
	KEEP (*(.fini_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .dtors))
	PROVIDE_HIDDEN (__fini_array_end = .);
    } >{{ rom.vma }} AT>{{ rom.lma }} :{{ rom.phdr }}

    .ctors : {
	KEEP (*crtbegin.o(.ctors))
	KEEP (*crtbegin?.o(.ctors))
	KEEP (*(EXCLUDE_FILE (*crtend.o *crtend?.o ) .ctors))
	KEEP (*(SORT(.ctors.*)))
	KEEP (*(.ctors))
    } >{{ rom.vma }} AT>{{ rom.lma }} :{{ rom.phdr }}

    .dtors : {
	KEEP (*crtbegin.o(.dtors))
	KEEP (*crtbegin?.o(.dtors))
	KEEP (*(EXCLUDE_FILE (*crtend.o *crtend?.o ) .dtors))
	KEEP (*(SORT(.dtors.*)))
	KEEP (*(.dtors))
    } >{{ rom.vma }} AT>{{ rom.lma }} :{{ rom.phdr }}

    /* ITIM SECTION
     *
     * The following sections contain data which is copied from read-only
     * memory into an instruction tightly-integrated memory (ITIM), if one
     * is present in the design, during pre-main program initialization.
     *
     * Generally, the data copied into the ITIM should be performance-critical
     * functions which benefit from low instruction-fetch latency.
     */

    .litimalign : {
	. = ALIGN(8);
	PROVIDE( metal_segment_itim_source_start = . );
    } >{{ itim.lma }} AT>{{ itim.lma }} :{{ itim.source_phdr }}

    .ditimalign : {
	. = ALIGN(8);
	PROVIDE( metal_segment_itim_target_start = . );
    } >{{ itim.vma }} AT>{{ itim.lma }} :{{ itim.dest_phdr }}

{% if text_in_itim %}
    /* The .text section is placed in the ITIM to improve the performance
     * of all post-init and non-constructor application code. Note that
     * this may cause the program to fail to link if the ITIM is not large
     * enough to contain the entire .text section. */
    .text : {
	*(.text.unlikely .text.unlikely.*)
	*(.text.startup .text.startup.*)
	*(.text .text.*)
	*(.gnu.linkonce.t.*)
    } >{{ itim.vma }} AT>{{ itim.lma }} :{{ itim.dest_phdr }}
{% endif %}

    .itim : {
	*(.itim .itim.*)
	PROVIDE( metal_segment_itim_target_end = . );
    } >{{ itim.vma }} AT>{{ itim.lma }} :{{ itim.dest_phdr }}

    /* RAM SECTION
     *
     * The following sections contain data which is copied from read-only
     * memory into a read-write-capable memory such as data tightly-integrated
     * memory (DTIM) or another main memory, as well as the BSS, stack, and
     * heap.
     */

    .lalign : {
	. = ALIGN(8);
	PROVIDE( _data_lma = . );
	PROVIDE( metal_segment_data_source_start = . );
    } >{{ ram.lma }} AT>{{ ram.lma }} :{{ ram.source_phdr }}

    .dalign : {
	. = ALIGN(8);
	PROVIDE( metal_segment_data_target_start = . );
    } >{{ ram.vma }} AT>{{ ram.lma }} :{{ ram.dest_phdr }}

    .data : {
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
    } >{{ ram.vma }} AT>{{ ram.lma }} :{{ ram.dest_phdr }}

    PROVIDE( _edata = . );
    PROVIDE( edata = . );
    PROVIDE( metal_segment_data_target_end = . );

    . = ALIGN(8);
    PROVIDE( _fbss = . );
    PROVIDE( __bss_start = . );
    PROVIDE( metal_segment_bss_target_start = . );

    .bss : {
	*(.sbss*)
	*(.gnu.linkonce.sb.*)
	*(.bss .bss.*)
	*(.gnu.linkonce.b.*)
	*(COMMON)
    } >{{ ram.vma }} AT>{{ ram.lma }} :{{ ram.dest_phdr }}

    PROVIDE( _end = . );
    PROVIDE( end = . );
    PROVIDE( metal_segment_bss_target_end = . );

    .stack : {
	PROVIDE(metal_segment_stack_begin = .);
	. = __stack_size; /* Hart 0 */
	PROVIDE( _sp = . );
{%- for hart in range(num_harts - 1) %}
	. = __stack_size; /* Hart {{ hart + 1 }} */
{%- endfor %}
	PROVIDE(metal_segment_stack_end = .);
    } >{{ ram.vma }} :{{ ram.source_phdr }}

    .heap : {
	PROVIDE( metal_segment_heap_target_start = . );
	. = __heap_size;
	PROVIDE( metal_segment_heap_target_end = . );
	PROVIDE( _heap_end = . );
    } >{{ ram.vma }} :{{ ram.source_phdr }}
}
