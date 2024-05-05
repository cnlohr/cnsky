Shader "SatelliteStuff/SatelliteDisplay"
{
	Properties
	{
		_ThicknessGeo ("Thickness", float) = 0.01
		_ComputedTexture("Compute Satellites", 2D) = "white" {}
		_ManagementTexture("Compute Management", 2D) = "white" {}
		_ImportTexture("Compute Download", 2D) = "white" {}
		_InverseScale("InverseScale", float) = 6000
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
				float4 bez3 : BEZ3;
				float4 cppos : CPP;
				float3 reltime : RELTIME;
				UNITY_FOG_COORDS(1)
			};

			float _ThicknessGeo;
			float _InverseScale;
			
			// Cubic bezier approx distance 2
			// https://www.shadertoy.com/view/3lsSzS
			// By NinjaKoala
			#include "ninja_koala_cubic_bezier_math.cginc"

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
			
			[maxvertexcount(30)]
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

				for( seg = 0; seg < 6; seg++ )
				{
					float4 pos0 = _ComputedTexture.Load( int3( thissatCompute.x + 0 + seg, _ComputedTexture_TexelSize.w - ( thissatCompute.y + 0 ) - 1 + 0, 0 ) );
					float4 vel0 = _ComputedTexture.Load( int3( thissatCompute.x + 0 + seg, _ComputedTexture_TexelSize.w - ( thissatCompute.y + 1 ) - 1 + 0, 0 ) );
					float4 pos1 = _ComputedTexture.Load( int3( thissatCompute.x + 1 + seg, _ComputedTexture_TexelSize.w - ( thissatCompute.y + 0 ) - 1 + 0, 0 ) );
					float4 vel1 = _ComputedTexture.Load( int3( thissatCompute.x + 1 + seg, _ComputedTexture_TexelSize.w - ( thissatCompute.y + 1 ) - 1 + 0, 0 ) );
					
					vel0 *= separatingTimePerSegment*60 / 3;
					vel1 *= separatingTimePerSegment*60 / 3;
					
					float3 bez[4] = {
						pos0.xyz,
						pos0.xyz + vel0.xyz,
						pos1.xyz,
						pos1.xyz - vel1.xyz,
						};
						
					int i;
					for( i = 0; i < 4; i++ )
						bez[i] /= _InverseScale;
				
					
					g2f po;
					po.bez0 = UnityObjectToClipPos( bez[0] );
					po.bez1 = UnityObjectToClipPos( bez[1] );
					po.bez2 = UnityObjectToClipPos( bez[3] );
					po.bez3 = UnityObjectToClipPos( bez[2] );

					float4 clippos_base[4] = {
						UnityObjectToClipPos(bez[0]),
						UnityObjectToClipPos(bez[1]),
						UnityObjectToClipPos(bez[3]),
						UnityObjectToClipPos(bez[2]) };
						
					float2 orthos[2] = {
						(clippos_base[1] - clippos_base[0]).yx * float2( 1.0, -1.0 ),
						(clippos_base[3] - clippos_base[2]).yx * float2( 1.0, -1.0 ) };

					orthos[0] = normalize( orthos[0] )*_ThicknessGeo;
					orthos[1] = normalize( orthos[1] )*_ThicknessGeo;
					
					float4 clippos[6] = {
						clippos_base[0] + float4( orthos[0], 0.0, 0.0 ),
						clippos_base[0] - float4( orthos[0], 0.0, 0.0 ),
						clippos_base[2],
						clippos_base[1],
						clippos_base[3] - float4( orthos[1], 0.0, 0.0 ),
						clippos_base[3] + float4( orthos[1], 0.0, 0.0 ),
					};
					
					
					po.reltime = float3( pos0.w, jdFrac, pos1.w );

					triStream.RestartStrip(); // XXX TODO REMOVE ME!!! THEN ALSO SKIP First 2 of next emission.


					//XXX TODO: Potentially re-order indices 2 and 3 to mazimize hull.
					
					// Looks like we might need to re-order everything.
					int vtx;
					for( vtx = 0; vtx < 6; vtx++ )
					{
						float4 cp = clippos[vtx];
						po.vertex = cp;
						po.cppos = po.vertex.xyzw;

						UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(po);

						UNITY_TRANSFER_FOG(po,po.vertex);

						triStream.Append(po);
					}

				}
			}

			fixed4 frag (g2f i) : SV_Target
			{
				fixed4 col = float4( 1.0, 1.0, 1.0, 1.0 );

				float2 cp = i.cppos / i.cppos.w;
				float2 bez0 = i.bez0 / i.bez0.w;
				float2 bez1 = i.bez1 / i.bez1.w;
				float2 bez2 = i.bez2 / i.bez2.w;
				float2 bez3 = i.bez3 / i.bez3.w;

				// XXX TODO: Use implicit clippos.  I.e. when the surface is close to the camera, but the intersection is far, it shows up close.
				float2 dis=cubic_bezier_dis_approx(
					cp,
					bez0,
					bez1,
					bez2,
					bez3
					);
				
				// Perspective correct				
				//dis.x *= i.cppos.w * 20;

				dis.x *= 0.7 / fwidth( cp );
				

				// Comptue actual position
				//float t = frac( _Time.x );
				float t = (i.reltime.y - i.reltime.x) / (i.reltime.z - i.reltime.x);

				float aspectRatio = ddx( i.cppos.x ) / ddy (i.cppos.y );
				float s = 1.0-t;
				float2 b = bez0*s*s*s + bez1*3.0*s*s*t + bez2*3.0*s*t*t + bez3*t*t*t;
				float satitself = saturate( 1.0 - length( (cp - b) * float2(1, aspectRatio ) ) * 0.2 * clamp( i.cppos.w, 1, 7.0 ) / fwidth( cp ) );
				satitself =  pow( satitself, .1 );
				
				col.a = saturate( saturate( 1.0 - dis.x) * 0.1 + satitself  );

				//col.a += 0.1;

				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
