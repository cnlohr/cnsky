#include <stdio.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <stdint.h>
#include <linux/limits.h>

#define STB_IMAGE_WRITE_IMPLEMENTATION

#include "../csgp4/csgp4.h"
#include "../csgp4/os_generic.h"

#include "stb_image_write.h"

// Assume 24 floats per entry.
#define FPERE 24
#define DATAW 2048
#define DATAH 512
#define USABLE_W (((DATAW)/(FPERE))*(FPERE))

uint32_t data[2048*2048];

int main( int argc, char ** argv )
{
	if( argc != 3 )
	{
		fprintf( stderr, "Error: Usage: ./tle2image [infile] [outfile]\n" );
		return -10;
	}

	FILE * f = fopen( argv[1], "r" );
	if( !f )
	{
		fprintf( stderr, "Error: failed to open input file %s\n", argv[1] );
		return -11;
	}
	int numObjects = 0;
	struct TLEObject * objects = 0;
	int r = ParseFileOrString( f, 0, &objects, &numObjects );
	if( r )
	{
		fprintf( stderr, "Error: input file %s has errors\n", argv[1] );
		return -12;
	}
	printf( "Read in %d objects\n", numObjects );

	int outObjNumber = 1;

	int i;
	for( i = 0; i < numObjects; i++ )
	{
		struct TLEObject * o = objects + i;
		int validflags = o->valid;
		if( ( o->valid & 7 ) == 7 ) continue;

		o->valid = 0;
		// Scan through list and make sure we are the best object.
		int j;
		for( j = i+1; j < numObjects; j++ )
		{
			struct TLEObject * c = objects + j;
			if( ( ( c->valid & 7 ) == 7 ) && strcmp( o->objectName, c->objectName ) == 0 & strcmp( o->internationalDesignator, c->internationalDesignator ) == 0 )
			{
				// we have a duplicate, find one with most recent data.
				if( c->jdsatepoch >= o->jdsatepoch && c->jdsatepochF > o->jdsatepochF )
				{
					validflags = c->valid;
					o = c;
				}
				c->valid = 0;
			}
		}


		int oox = (outObjNumber * FPERE) % USABLE_W;
		int ooy = (outObjNumber * FPERE) / USABLE_W;

		float * px =  (float*)&data[oox+ooy*DATAW];
		px[0] = validflags; // valid flags - might be different?
		px[1] = o->jdsatepoch;
		px[2] = o->jdsatepochF;
		px[3] = o->meanMotion1;
		px[4] = o->dragTerm;
		px[5] = o->inclination;
		px[6] = o->rightAscensionOfTheAscendingNode;
		px[7] = o->eccentricity;
		px[8] = o->argumentOfPerigee;
		px[9] = o->meanAnomaly;
		px[10] = o->meanMotion;
		px[11] = o->revolutionNumberAtEpoch; // Possibly reserved.
		px[12] = o->elementSetNumber; // Possibly reserved.
		px[13] = o->catalogNumber;    // Possibly reserved.
		memcpy( px+14, o->internationalDesignator, 12 );
		memcpy( px+17, o->objectName, 24 );

		outObjNumber++;
	}
	printf( "Parsed %d objects\n", outObjNumber-1 );


	{
		// Info Block
		int oox = (0 * FPERE) % USABLE_W;
		int ooy = (0 * FPERE) / USABLE_W;
		float * px =  (float*)&data[oox+ooy*DATAW];
		px[0] = 7;
		double dNow = OGGetAbsoluteTime() / 1440.0;
		px[1] = (int)dNow;
		px[2] = dNow - (int)dNow;
		px[3] = numObjects;
		px[4] = outObjNumber;
		px[5] = 0;

		outObjNumber++;
	}



	// Assume 32 floats per object.
	char tempfile[PATH_MAX+1];
	snprintf( tempfile, sizeof(tempfile)-1, "%s.temp", argv[2] );
	r = stbi_write_png( tempfile, DATAW, DATAH, 4, data, 4*DATAW );
	printf( "Write status: %d\n", r );
	if( r == 0 )
	{
		fprintf( stderr, "Error: failed to write out PNG\n" );
		return -9;
	}
	printf( "Building image complete.\n" );
	// Need to copy file into place to make sure downloads don't get corrutped.
	r = rename( tempfile, argv[2] );
	if( r == 0 )
	{
		printf( "Copy into place ok\n" );
	}
	else
	{
		fprintf( stderr, "Error copying into place\n" );
	}
	return 0;
}

