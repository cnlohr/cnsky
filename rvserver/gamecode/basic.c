#include <string.h>
#include <stdint.h>
#include <stdio.h>
#include <stdarg.h>

// These are going to be bound to memory addresses in the linker script.
extern volatile uint32_t VRCCON0;
extern volatile uint32_t VRCCON1;
extern volatile uint32_t SYSCON;
extern volatile uint32_t TIMERL;
extern volatile uint32_t STDOUT;

// These will not turn into function calls, but instead will find a way
// of writing the assembly in-line
static void lprint( const char * s )
{
	int c;
	while( c = *s++ )
		STDOUT = c;
/*
	uint32_t assembled = 0;
	uint32_t l = 0;
	do
	{
		for( l = 0; l < 4; l++ )
		{
			char c;
			c = *(s++);
			if( !c ) goto doublebreak;
			assembled >>= 8;
			assembled |= c<<24;
		}
		STDOUT = assembled;
	} while( 1 );
	doublebreak:
	if( assembled )
		STDOUT = assembled >> (4-l*8);
*/
}

static void pprint( intptr_t ptr )
{
	int n;
	for( n = 7; n >= 0; n-- )
	{
		int c = (ptr >> (n*4)) & 0xf;
		if( c >= 10 ) c += 'a' - 10; else c += '0';
		STDOUT = c;
	}
}

static void nprint( intptr_t ptr )
{
	int lg10;
	int lg10c = 1;
	for( lg10 = 0; lg10 < 10; lg10++ )
	{
		if( ptr < lg10c ) break;
		lg10c *= 10;
	}

	lg10c /= 10;
	if( !lg10c )
	{
		STDOUT = '0';
		return;
	}

	do
	{
		int dif = ptr / lg10c;
		STDOUT = ( dif ) + '0';
		ptr -= dif * lg10c;
		lg10c /= 10;
	} while( lg10c );
}

static inline uint32_t get_cyc_count() {
	uint32_t ccount;
	asm volatile(".option norvc\ncsrr %0, 0xC00":"=r" (ccount));
	return ccount;
}

int main()
{
	lprint("\n");
	lprint("Hello world from RV32 land.\n");
	lprint("main is at: ");
	pprint( (intptr_t)main );
	lprint("\n");

	// Wait a while.
	uint32_t cyclecount_initial = get_cyc_count();
	uint32_t timer_initial = TIMERL;

	int i;
	for( i = 0; i < 10000; i++ )
	{
		asm volatile( "nop" );
	}

	// Gather the wall-clock time and # of cycles
	uint32_t cyclecount = get_cyc_count() - cyclecount_initial;
	uint32_t timer = TIMERL - timer_initial;
	lprint( "Total Timer: ");
	nprint( timer );
	lprint( "\nCycle count: ");
	nprint( get_cyc_count() );
	lprint( "\nProcessor effective speed: ");
	nprint( cyclecount * 1000 / timer );
	lprint( " Kcyc/s\n");

	lprint("\n");
	//SYSCON = 0x5555; // Power off
//	while(1) VRCCON0 = 1;
	// Idle
	while(1)
	{
		int frame = VRCCON1;
		lprint( "\x1b[10;1H" );
		nprint( frame );
		VRCCON0 = 0x1;
	}
}

