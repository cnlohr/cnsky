Shader "SatelliteStuff/SatelliteDisplay"
{
	Properties
	{
		_ThicknessGeo ("Thickness", float) = 0.01
		_ComputedTexture("Compute Satellites", 2D) = "white" {}
		_ManagementTexture("Compute Management", 2D) = "white" {}
		_ImportTexture("Compute Download", 2D) = "white" {}
		_InverseScale("InverseScale", float) = 6000
		_SatSize("Satellite Size", float)=0.01
	}
	SubShader
	{
		Tags {"Queue"="Transparent" "RenderType"="Transparent"}
		Blend SrcAlpha OneMinusSrcAlpha
		//Blend One One // Additive
		Cull Off
			ZWrite Off
		
		Pass
		{
			CGPROGRAM
			#include "UnityCG.cginc"

			#pragma vertex vert
			#pragma geometry geo
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile_fog
			
			#include "PerBloksgaard-BezierCode.cginc"
			#include "Assets/MSDFShaderPrintf/MSDFShaderPrintf.cginc"
			
			struct appdata
			{
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2g
			{
				uint id : ID;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct g2f
			{
				float4 vertex : SV_POSITION;
				float4 bez0 : BEZ0;
				float4 bez1 : BEZ1;
				float4 bez2 : BEZ2;
				float4 cppos : CPP;
				float3 reltime : RELTIME;
				UNITY_FOG_COORDS(1)
			};

			float _ThicknessGeo;
			float _InverseScale;

			v2g vert (appdata v, uint id : SV_VertexID, uint iid : SV_InstanceID  )
			{
				v2g t;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_OUTPUT(v2g, t);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(t);
				t.id = id;
				return t;
			}
			
			
			Texture2D< float4 > _ImportTexture;
			float4 _ImportTexture_TexelSize;
			Texture2D< float4 > _ManagementTexture;
			float4 _ManagementTexture_TexelSize;
			Texture2D< float4 > _ComputedTexture;
			float4 _ComputedTexture_TexelSize;
			
			float _SatSize;
			
			[maxvertexcount(36)]
			void geo(point v2g p[1], inout TriangleStream<g2f> triStream, uint pid : SV_PrimitiveID )
			{
				uint operationID = pid;
				uint thisop = operationID;
				const uint totalsat = (511*85); // 85 satellites per line, 511 lines.
				const uint thissatno = (thisop%totalsat);
				
				// +1 in y term says to skip first row.
				uint2 thissatImport = uint2( 6 * (thissatno % 85), ((thissatno / 85) % 511) + 1 );
				uint2 thissatCompute = uint2( 6 * (thissatno % 85), (((thissatno / 85) % 511) + 1)*2 ); 

				float4 InfoBlock = _ManagementTexture.Load( int3( 0, _ManagementTexture_TexelSize.w - 1, 0 ) );
				float4 ManagementBlock2 = _ManagementTexture.Load( int3( 0, _ManagementTexture_TexelSize.w - 2, 0 ) );
				float jdDay = InfoBlock.y;
				float jdFrac = InfoBlock.z;

				float4 tledat0 = _ImportTexture.Load( int3( thissatImport.x + 0, _ImportTexture_TexelSize.w - thissatImport.y - 1, 0 ) );
				if( tledat0.x < 0.5 ) return;
				int seg;
				
				float separatingTimePerSegment = ManagementBlock2.x;

				float3 objectCenter = 0;
				
				for( seg = 0; seg < 5; seg++ )
				{
					float4 pos0 = _ComputedTexture.Load( int3( thissatCompute.x + 0 + seg, _ComputedTexture_TexelSize.w - ( thissatCompute.y + 0 ) - 1 + 0, 0 ) );
					float4 vel0 = _ComputedTexture.Load( int3( thissatCompute.x + 0 + seg, _ComputedTexture_TexelSize.w - ( thissatCompute.y + 1 ) - 1 + 0, 0 ) );
					float4 pos1 = _ComputedTexture.Load( int3( thissatCompute.x + 1 + seg, _ComputedTexture_TexelSize.w - ( thissatCompute.y + 0 ) - 1 + 0, 0 ) );
					float4 vel1 = _ComputedTexture.Load( int3( thissatCompute.x + 1 + seg, _ComputedTexture_TexelSize.w - ( thissatCompute.y + 1 ) - 1 + 0, 0 ) );
					
					vel0 *= separatingTimePerSegment*60 / 2;
					vel1 *= separatingTimePerSegment*60 / 2; //Careful here - this makes everything line up when we switch to a 3-point-bezier.
					
					float3 bez[3] = {
						pos0.xyz,
						( pos0.xyz + vel0.xyz + pos1.xyz - vel1.xyz ) / 2.0, // This is how we switch to a 3-point bezier.
						pos1.xyz,
						};
						
					int i;
					for( i = 0; i < 3; i++ )
						bez[i] /= _InverseScale;
			
					
					g2f po;
					
					po.reltime = float3( pos0.w, jdFrac, pos1.w );
					
					if( jdFrac >= pos0.w && jdFrac <=  pos1.w )
					{
						float t = (jdFrac - pos0.w) / (pos1.w - pos0.w);
						objectCenter = lerp( bez[0].xyz, bez[2].xyz, t );
					}

					// TODO: Roll this into ResolveBezier
					po.bez0 = UnityObjectToClipPos( bez[0] );
					po.bez1 = UnityObjectToClipPos( bez[1] );
					po.bez2 = UnityObjectToClipPos( bez[2] );

					float4 clippos[5];
					ResolveBezierGeometry( clippos, bez, _ThicknessGeo);

					// UNRESOLVED, Handle shape where center is behind one of the other two.
					
					int vtx;

					for( vtx = 0; vtx < 5; vtx++ )
					{
						//if( seg > 0 && vtx < 0 ) continue;
						float4 cp = clippos[vtx];
						po.vertex = cp;
						po.cppos = po.vertex.xyzw;

						UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(po);

						UNITY_TRANSFER_FOG(po,po.vertex);

						triStream.Append(po);
					}
					// XXX TODO REMOVE ME!!! THEN ALSO SKIP First 2 of next emission.
					triStream.RestartStrip();
				}
				
				
				// Emit special block at end.
				//reltime
				float4 csCenter = UnityObjectToClipPos( objectCenter );

				g2f po;
				po.reltime = 0.0;
				po.bez0 = 0;
				po.bez1 = 0;
				po.bez2 = float4( thissatImport+0.5, 0.0, 0.0 );
				float4 rsize = float4( _ScreenParams.y/_ScreenParams.x, 1, 0, 1. ) * _SatSize;
				float4 vtx_ofs[4] = {
					{-1, -1, 0, 0},
					{ 1, -1, 0, 0},
					{-1,  1, 0, 0},
					{ 1,  1, 0, 0}
					};
				int i;
				for( i = 0; i < 4; i++ )
				{
					po.cppos = vtx_ofs[i];
					po.vertex = csCenter + vtx_ofs[i] * rsize;

					UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(po);
					UNITY_TRANSFER_FOG(po,po.vertex);
					triStream.Append(po);
				}
			}

			fixed4 frag (g2f i) : SV_Target
			{
				fixed4 col = float4( 1.0, 1.0, 1.0, 1.0 );

				if( length( i.reltime ) < 0.0001 )
				{
					float sedge = length(i.cppos.xy);
					col = 1.0;
					float2 uv = i.cppos+0.5;
					
					float distscale = .02 / length( fwidth( i.cppos.xy ) );
					uv = uv * float2( 8.0, 4.0 ) * clamp( .05 + distscale, 0.1, 1.0 );
					
					uv.x += 3.0;
					uint2 textcoord = floor( uv );
					if( uv.x < 0 || uv.y < 0 || uv.y > 2 || distscale < 0.1 || textcoord.x >= 12 )
					{
						//Outside bounds
					}
					else
					{
						// When in zoom mode, bez2 contains where we can look for more info.
						uint2 thissatImport = i.bez2.xy;
						uint charno = textcoord.x;
						charno += textcoord.y*12;
						charno += 4+2;
						uint4 tledat0 = asuint(_ImportTexture.Load( int3( thissatImport.x + 4 + (charno/16), _ImportTexture_TexelSize.w - thissatImport.y - 1, 0 ) ));
						uint char = tledat0[(charno/4)%4];
						char = (char >> (charno%4) * 8) &0xff;
						float2 c = MSDFPrintChar( char, uv, uv );
						col.rgb = lerp( col.rgb, saturate( c.xxx ), distscale );
					}					
					
					col.a *= saturate(2.0-sedge*2.0);
					return col;
				}

				float2 cp = i.cppos / i.cppos.w;
				float2 bez0 = i.bez0 / i.bez0.w;
				float2 bez1 = i.bez1 / i.bez1.w;
				float2 bez2 = i.bez2 / i.bez2.w;

				float deres = length( fwidth( cp ) );

				float t;
				float f = calculateDistanceToQuadraticBezier( t, cp, bez0, bez1, bez2 );
				
				// 1.2 controls close-side, bigger = can get closer.
				// 0.1/deres determine far size.
				f *= clamp( i.cppos.w, 1.2, .007/deres );

				float tT = 
					(i.reltime.y - i.reltime.x) / (i.reltime.z - i.reltime.x);
				float tDelta = (t-tT);

				float fDist = f*400;
				
				// Get rid of tail in front of satellite.
				fDist += saturate( tDelta*2000);

				col.a = saturate( 1.0-fDist );
				col.a *= saturate((4.4+tDelta)/4.4); // Fade out tail.  Based on nr segs, and where in the front we expect the satellite to be.
				col.a *= 0.2;  // Overall fade.
	
				//col.a += .1; // for debug
				
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
