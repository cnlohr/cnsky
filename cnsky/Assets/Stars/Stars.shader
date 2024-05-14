Shader "Unlit/Stars"
{
    Properties
    {
		_Hip2 ("HIPPARCOS Data", 2D) = "" {}
		_ManagementTexture ("Management Texture", 2D) = "" {}
		_InverseScale("InverseScale", float) = 6000
		_StarSize("Satellite Size", float)=0.01
		_BaseSizeUpscale("Base Size Upscale", float)=1.0
    }
    SubShader
	{
		// UNITY_SHADER_NO_UPGRADE 
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
				UNITY_VERTEX_OUTPUT_STEREO
				float4 vertex : SV_POSITION;
				float4 cppos : CPP;
				float4 bez2 : BEZ2;
				float3 reltime : RELTIME;
				UNITY_FOG_COORDS(1)
			};

			float _InverseScale;
			float _StarSize;
			float _TailAlpha;
			float _SatelliteAlpha;
			float _BaseSizeUpscale;
			Texture2D< float4 > _ManagementTexture;
			float4 _ManagementTexture_TexelSize;
			Texture2D< float4 > _Hip2;
			float4 _Hip2_TexelSize;

			v2g vert (appdata v, uint id : SV_VertexID, uint iid : SV_InstanceID  )
			{
				v2g t;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_OUTPUT(v2g, t);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(t);
				t.id = id;
				return t;
			}

		
			[maxvertexcount(36)]
			void geo(point v2g p[1], inout TriangleStream<g2f> triStream, uint pid : SV_PrimitiveID )
			{
				uint operationID = pid;
				uint thisop = operationID;
				const uint totalsat = (256*460);
				const uint thisstar = thisop;

				// +1 in y term says to skip first row.
				uint2 thisStarImport = uint2( (thisstar % 256), (thisstar / 256) );
				
				float4 StarBlockA = _Hip2.Load( int3( thisStarImport.x*2+0, _Hip2_TexelSize.w - 1 - thisStarImport.y, 0 ) );
				float4 StarBlockB = _Hip2.Load( int3( thisStarImport.x*2+1, _Hip2_TexelSize.w - 1 - thisStarImport.y, 0 ) );
				float4 InfoBlock = _ManagementTexture.Load( int3( 0, _ManagementTexture_TexelSize.w - 1, 0 ) );
				float4 ManagementBlock2 = _ManagementTexture.Load( int3( 0, _ManagementTexture_TexelSize.w - 2, 0 ) );
				float jdDay = InfoBlock.y;
				float jdFrac = InfoBlock.z;
				
				int4 StarBlockIntA = asuint( StarBlockA );
				uint4 StarBlockIntB = asuint( StarBlockB );
				
				float2 srascention, sdeclination;
				sincos( ((uint(StarBlockIntA.r))/4294967296.0) * 6.2831852, srascention.x, srascention.y );
				sincos( StarBlockIntA.g/2147483647.0 * 3.14159, sdeclination.x, sdeclination.y );
				float3 objectCenter = float3( srascention.x * sdeclination.y, srascention.y * sdeclination.y, sdeclination.x ) * 20;
		
				g2f po;
				UNITY_INITIALIZE_OUTPUT(g2f, po);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(po);
				
				// Emit special block at end.
				float4 csCenter = mul( UNITY_MATRIX_VP, float4( objectCenter.xyz, 1.0 ) );
				float3 csWorldCenter = mul( UNITY_MATRIX_M, float4( objectCenter, 1.0 ) );

				po.reltime = 0.0;
				po.bez2 = float4( thisStarImport+0.5, 0.0, 0.0 );
				float4 rsize = float4( _ScreenParams.y/_ScreenParams.x, 1, 0, 1. ) * .02;
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
			
			float3 projectIntoPlane( float3 n,  float3 b )
			{
				n = normalize( n );
				return cross( n, cross( b, n ) ) + n * dot( n, b );
			}
			
			fixed4 frag (g2f i) : SV_Target
			{
				fixed4 col = float4( 1.0, 1.0, 1.0, 1.0 );

				// Debug.
				return 1.0;
				
				float sedge = length(i.cppos.xy);
				col = 1.0;
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
					float c = 1.0;
					col.rgb = c.xxx;
					//col.rgb = lerp( col.rgb, saturate( c.xxx ), saturate( distscale * 2.0 ) );
				}					
				
				col.a *= saturate(2.0-sedge*2.0) * _SatelliteAlpha;
				//col.a += 0.05;
				return col;
			}
			ENDCG
		}
	}
}
