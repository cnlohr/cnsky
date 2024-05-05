Shader "SatelliteStuff/RTComputeManagement"
{
    Properties
    {
        _FloatImport ("Float Import", 2D) = "white" {}
    }
    SubShader
    {

		Tags { }
		ZTest always
		ZWrite Off


	CGINCLUDE
		#pragma vertex vert
		#pragma fragment frag
		#pragma geometry geo
		#pragma multi_compile_fog
		#pragma target 5.0

		#define CRTTEXTURETYPE float4
		#include "/Assets/cnlohr/flexcrt/flexcrt.cginc"
		#include "/Assets/SatelliteStuff/csgp4_aux.cginc"
		
	ENDCG


		Pass
		{
			Name "Satellite Management CRT"
			
			CGPROGRAM
			
			#include "/Assets/cnlohr/hashwithoutsine/hashwithoutsine.cginc"

			#include "Packages/com.llealloo.audiolink/Runtime/Shaders/AudioLink.cginc"
		
			Texture2D<float4> _FloatImport;
			float4 _FloatImport_TexelSize;

			struct v2g
			{
				float4 vertex : SV_POSITION;
				uint2 batchID : TEXCOORD0;
			};

			struct g2f
			{
				float4 vertex		   : SV_POSITION;
				uint4 color			: TEXCOORD0;
			};

			v2g vert( appdata_customrendertexture IN )
			{
				v2g o;
				o.batchID = IN.vertexID / 6;

				// This is unused, but must be initialized otherwise things get janky.
				o.vertex = 0.;
				return o;
			}

			[maxvertexcount(8)]
			[instance(2)]
			void geo( point v2g input[1], inout PointStream<g2f> stream,
				uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID )
			{
				// Just FYI you get 64kB of local variable space.
				// --> geoPrimID ---> I believe geoPrimID can be either 0 or 1?
				
				int batchID = input[0].batchID;
				int operationID = geoPrimID * 2 + ( instanceID - batchID );
				g2f o;

				float UTCDAY = AudioLinkDecodeDataAsUInt( ALPASS_GENERALVU_UNIX_DAYS )  + SGP4_FROM_EPOCH_DAYS;
				float UTCDAYf = AudioLinkDecodeDataAsSeconds( ALPASS_GENERALVU_UNIX_SECONDS )/86400.0;
				float ALROK = 1;
				// AudioLink Not Running

				if( UTCDAY == 0 )
				{
					float4 infoblock = _FloatImport.Load( uint3( 0, _FloatImport_TexelSize.w - 1, 0 ) );
					UTCDAYf = infoblock.z + _Time.y/86400.0;
					UTCDAY = infoblock.y + floor( UTCDAYf );
					UTCDAYf = frac( UTCDAYf );
					ALROK = 0;
				}

				int year, mon, day, hr, minute;
				float second;
				invjday( UTCDAY+SGP4_FROM_EPOCH_DAYS, UTCDAYf, year, mon, day, hr, minute, second );

				for( int i = 0; i < 4; i++ )
				{
					uint PixelID = operationID * 4 + i;
					
					// We first output random noise, then we output a stable block.
					uint2 coordOut;
					coordOut = uint2( i, operationID+0 );
					
					// Weird as-uint, as-float because otherwise we lose our timer.
					uint4 color = 0.0;
					if( operationID == 0 )
					{
						switch( i )
						{
						case 0:
							color = asuint( float4( asfloat( asuint(_SelfTexture2D.Load( int3( 0, 3, 0 ) ).x) + 1 ), UTCDAY, UTCDAYf, ALROK) );
							break;
						case 1:
							color = asuint( float4( year, mon, day, 0.0 ) );
							break;
						case 2:
							color = asuint( float4( hr, minute, second, 0.0 ) );
							break;
						default:
							break;
						}
					}
					else if( operationID == 1 )
					{
						switch( i )
						{
						case 0:
							color = asuint( float4( 4.0, -18.0, 0.0, 0.0 ) );
							break;
						case 1:
							color = 0.0;
							break;
						}
					}

					o.vertex = FlexCRTCoordinateOut( coordOut );
					o.color = color;
					stream.Append(o);
				}
			}

			float4 frag( g2f IN ) : SV_Target
			{
				return asfloat( IN.color );
			}
			ENDCG
		}
	}
}
