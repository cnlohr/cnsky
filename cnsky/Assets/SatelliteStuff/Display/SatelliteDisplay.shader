// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "SatelliteStuff/SatelliteDisplay"
{
	Properties
	{
		_MSDFTex ("MSDF Texture", 2DArray) = "white" {}
		_TailThick ("Tail Thickness", float) = 0.01
		_TailAlpha("Tail Alpha", float)=1.0
		_SatelliteAlpha("Satellite Alpha", float)=1.0
		_ComputedTexture("Compute Satellites", 2D) = "white" {}
		_ManagementTexture("Compute Management", 2D) = "white" {}
		_ImportTexture("Compute Download", 2D) = "white" {}
		_InverseScale("InverseScale", float) = 6000
		_SatSize("Satellite Size", float)=0.01
		_BaseSizeUpscale("Base Size Upscale", float)=1.0
		_TailThickHullOffset("Tail Thickness Hull Offset", float)=0.3
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
			
			#include "IQ-QuadradicBezier.cginc"
			#include "cnlohr-QuadradicBezier.cginc"
			#include "Assets/MSDFShaderPrintf/MSDFShaderPrintf.cginc"
			
			struct appdata
			{
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2g
			{
				uint id : ID;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			struct g2f
			{
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
				float4 vertex : SV_POSITION;
				float4 bez0 : BEZ0;
				float4 bez1 : BEZ1;
				float4 bez2 : BEZ2;
				float4 cppos : CPP;
				float4 color : COLOR;
				float3 reltime : RELTIME;
				UNITY_FOG_COORDS(1)
			};

			float _InverseScale;
			float _SatSize;
			float _TailAlpha;
			float _SatelliteAlpha;

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

			float ComputeTailThickness( float dist )
			{
				float fInvScale = 
					_TailThick * (abs(dist) +.5*_BaseSizeUpscale) / _ScreenParams.x * 100.0
					+ 1.4 * abs(dist)  / _ScreenParams.x; // Increase size of distant ones.
				return 1./fInvScale;
			}

			float ComputeSatelliteSize( float dist )
			{
				return
					_SatSize * (abs(dist) +10*_BaseSizeUpscale) / _ScreenParams.x
					+ 2.0 * abs(dist)  / _ScreenParams.x; // Increase size of distant ones.
			}


#if defined(UNITY_STEREO_MULTIVIEW_ENABLED) && defined(SHADER_API_GLES3)
			[maxvertexcount(64)]
#else
			[maxvertexcount(32)]
#endif

			void geo(point v2g p[1], inout TriangleStream<g2f> triStream, uint pid : SV_PrimitiveID )
			{
			
#if defined(UNITY_STEREO_MULTIVIEW_ENABLED) && defined(SHADER_API_GLES3)
				int eye;
				for( eye = 0; eye < 2; eye ++ )
				{
					unity_StereoEyeIndex = p[0].stereoTargetEyeIndex = eye;
#endif				

				UNITY_SETUP_INSTANCE_ID(p[0]);
				
				uint operationID = pid;
				uint thisop = operationID;
				const uint totalsat = (511*85); // 85 satellites per line, 511 lines.
				const uint thissatno = (thisop%totalsat);
				
				// +1 in y term says to skip first row.
				uint2 thissatImport = uint2( 6 * (thissatno % 85), ((thissatno / 85) % 511) + 1 );
				uint2 thissatCompute = uint2( 8 * (thissatno % 85), (((thissatno / 85) % 511) + 1)*2 ); 

				float4 InfoBlock = _ManagementTexture.Load( int3( 0, _ManagementTexture_TexelSize.w - 1, 0 ) );
				float4 ManagementBlock2 = _ManagementTexture.Load( int3( 0, _ManagementTexture_TexelSize.w - 2, 0 ) );
				float jdDay = InfoBlock.y;
				float jdFrac = InfoBlock.z;

				float4 tledat0 = _ImportTexture.Load( int3( thissatImport.x + 0, _ImportTexture_TexelSize.w - thissatImport.y - 1, 0 ) );
				if( tledat0.x < 0.5 ) return;
				int seg;
				
				float separatingTimePerSegment = ManagementBlock2.x;

				float3 objectCenter = 0;

// I couldn't get this working.				
//				float4 posfront = _ComputedTexture.Load( int3( thissatCompute.x + 0 + 0, _ComputedTexture_TexelSize.w - ( thissatCompute.y + 0 ) - 1 + 0, 0 ) );
//				float4 poslast = _ComputedTexture.Load( int3( thissatCompute.x + 0 + 5, _ComputedTexture_TexelSize.w - ( thissatCompute.y + 0 ) - 1 + 0, 0 ) );
//				float4 poscenterish = _ComputedTexture.Load( int3( thissatCompute.x + 0 + 2, _ComputedTexture_TexelSize.w - ( thissatCompute.y + 0 ) - 1 + 0, 0 ) );
//				float3 orthoAxis =
//					normalize( ( mul( UNITY_MATRIX_MV, float4( poscenterish.xyz, 0.0 ) ) ).xyz );
//					normalize( cross( 
//						( mul( UNITY_MATRIX_MV, float4( posfront.xyz, 1.0 ) ) -  mul( UNITY_MATRIX_MV, float4( poslast.xyz, 1.0 ) ) ).xyz, 
//						( mul( UNITY_MATRIX_MV, float4( poscenterish.xyz, 1.0 ) ) ).xyz ) );
				g2f po;

				UNITY_INITIALIZE_OUTPUT(g2f, po);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(po);
				UNITY_TRANSFER_VERTEX_OUTPUT_STEREO( po, p[0] );
#if defined(UNITY_STEREO_MULTIVIEW_ENABLED) && defined(SHADER_API_GLES3)
				po.gl_Layer = eye;
#endif
				po.color = _ComputedTexture.Load( int3( thissatCompute.x + 6, _ComputedTexture_TexelSize.w - ( thissatCompute.y + 0 ) - 1 + 0, 0 ) );

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
						
					po.reltime = float3( pos0.w, jdFrac, pos1.w );
					
					if( jdFrac >= pos0.w && jdFrac <=  pos1.w )
					{
						float t = (jdFrac - pos0.w) / (pos1.w - pos0.w);

						// Compute position along curve.
						float3 a = lerp( bez[0].xyz, bez[1].xyz, t );
						float3 b = lerp( bez[1].xyz, bez[2].xyz, t ); 
						objectCenter = lerp( a, b, t );
					}

					// TODO: Roll this into ResolveBezier
					po.bez0 = ( mul( UNITY_MATRIX_MV, float4( bez[0], 1.0 ) ) );
					po.bez1 = ( mul( UNITY_MATRIX_MV, float4( bez[1], 1.0 ) ) );
					po.bez2 = ( mul( UNITY_MATRIX_MV, float4( bez[2], 1.0 ) ) );
					
					bez[0] = po.bez0;
					bez[1] = po.bez1;
					bez[2] = po.bez2;
					
					float3 viewpos[5];

					ResolveBezierGeometry( viewpos, bez );

					// UNRESOLVED, Handle shape where center is behind one of the other two.
					
					int vtx;

					for( vtx = 0; vtx < 5; vtx++ )
					{
						//if( seg > 0 && vtx < 0 ) continue;
						
						float4 cp = mul( UNITY_MATRIX_P, float4( viewpos[vtx], 1.0 ) );
						po.vertex = cp;
						po.cppos = ( float4( viewpos[vtx], 1.0  ));

						UNITY_TRANSFER_FOG(po,po.vertex);

						triStream.Append(po);
					}
					// XXX TODO REMOVE ME!!! THEN ALSO SKIP First 2 of next emission.
					triStream.RestartStrip();
				}
				
				
				// Emit special block at end.
				//reltime
				float4 csCenter = UnityObjectToClipPos( objectCenter );
				float3 csWorldCenter = mul( UNITY_MATRIX_M, float4( objectCenter, 1.0 ) );


				po.reltime = 0.0;
				po.bez0 = 0;
				po.bez1 = 0;
				po.bez2 = float4( thissatImport+0.5, 0.0, 0.0 );
				float4 rsize = float4( _ScreenParams.y/_ScreenParams.x, 1, 0, 1. ) * ComputeSatelliteSize( length( csWorldCenter - _WorldSpaceCameraPos ) );
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
				
				
#if defined(UNITY_STEREO_MULTIVIEW_ENABLED) && defined(SHADER_API_GLES3)
				}
#endif
			}
			
			float3 projectIntoPlane( float3 n,  float3 b )
			{
				n = normalize( n );
				return cross( n, cross( b, n ) ) + n * dot( n, b );
			}
			
			fixed4 frag (g2f i) : SV_Target
			{
				fixed4 col = float4( i.color.rgba );

				if( length( i.reltime ) < 0.0001 )
				{
					float sedge = length(i.cppos.xy);
					float2 uv = i.cppos+0.5;
					
					float distscale = .025 / length( fwidth( i.cppos.xy ) );
					
					 // Add offset
					uv.x += 0.33;
					uv.y -= 0.0;

					uv = uv * float2( 8.0, 4.0 ) * clamp( .05 + distscale, 0.1, 1.0 );

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
						float4 grad = float4( ddx(uv), ddy(uv) );
						float2 c = MSDFPrintChar( char, uv, grad );
						c.x = 1.0 - c.x;
						col.rgb *= c.xxx;
						//col.rgb = lerp( col.rgb, saturate( c.xxx ), saturate( distscale * 2.0 ) );
					}					
					
					col.a *= saturate(2.0-sedge*2.0) * _SatelliteAlpha;
					//col.a += 0.05;
					return col;
				}



				float3 cp = i.cppos;
				float3 bez0 =  i.bez0;
				float3 bez1 =  i.bez1;
				float3 bez2 =  i.bez2;
				
				// Project bezier onto visual plane (cppos is our "local" view vector)
				// We can't project it onto the normal view vector otherwise it will warp around.
				// What if we project cp into bezproj plane instead?

				// build basis for forward vector.
				// Need to pick the correct direction otherwise we will get artifacting.
				float3 forward = normalize( cp );
				
				float3 up = float3( 0, 1, 0 );
				float3 right = normalize( cross( forward, up ) );
				float3 newup = normalize( cross( right, forward ) ); 
				float3x3 matr = float3x3( right, newup, forward );

				bez0 = mul( matr, bez0);
				bez1 = mul( matr, bez1 );
				bez2 = mul( matr, bez2  );
				cp = mul( matr, cp );
				float3 cpbase = cp;
				cp = normalize( cp );
				
				bez0.z *= 0.000;
				bez1.z *= 0.000;
				bez2.z *= 0.000;
				cp.z   *= 0.000;
				

				float t;
				float2 outQ;
				float f = sdBezierMod( cp, bez0, bez1, bez2, outQ, t );
				f = abs(f);

				float tT = (i.reltime.y - i.reltime.x) / (i.reltime.z - i.reltime.x);
				float tDelta = (t-tT);

				float fLoD = length( fwidth( cpbase.xy ) );
				float fDist = f*ComputeTailThickness( cpbase.z );
				
				// Get rid of tail in front of satellite.
				fDist += saturate( tDelta*2000);
				col.a = saturate( 1.0-fDist );
				// Fade out tail.  Based on nr segs, and where in the front we expect the satellite to be.
				col.a *= saturate((4.5+tDelta)/4.5) * _TailAlpha; 
				col.a *= 0.2;  // Overall fade.

				//col.a += 0.01;

		
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
