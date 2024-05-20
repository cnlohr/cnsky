__heap_size = 0x1000;
__stack_size = 0x1000;

ENTRY(_start)

MEMORY
{
	COMBINE (rwx)  : ORIGIN = 0x80000000, LENGTH = 4M
}

SECTIONS
{
	. = 0x80000000;
/*
	.header : ALIGN( 16 )
	{
		LONG( 0 )
		LONG( 0 )
	}
*/
	.text : ALIGN(16) {
		__TEXT_BEGIN__ = .;
		*(.initial_jump)
		*(.entry.text)
		*(.init.literal)
		*(.init)
		*(.text)
		*(.literal .text .literal.* .text.* .stub)
		*(.out_jump.literal.*)
		*(.out_jump.*)
		__TEXT_END__ = .;
	} > COMBINE

	/* If we're on a newer compiler */
	/DISCARD/ :
	{
		*(.interp)
		*(.dynsym)
		*(.dynstr)
		*(.header)
	} : phdr

	.data : ALIGN(16) {
		__DATA_BEGIN__ = .;
		*(.rodata)
		*(.rodata.*)
		*(.gnu.linkonce.r.*)
		*(.rodata1)
		*(.dynsbss)
		*(.gnu.linkonce.sb.*)
		*(.scommon)
		*(.gnu.linkonce.sb2.*)
		*(.sbss)
		*(.sbss.*)
		*(.sbss2)
		*(.sbss2.*)
		*(.dynbss)
		*(.data)
		*(.data.*)
		*(.got)
		*(.got.*)
		__DATA_END__ = .;
	} > COMBINE

	.bss : ALIGN( 16 ) {
		__BSS_BEGIN__ = .;
		*(.bss) /* Tricky: BSS needs to be allocated but not sent. GCC Will not populate these for calculating data size */
		*(.bss.*)
		__BSS_END__ = .;
	} > COMBINE

	.heap : ALIGN( 16 ) {
		_sheap = .;
		. = . + __heap_size;
		_eheap = .;
	} > COMBINE

	.stack : ALIGN( 16 ) {
		_estack = .;
		. = . + __stack_size;
		_sstack = .;
	} > COMBINE

	PROVIDE( SYSCON = 0x11100000 );
	PROVIDE( STDOUT = 0x10000000 );
	PROVIDE( VRCCON0 = 0x11000000 );
	PROVIDE( VRCCON1 = 0x11000001 );
	PROVIDE( TIMERL = 0x1100bff8 );
	PROVIDE( TIMERH = 0x1100bffc );
}


