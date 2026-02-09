Shader "Unlit/QuestGEOHLSL"
{
	Properties
	{
	}
	SubShader
	{
		Tags { "RenderQueue"="Overlay" "RenderType"="Opaque" }
		Blend One One // Additive
		ZTest Off
		ZWrite On
		Cull Off
		
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma geometry geo
			#pragma target 5.0

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2g
			{
				float4 pos : LOC;
				float4 uva : TC;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};
			
			struct g2f
			{
				float4 vertex : SV_POSITION; // Tricky: This MUST be first.

				UNITY_VERTEX_OUTPUT_STEREO
				
#if defined(UNITY_STEREO_MULTIVIEW_ENABLED) && defined(SHADER_API_GLES3)
				uint gl_Layer : SV_RenderTargetArrayIndex;
#endif
				float4 uv : TC;
			};

			v2g vert (appdata v) //, uint id : SV_VertexID, uint iid : SV_InstanceID )
			{			
				UNITY_SETUP_INSTANCE_ID(v);
				v2g o = (v2g)0;
				UNITY_INITIALIZE_OUTPUT(v2g, o);
				UNITY_TRANSFER_INSTANCE_ID(v,o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				o.pos = v.vertex;
				o.uva = float4( v.uv, 0.0, 0.0 );
				return o;
			}
			
			[maxvertexcount(9)]
			//[instance(2)]  // HALP WY NO WORK
			void geo(triangle v2g t[3], inout TriangleStream<g2f> triStream,
				uint InstanceID : SV_GSInstanceID,
				uint pid : SV_PrimitiveID
				)
			{
#if defined(UNITY_STEREO_MULTIVIEW_ENABLED) && defined(SHADER_API_GLES3)
				int eye = InstanceID;
			//	for( eye = 0; eye < 2; eye++ )
				{
				unity_StereoEyeIndex = 
#if defined(UNITY_INSTANCING_ENABLED) || defined(UNITY_PROCEDURAL_INSTANCING_ENABLED) || defined(UNITY_STEREO_INSTANCING_ENABLED)
					t[0].instanceID =
#endif
					eye;
#endif				

				UNITY_SETUP_INSTANCE_ID(t[0]);

				g2f po;

				UNITY_INITIALIZE_OUTPUT(g2f, po);

#if defined(UNITY_STEREO_MULTIVIEW_ENABLED) && defined(SHADER_API_GLES3)
				po.gl_Layer = eye;
#endif
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(po);

				int i;
				for( i = 0; i < 3; i++ )
				{

					float3 offset = float3( InstanceID, i, 0.0 );

					float4 c0 = mul( UNITY_MATRIX_VP, mul ( UNITY_MATRIX_M, (t[0].pos.xyzw + float4( offset, 0.0 )) ) );
					float4 c1 = mul( UNITY_MATRIX_VP, mul ( UNITY_MATRIX_M, (t[1].pos.xyzw + float4( offset, 0.0 )) ) );
					float4 c2 = mul( UNITY_MATRIX_VP, mul ( UNITY_MATRIX_M, (t[2].pos.xyzw + float4( offset, 0.0 )) ) );

					po.vertex = c0; po.uv = t[0].uva; UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(po); triStream.Append(po);
					po.vertex = c1; po.uv = t[1].uva; UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(po); triStream.Append(po);
					po.vertex = c2; po.uv = t[2].uva; UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(po); triStream.Append(po);
					triStream.RestartStrip();
				}
				
#if defined(UNITY_STEREO_MULTIVIEW_ENABLED) && defined(SHADER_API_GLES3)
				}
#endif
			}

			float4 frag (g2f i) : SV_Target
			{
				float4 col = float4( i.uv.rgb, 1.0 );
				return col;
			}
			ENDCG
		}
	}
}
