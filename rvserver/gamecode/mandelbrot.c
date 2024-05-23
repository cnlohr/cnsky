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
	lprint( "HELLO RAYN!\n");

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
	int iter = 0;
	while(1)
	{
		int frame = VRCCON1;
		iter++;
//		lprint( "\x1b[" );
//		nprint( ( iter % 10 ) + 10 );
//		int nf = iter / 10;
//		lprint( ";" );
//		nprint( (nf%10)*6 );
//		lprint( "H" );
//		nprint( frame );
		VRCCON0 = 0x1;

		uint32_t * rptr = 0x80010000;
		int jj;
		for( jj = 0; jj < 256; jj++ )
		{
			uint32_t * rptra = &rptr[(iter*1024+jj*4)%950000];
			int px = (rptra-rptr) / 4;
			int x = px & 0x1ff;
			int y = px / 0x1ff;
			int ofs = 16384;
			int32_t cr = (int32_t)(x * 64) - ofs;
			int32_t ci = (int32_t)(y * 64) - ofs;
//			nprint( cr );
//			lprint( " ");
//			nprint( x );
//			lprint ("\n");

			int zi = 0;
			int zr = 0;
			int iter = 0;
			for( iter = 0; iter < 63; iter++ )
			{
				// Z = Z^2 + C
				int tzi = ( ( 2 * ( ( zi * zr ) >> 12 ) )  )+ ci;
				zr = (( zr * zr ) >> 12 ) - (( zi * zi >> 12 )) + cr;
				zi = tzi;
				uint32_t mag = (uint32_t)(zr * zr) + (uint32_t)(zi * zi);
				if( mag > 100000000 ) break;
			}
//			nprint( iter );
//			lprint( " ");
//			nprint( cr );
//			lprint( " ");
//			nprint( zr );
//			lprint( "\n");


			uint32_t col = iter * 0x4000000;
			rptra[0] = col;
			rptra[1] = col;//x<<21;
			rptra[2] = col;//y<<21;
			rptra[3] = 0;
		}
	}
}

