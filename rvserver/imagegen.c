#include <sys/stat.h>
#include <stdio.h>
#include <stdint.h>
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

int main( int argc, char ** argv )
{
	if( argc != 4 )
	{
		fprintf( stderr, "Error: Usage: [tool] width image[.png] file[.bin]\n" );
		return -5;
	}
	int width = atoi( argv[1] );
	FILE * f = fopen( argv[3], "rb" );
	if( !f )
	{
		fprintf( stderr, "Error: can't open file %s\n", argv[4] );
		return -6;
	}
	fseek( f, 0, SEEK_END );
	int bytes = ftell( f );
	int height = ( bytes + width - 1 ) / width;
	fseek( f, 0, SEEK_SET );
	int bytesup = width * height * 4;
	uint8_t * data = calloc( bytesup, 1 );
	int rb = fread( data, 1, bytes, f );
	if( rb <= 0 )
	{
		fprintf( stderr, "Error: No image data read\n" );
		return -8;
	}
	printf( "Read %.3f kBytes\n", 0.001*rb );
	int r = stbi_write_png( argv[2], width, height, 4, data, width*4 );
	if( !r )
	{
		fprintf( stderr, "Error writing image \"%s\"\n", argv[2] );
		return -12;
	}
	struct stat sb;
	r = stat( argv[2], &sb );
	if( r )
	{
		fprintf( stderr, "Error: Could not stat written image \"%s\"\n", argv[2] );
		return -13;
	}
	printf( "Compressed: %.3f kBytes\n", 0.001 * sb.st_size );
	return 0;
}

