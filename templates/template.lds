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
	{{ phdr.name }} {{ phdr.type }};
{%- endfor %}
}

SECTIONS
{

	__stack_size = DEFINED(__stack_size) ? __stack_size : {{ default_stack_size }};
	PROVIDE(__stack_size = __stack_size);
	__heap_size = DEFINED(__heap_size) ? __heap_size : {{ default_heap_size }};
	PROVIDE(__metal_boot_hart = {{ boot_hart }});
	PROVIDE(__metal_chicken_bit = {{ chicken_bit }});

	.init : {
		KEEP (*(.text.metal.init.enter))
		KEEP (*(.text.metal.init.*))
		KEEP (*(SORT_NONE(.init)))
		KEEP (*(.text.libgloss.start))
	} >{{ init.vma }} AT>{{ init.lma }} :{{ init.phdr }}

{% if not text_in_itim %}
	.text : {
		*(.text.unlikely .text.unlikely.*)
		*(.text.startup .text.startup.*)
		*(.text .text.*)
		*(.gnu.linkonce.t.*)
	} >{{ text.vma }} AT>{{ text.lma }} :{{ text.phdr }}
{% endif %}

	.fini : {
		KEEP (*(SORT_NONE(.fini)))
	} >{{ init.vma }} AT>{{ init.lma }} :{{ init.phdr }}

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
	} >{{ rodata.vma }} AT>{{ rodata.lma }} :{{ rodata.phdr }}
{% endif %}

	.preinit_array : {
		. = ALIGN(8);
		PROVIDE_HIDDEN (__preinit_array_start = .);
		KEEP (*(.preinit_array))
		PROVIDE_HIDDEN (__preinit_array_end = .);
	} >{{ ctors.vma }} AT>{{ ctors.lma }} :{{ ctors.phdr }}

	.init_array : {
		PROVIDE_HIDDEN (__init_array_start = .);
		KEEP (*(SORT_BY_INIT_PRIORITY(.init_array.*) SORT_BY_INIT_PRIORITY(.ctors.*)))
		KEEP (*(.init_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .ctors))
		PROVIDE_HIDDEN (__init_array_end = .);
	} >{{ ctors.vma }} AT>{{ ctors.lma }} :{{ ctors.phdr }}

	.fini_array : {
		PROVIDE_HIDDEN (__fini_array_start = .);
		KEEP (*(SORT_BY_INIT_PRIORITY(.fini_array.*) SORT_BY_INIT_PRIORITY(.dtors.*)))
		KEEP (*(.fini_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .dtors))
		PROVIDE_HIDDEN (__fini_array_end = .);
	} >{{ ctors.vma }} AT>{{ ctors.lma }} :{{ ctors.phdr }}

	.ctors : {
		KEEP (*crtbegin.o(.ctors))
		KEEP (*crtbegin?.o(.ctors))
		KEEP (*(EXCLUDE_FILE (*crtend.o *crtend?.o ) .ctors))
		KEEP (*(SORT(.ctors.*)))
		KEEP (*(.ctors))
	} >{{ ctors.vma }} AT>{{ ctors.lma }} :{{ ctors.phdr }}

	.dtors : {
		KEEP (*crtbegin.o(.dtors))
		KEEP (*crtbegin?.o(.dtors))
		KEEP (*(EXCLUDE_FILE (*crtend.o *crtend?.o ) .dtors))
		KEEP (*(SORT(.dtors.*)))
		KEEP (*(.dtors))
	} >{{ ctors.vma }} AT>{{ ctors.lma }} :{{ ctors.phdr }}

	.litimalign : {
		. = ALIGN(8);
		PROVIDE( metal_segment_itim_source_start = . );
	} >{{ itim.lma }} AT>{{ itim.lma }} :{{ itim.source_phdr }}

	.ditimalign : {
		. = ALIGN(8);
		PROVIDE( metal_segment_itim_target_start = . );
	} >{{ itim.vma }} AT>{{ itim.lma }} :{{ itim.dest_phdr }}

{% if text_in_itim %}
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

	.lalign : {
		. = ALIGN(8);
		PROVIDE( _data_lma = . );
		PROVIDE( metal_segment_data_source_start = . );
	} >{{ data.lma }} AT>{{ data.lma }} :{{ data.source_phdr }}

	.dalign : {
		. = ALIGN(8);
		PROVIDE( metal_segment_data_target_start = . );
	} >{{ data.vma }} AT>{{ data.lma }} :{{ data.dest_phdr }}

	.data : {
		*(.data .data.*)
		*(.gnu.linkonce.d.*)
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
	} >{{ data.vma }} AT>{{ data.lma }} :{{ data.dest_phdr }}

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
	} >{{ bss.vma }} AT>{{ bss.lma }} :{{ bss.phdr }}
	PROVIDE( _end = . );
	PROVIDE( end = . );
	PROVIDE( metal_segment_bss_target_end = . );

	.stack : {
		PROVIDE(metal_segment_stack_begin = .);
		. = __stack_size;
		PROVIDE( _sp = . );
{%- for hart in range(num_harts - 1) %}
		. = __stack_size;
{%- endfor %}
		PROVIDE(metal_segment_stack_end = .);
	} >{{ stack.vma }} AT>{{ stack.lma }} :{{ stack.phdr }}

	.heap : {
		PROVIDE( metal_segment_heap_target_start = . );
		. = __heap_size;
		PROVIDE( metal_segment_heap_target_end = . );
		PROVIDE( _heap_end = . );
	} >{{ heap.vma }} AT>{{ heap.lma }} :{{ heap.phdr }}
}

