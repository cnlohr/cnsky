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
			
			#include "/Assets/cnsky/SatelliteStuff/csgp4_aux.cginc"

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

			uint BitsSelect( uint4 dataA, uint4 dataB, uint shift ) 
			{
				uint shiftdiv4 = shift/4;
				uint selfromA = 0;
				if (shiftdiv4<4)
					selfromA = dataA[shiftdiv4-0];
				else if(shiftdiv4<8)
					selfromA = dataB[shiftdiv4-4];

				uint selmod4 = shift % 4;
				
				uint ret = ( selfromA >> (selmod4*8) );

				if( selmod4 > 0 )
				{
					shiftdiv4++;
					if (shiftdiv4<4)
						selfromA = dataA[shiftdiv4];
					else if(shiftdiv4<8)
						selfromA = dataB[shiftdiv4-4];

					ret |= ( selfromA << (( 4 - selmod4 )*8) );
				}
				return ret;
			}



			#define INSTANCE_CT 32
			#define GEOPRIM_CT  2 // Do not change this.
			
			[maxvertexcount(16)] // Position + Velocity, 6 points  + 4 Bonus
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
				uint2 thissat = uint2( 8 * (thissatno % 85), ((thissatno / 85) % 511) + 1 );
				uint2 thissatin = uint2( 6 * (thissatno % 85), ((thissatno / 85) % 511) + 1 );
				
				// Make sure it is a sane number of satellites.
				if( totalsat < 1 || totalsat >= (511*85) )
					return;

				float4 tledat0 = _ImportTexture.Load( int3( thissatin.x + 0, _ImportTexture_TexelSize.w - thissatin.y - 1, 0 ) );
				float4 tledat1 = _ImportTexture.Load( int3( thissatin.x + 1, _ImportTexture_TexelSize.w - thissatin.y - 1, 0 ) );
				float4 tledat2 = _ImportTexture.Load( int3( thissatin.x + 2, _ImportTexture_TexelSize.w - thissatin.y - 1, 0 ) );
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
				
				// Output color...
				float4 color = 1.0;
				
				// Check against a string list.
				uint4 InfoBlockStr  = asuint( _ImportTexture.Load( int3( thissatin.x + 4, _ImportTexture_TexelSize.w - thissatin.y - 1, 0 ) ) );
				uint4 InfoBlockStr2 = asuint( _ImportTexture.Load( int3( thissatin.x + 5, _ImportTexture_TexelSize.w - thissatin.y - 1, 0 ) ) );
				
				// String search - shift through, ofsetting the string by 0 to 16 bytes, to string match to known color-coded satellites.
				int s = 0;
				for( s = 0; s < 16; s++ )
				{
					uint4 CheckBlock = 0;
					CheckBlock.r = BitsSelect( InfoBlockStr, InfoBlockStr2, s + 6 );
					CheckBlock.g = BitsSelect( InfoBlockStr, InfoBlockStr2, s + 10 );
					CheckBlock.b = BitsSelect( InfoBlockStr, InfoBlockStr2, s + 14 );
					CheckBlock.a = BitsSelect( InfoBlockStr, InfoBlockStr2, s + 18 );
					
					// STARLINK
					if( CheckBlock.r == 0x52415453 && CheckBlock.g == 0x4b4e494c )
						color = float4(0.78, 0.957, 0.392, 1.0);

					if( CheckBlock.r == 0x42454420 ) // DEB
						color = float4( 0.902, 0.267, 0.325, 1.0 ); //GREEN
						//49 53 53 20

					if( CheckBlock.r == 0x29535349 || CheckBlock.r == 0x20535349 || CheckBlock.r == 0x53534928 ) // ISS) ISS_ or (ISS
						color = float4( 0.153, 0.404, 0.671, 1.0 ); // BLUE
						
					// Dragon
					if( s == 0 && 
						( 
						   (  CheckBlock.r == 0x47415244 && ( CheckBlock.g & 0xffff ) == 0x4E4F )  // 44 52 41 47 4F 4E "DRAGON"
						|| ( CheckBlock.r == 0x474f5250 && CheckBlock.g  == 0x53534552  ) //50 52 4F 47 52 45 53 53 "PROGRESS"
						) )
					{
						color = float4( 0.153, 0.404, 0.671, 1.0 ); // BLUE
					}
						
					if( CheckBlock.r == 0x57454E4F && ( CheckBlock.g & 0xffff ) == 0x4245 ) // ONEWEB
						color = float4( 0.306, 0.804, 0.769, 1.0 ); // CYAN
						
					// // OBJECT or UNKNOWN  55 4E 4B 4E 4F 57 4E
					if( ( CheckBlock.r == 0x454A424F && ( CheckBlock.g & 0xffff ) == 0x5443 ) || ( CheckBlock.r == 0x4E4B4E55 && ( CheckBlock.g & 0xffff ) == 0x4E57 ) )
						color = float4( 1, 0.569, 0.282, 1.0 ); // ORANGE
						
				}
					
				//53 54 
				//41 52 4C 49 4E 4B 0A
				
				
				uint2 coordOut;
				coordOut = uint2( thissat * uint2( 1, 2 ) + uint2( 6, 0) );
				o.vertex = FlexCRTCoordinateOut( coordOut );
				o.color = color;
				stream.Append(o);
			}

			float4 frag( g2f IN ) : SV_Target
			{
				return IN.color;
			}
			ENDCG
		}
	}
}
