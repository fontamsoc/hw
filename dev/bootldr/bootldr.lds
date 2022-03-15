/* SPDX-License-Identifier: GPL-2.0-only
   (c) William Fonkou Tambe

   Templated from `ld -verbose` with following changes done:
   - Use ALIGN(8) for data segment, instead of ALIGN(CONSTANT (MAXPAGESIZE)),
	accounting for pu64.
   - Remove shared library support.
   - Remote thread-local-storage support.
   - Remove exception handling support. */

ENTRY(_start)

SECTIONS {
	PROVIDE (__executable_start = SEGMENT_START("text-segment", 0x0));
	. = __executable_start;
	.text           : {
		*(.text._start)
		*(.text.unlikely .text.*_unlikely .text.unlikely.*)
		*(.text.exit .text.exit.*)
		*(.text.startup .text.startup.*)
		*(.text.hot .text.hot.*)
		*(SORT(.text.sorted.*))
		*(.text .stub .text.* .gnu.linkonce.t.*)
		/* .gnu.warning sections are handled specially by elf.em.  */
		*(.gnu.warning)
	}
	.init           : {
		KEEP (*(SORT_NONE(.init)))
	}
	.fini           : {
		KEEP (*(SORT_NONE(.fini)))
	}
	PROVIDE (__etext = .);
	PROVIDE (_etext = .);
	PROVIDE (etext = .);
	.rodata         : { *(.rodata .rodata.* .gnu.linkonce.r.*) }
	.rodata1        : { *(.rodata1) }
	.sdata2         : {
		*(.sdata2 .sdata2.* .gnu.linkonce.s2.*)
	}
	.sbss2          : { *(.sbss2 .sbss2.* .gnu.linkonce.sb2.*) }
	. = ALIGN(8); /* Align the address for the data segment */
	.preinit_array    : {
		PROVIDE_HIDDEN (__preinit_array_start = .);
		KEEP (*(.preinit_array))
		PROVIDE_HIDDEN (__preinit_array_end = .);
	}
	.init_array    : {
		PROVIDE_HIDDEN (__init_array_start = .);
		KEEP (*(SORT_BY_INIT_PRIORITY(.init_array.*) SORT_BY_INIT_PRIORITY(.ctors.*)))
		KEEP (*(.init_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .ctors))
		PROVIDE_HIDDEN (__init_array_end = .);
	}
	.fini_array    : {
		PROVIDE_HIDDEN (__fini_array_start = .);
		KEEP (*(SORT_BY_INIT_PRIORITY(.fini_array.*) SORT_BY_INIT_PRIORITY(.dtors.*)))
		KEEP (*(.fini_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .dtors))
		PROVIDE_HIDDEN (__fini_array_end = .);
	}
	.ctors          : {
		/* gcc uses crtbegin.o to find the start of
		the constructors, so we make sure it is
		first.  Because this is a wildcard, it
		doesn't matter if the user does not
		actually link against crtbegin.o; the
		linker won't look for a file to match a
		wildcard.  The wildcard also means that it
		doesn't matter which directory crtbegin.o
		is in.  */
		KEEP (*crtbegin.o(.ctors))
		KEEP (*crtbegin?.o(.ctors))
		/* We don't want to include the .ctor section from
		the crtend.o file until after the sorted ctors.
		The .ctor section from the crtend file contains the
		end of ctors marker and it must be last */
		KEEP (*(EXCLUDE_FILE (*crtend.o *crtend?.o ) .ctors))
		KEEP (*(SORT(.ctors.*)))
		KEEP (*(.ctors))
	}
	.dtors          : {
		KEEP (*crtbegin.o(.dtors))
		KEEP (*crtbegin?.o(.dtors))
		KEEP (*(EXCLUDE_FILE (*crtend.o *crtend?.o ) .dtors))
		KEEP (*(SORT(.dtors.*)))
		KEEP (*(.dtors))
	}
	.data.rel.ro : { *(.data.rel.ro.local* .gnu.linkonce.d.rel.ro.local.*) *(.data.rel.ro .data.rel.ro.* .gnu.linkonce.d.rel.ro.*) }
	.data           : {
		*(.data .data.* .gnu.linkonce.d.*)
		SORT(CONSTRUCTORS)
	}
	.data1          : { *(.data1) }
	/* We want the small data sections together, so single-instruction offsets
	can access them all, and initialized data all before uninitialized, so
	we can shorten the on-disk segment size.  */
	.sdata          : {
		*(.sdata .sdata.* .gnu.linkonce.s.*)
	}
	_edata = .; PROVIDE (edata = .);
	. = .;
	__bss_start = .;
	. = ALIGN(8); __bss_start = . ;
	.sbss           : {
		*(.dynsbss)
		*(.sbss .sbss.* .gnu.linkonce.sb.*)
		*(.scommon)
	}
	.bss            : {
		*(.dynbss)
		*(.bss .bss.* .gnu.linkonce.b.*)
		*(COMMON)
	}
	__bss_end = . ;
	. = ALIGN(8);
	. = SEGMENT_START("ldata-segment", .);
	. = ALIGN(8);
	_end = .; PROVIDE (end = .);
	.note.gnu.build-id  : { *(.note.gnu.build-id) }
	.hash           : { *(.hash) }
	.gnu.hash       : { *(.gnu.hash) }
	.gnu.version    : { *(.gnu.version) }
	.gnu.version_d  : { *(.gnu.version_d) }
	.gnu.version_r  : { *(.gnu.version_r) }
	/* Stabs debugging sections.  */
	.stab          0 : { *(.stab) }
	.stabstr       0 : { *(.stabstr) }
	.stab.excl     0 : { *(.stab.excl) }
	.stab.exclstr  0 : { *(.stab.exclstr) }
	.stab.index    0 : { *(.stab.index) }
	.stab.indexstr 0 : { *(.stab.indexstr) }
	.comment       0 : { *(.comment) }
	.gnu.build.attributes : { *(.gnu.build.attributes .gnu.build.attributes.*) }
	/* DWARF debug sections.
	Symbols in the DWARF debugging sections are relative to the beginning
	of the section so we begin them at 0.  */
	/* DWARF 1 */
	.debug          0 : { *(.debug) }
	.line           0 : { *(.line) }
	/* GNU DWARF 1 extensions */
	.debug_srcinfo  0 : { *(.debug_srcinfo) }
	.debug_sfnames  0 : { *(.debug_sfnames) }
	/* DWARF 1.1 and DWARF 2 */
	.debug_aranges  0 : { *(.debug_aranges) }
	.debug_pubnames 0 : { *(.debug_pubnames) }
	/* DWARF 2 */
	.debug_info     0 : { *(.debug_info .gnu.linkonce.wi.*) }
	.debug_abbrev   0 : { *(.debug_abbrev) }
	.debug_line     0 : { *(.debug_line .debug_line.* .debug_line_end) }
	.debug_frame    0 : { *(.debug_frame) }
	.debug_str      0 : { *(.debug_str) }
	.debug_loc      0 : { *(.debug_loc) }
	.debug_macinfo  0 : { *(.debug_macinfo) }
	/* SGI/MIPS DWARF 2 extensions */
	.debug_weaknames 0 : { *(.debug_weaknames) }
	.debug_funcnames 0 : { *(.debug_funcnames) }
	.debug_typenames 0 : { *(.debug_typenames) }
	.debug_varnames  0 : { *(.debug_varnames) }
	/* DWARF 3 */
	.debug_pubtypes 0 : { *(.debug_pubtypes) }
	.debug_ranges   0 : { *(.debug_ranges) }
	/* DWARF Extension.  */
	.debug_macro    0 : { *(.debug_macro) }
	.debug_addr     0 : { *(.debug_addr) }
	.gnu.attributes 0 : { KEEP (*(.gnu.attributes)) }
	/DISCARD/ : { *(.note.GNU-stack) *(.gnu_debuglink) *(.gnu.lto_*) }
}
