#include <string.h>
#include <stdint.h>
#include <stdio.h>
#include <stdarg.h>

#include "vrc-rv32ima.h"

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

static void nprint( int32_t ptrin )
{
	uint32_t ptr = ptrin;
	if( ptrin < 0 )
	{
		ptr = -ptrin;
		lprint( "-" );
	}
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


void Print3( const char * str, const volatile uint32_t * nums )
{
	lprint( str ); lprint( " " ); nprint( nums[0] ); lprint( " " ); nprint( nums[1] ); lprint( " " ); nprint( nums[2] ); lprint( "    \n" );
}

int main()
{
	lprint("\n");
	lprint("Hello world from RV32 land.\n");
	lprint("main is at: ");
	pprint( (intptr_t)main );
	lprint( "\nENVCTRL = " );
	pprint( (intptr_t)&ENVCTRL->marker[0] );
	lprint( "\nHOSTDAT = " );
	pprint( (intptr_t)&HOSTDAT.GameFrameLow );
	lprint( "\n" );

	ENVCTRL->marker[0] = 0xffffffff;
	ENVCTRL->marker[1] = 0xffffffff;
	ENVCTRL->marker[2] = 0xffffffff;
	ENVCTRL->marker[3] = 0xffffffff;

	// Wait a while.
	uint32_t cyclecount_initial = get_cyc_count();
	uint32_t timer_initial = TIMERL;

	int i;
	for( i = 0; i < 30000; i++ )
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
		int frame = HOSTDAT.GameFrameLow;
		lprint( "\x1b[9;1H" );
		nprint( frame );
		lprint( " " );
		int np = HOSTDAT.NumPlayers;
		nprint( np );
		lprint( " " );
		nprint( HOSTDAT.IdOfLocalPlayer );
		lprint( "\n" );
		lprint( "Clicks: " );
		nprint( HOSTDAT.LeftClickness );
		lprint( " " );
		nprint( HOSTDAT.RightClickness );
		lprint( "      \n" );

		Print3( "IndexLD", HOSTDAT.IndexLeftDistal );
		Print3( "IndexRD", HOSTDAT.IndexRightDistal );
		Print3( "IndexLM", HOSTDAT.IndexLeftIntermediate );
		Print3( "IndexRM", HOSTDAT.IndexRightIntermediate );
		Print3( "PointLP", HOSTDAT.Pointer0Pos );
		Print3( "PointRP", HOSTDAT.Pointer1Pos );
		Print3( "PointLD", HOSTDAT.Pointer0Dir );
		Print3( "PointRD", HOSTDAT.Pointer1Dir );

		int n;
		for( n = 0; n < np; n++ )
		{
			nprint( HOSTDAT.Players[n].Flag[0] );
			lprint( " " );
			nprint( HOSTDAT.Players[n].Pos[0] );
			lprint( " " );
			nprint( HOSTDAT.Players[n].Pos[1] );
			lprint( " " );
			nprint( HOSTDAT.Players[n].Pos[2] );
			lprint( " " );
			nprint( HOSTDAT.PlayerBones[n].LeftHand[0] );
			lprint( " " );
			nprint( HOSTDAT.PlayerBones[n].LeftHand[1] );
			lprint( " " );
			nprint( HOSTDAT.PlayerBones[n].LeftHand[2] );
			lprint( " " );
			nprint( HOSTDAT.Players[n].Name[0] );
			lprint( " " );
			nprint( HOSTDAT.Players[n].Name[1] );
			lprint( " " );
			nprint( HOSTDAT.Players[n].Name[2] );
			lprint( " " );
			nprint( HOSTDAT.Players[n].Name[3] );
			lprint( " " );
			nprint( HOSTDAT.Players[n].Name[4] );
			lprint( "    \n");
		}

		VRCCON0 = 0x1;
	}
}


