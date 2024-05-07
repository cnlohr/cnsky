Shader "SatelliteStuff/RTComputeSatellites"
{
	Properties
	{
		_ImportTexture ("Import", 2D) = "white" {}
		_ManagementTexture ("Management", 2D) = "white" {}
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

		#define CRTTEXTURETYPE uint4
		#include "/Assets/cnlohr/flexcrt/flexcrt.cginc"
	ENDCG


		Pass
		{
			Name "Demo Compute Test"
			
			CGPROGRAM
			
			#include "/Assets/SatelliteStuff/csgp4_aux.cginc"

			//#pragma skip_optimizations d3d11
			#pragma enable_d3d11_debug_symbols
			
			struct v2g
			{
				float4 vertex : SV_POSITION;
				uint2 batchID : TEXCOORD0;
			};

			struct g2f
			{
				float4 vertex		   : SV_POSITION;
				float4 color			: TEXCOORD0;
			};

			Texture2D< float4 > _ImportTexture;
			float4 _ImportTexture_TexelSize;
			Texture2D< float4 > _ManagementTexture;
			float4 _ManagementTexture_TexelSize;
			
			// The vertex shader doesn't really perform much anything.
			v2g vert( appdata_customrendertexture IN )
			{
				v2g o;
				o.batchID = IN.vertexID / 3;

				// This is unused, but must be initialized otherwise things get janky.
				o.vertex = 0.;
				return o;
			}

			#define INSTANCE_CT 32
			#define GEOPRIM_CT  2 // Do not change this.
			
			[maxvertexcount(12)] // Position + Velocity, 6 points.
			
			[instance(INSTANCE_CT)]

			void geo( point v2g input[1], inout PointStream<g2f> stream,
				uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID )
			{
				g2f o;
				int operationID = geoPrimID * INSTANCE_CT + instanceID;
				// operationID = 0..63
				
				float4 InfoBlock0 = _ManagementTexture.Load( int3( 0, _ManagementTexture_TexelSize.w - 1, 0 ) );
				float4 InfoBlock3 = _ManagementTexture.Load( int3( 3, _ManagementTexture_TexelSize.w - 1, 0 ) );
				float4 ManagementBlock2 = _ManagementTexture.Load( int3( 0, _ManagementTexture_TexelSize.w - 2, 0 ) );
				float jdDay = InfoBlock0.y;
				float jdFrac = InfoBlock0.z;

				// Can't go super in the past.
				if( jdDay < 2460281.5 ) return;
				
				uint thisop = asuint(InfoBlock0.x) * INSTANCE_CT * GEOPRIM_CT + operationID;
				const uint totalsat = InfoBlock3.x;
					//(511*85); // 85 satellites per line, 511 lines.
					//InfoBlock1.x;
				const uint thissatno = (thisop%totalsat);
				uint2 thissat = uint2( 6 * (thissatno % 85), ((thissatno / 85) % 511) + 1 );
				
				// Make sure it is a sane number of satellites.
				if( totalsat < 1 || totalsat >= (511*85) )
					return;

				float4 tledat0 = _ImportTexture.Load( int3( thissat.x + 0, _ImportTexture_TexelSize.w - thissat.y - 1, 0 ) );
				float4 tledat1 = _ImportTexture.Load( int3( thissat.x + 1, _ImportTexture_TexelSize.w - thissat.y - 1, 0 ) );
				float4 tledat2 = _ImportTexture.Load( int3( thissat.x + 2, _ImportTexture_TexelSize.w - thissat.y - 1, 0 ) );
				if( tledat0.x == 0 ) return; // Only write into in-use blocks.
				precise float jdsatepoch = tledat0.y - 2433281.5; // Compute to Jan 1, 1950 - when SGP4 starts.
				float jdsatepochF = tledat0.z;
				precise float computeEpoch = (jdsatepoch) + jdsatepochF;
				precise float initialTimeMinutes = ( (jdDay - 2433281.5 - jdsatepoch) + jdFrac - jdsatepochF)*24.0 * 60.0;
				
				
				// computeEpoch is used in SGP4 init,
				// initialTime is 
				
				// 24 pixels per satellite.
				// 21 satellites per line.

				for( int i = 0; i < 6; i++ )
				{
					uint PixelID = i + operationID * 6;

					float3 position;
					float3 velocity;
					float3 altaaltp;
					
					float fTargetTimeDeltaMinutes = i * ManagementBlock2.x + ManagementBlock2.y;
					float fTimeToMeasureMinutes = initialTimeMinutes + fTargetTimeDeltaMinutes;
					
					float fDeltaDayTime = fTimeToMeasureMinutes / 60 / 24;
					
					//float 
					//uint2 satellite_in_source = 

					sgp4init_simple( 
						computeEpoch, 
						tledat1.x, // Drag term
						tledat0.w, // Mean Motion (Not actually used)
						0, //meanMotion2 (Not actually used)
						tledat1.w, //eccentricity
						tledat2.x, //argumentOfPerigee
						tledat1.y, //inclination
						tledat2.y, //meanAnomaly
						tledat2.z, //meanMotion
						tledat1.z, //rightAscensionOfTheAscendingNode
						fTimeToMeasureMinutes,
						position,
						velocity,
						altaaltp
						);
						
					// We actually want the time of the measurement in our own timebase.
					float fracDayTimeOfReading = jdFrac + fTargetTimeDeltaMinutes / 60 / 24;

					uint2 coordOut;
					coordOut = uint2( thissat * uint2( 1, 2 ) + uint2( i, 0) );
					o.vertex = FlexCRTCoordinateOut( coordOut );
					o.color = float4( position, fracDayTimeOfReading );
					stream.Append(o);

					coordOut.y ++;
					o.vertex = FlexCRTCoordinateOut( coordOut );
					o.color = float4( velocity, 0  );
					stream.Append(o);
				}
			}

			float4 frag( g2f IN ) : SV_Target
			{
				return IN.color;
			}
			ENDCG
		}
	}
}
