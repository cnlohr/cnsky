Shader "Unlit/TestPoint"
{
	Properties
	{
		_Thickness ("Thickness", float) = 0.1
	}
	SubShader
	{
		Tags {"Queue"="Transparent" "RenderType"="Transparent"}
		Blend SrcAlpha OneMinusSrcAlpha
		//Blend One One // Additive
		Cull Off
			//ZWrite Off
		
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
				UNITY_FOG_COORDS(1)
			};

			float _Thickness;
			
			
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
			
			[maxvertexcount(32)]
			void geo(point v2g p[1], inout TriangleStream<g2f> triStream, uint pid : SV_PrimitiveID )
			{
				float3 offset = float3( pid* 1.5, 0, 0 );

				float3 bez[4] = {
					{ 0, 0, 0 },
					{ 0, 1, 0 },
					{ 1, 0, 1 },
					{ 1, 0, 1 } };
					
				bez[2].x = cos( 20*_Time.x )+1;
				bez[2].z = sin( 20*_Time.x )+1;

				bez[0] += offset;
				bez[1] += offset;
				bez[2] += offset;
				bez[3] += offset;
				
				
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

				orthos[0] = normalize( orthos[0] )*_Thickness;
				orthos[1] = normalize( orthos[1] )*_Thickness;
				
				float4 clippos[6] = {
					clippos_base[0] + float4( orthos[0], 0.0, 0.0 ),
					clippos_base[0] - float4( orthos[0], 0.0, 0.0 ),
					clippos_base[1],
					clippos_base[2],
					clippos_base[3] + float4( orthos[1], 0.0, 0.0 ),
					clippos_base[3] - float4( orthos[1], 0.0, 0.0 )
				};

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
				float t = frac( _Time.y );
				
				float s = 1.0-t;
				float2 b = bez0*s*s*s + bez1*3.0*s*s*t + bez2*3.0*s*t*t + bez3*t*t*t;
				//d0 = min(d0,segment_dis_sq(uv, a, b ));

				float satitself = saturate( 1.0 - length( cp - b ) * 0.2 * clamp( i.cppos.w, 1, 7.0 ) / fwidth( cp ) );
				satitself =  pow( satitself, .1 );
				
				col.a = saturate( saturate( 1.0 - dis.x) * 0.1 + satitself  );



				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
