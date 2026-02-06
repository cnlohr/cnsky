Shader "Unlit/Stars-Geo-Shader"
{
    Properties
    {
		_Hip2 ("HIPPARCOS Data", 2D) = "" {}
		_ManagementTexture ("Management Texture", 2D) = "" {}
		_InverseScale("InverseScale", float) = 6000
		_StarSizeBase("Star Size Base", float)=0.025
		_StarSizeRel("Star Size Rel", float)=0.025
		_BaseSizeUpscale("Base Size Upscale", float)=1.0
    }
    SubShader
	{
		// UNITY_SHADER_NO_UPGRADE 
		Tags {"Queue"="Transparent-10" "RenderType"="Background"}
		Blend SrcAlpha OneMinusSrcAlpha
		Blend SrcAlpha One // Additive
		Cull Off
		ZWrite Off
		ZTest On
		
		Pass
		{
			CGPROGRAM
			#include "UnityCG.cginc"

			#pragma vertex vert
			#pragma geometry geo
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile_fog
			
			//#include "Assets/cnsky/MSDFShaderPrintf/MSDFShaderPrintf.cginc"
			
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
				
#if defined(UNITY_STEREO_MULTIVIEW_ENABLED) && defined(SHADER_API_GLES3)
				uint gl_Layer : SV_RenderTargetArrayIndex;
#endif

				float4 cppos : CPP;
				nointerpolation float4 starcolor : STARCOLOR;
				UNITY_FOG_COORDS(1)
			};

			float _InverseScale;
			float _TailAlpha;
			float _SatelliteAlpha;
			float _BaseSizeUpscale;
			float _StarSizeRel;
			float _StarSizeBase;
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
			
#if defined(UNITY_STEREO_MULTIVIEW_ENABLED) && defined(SHADER_API_GLES3)
				int eye;
				for( eye = 0; eye < 2; eye ++ )
				{
					unity_StereoEyeIndex = p[0].stereoTargetEyeIndex = eye;
#endif				

				UNITY_SETUP_INSTANCE_ID(p[0]);
				
				#if defined(USING_STEREO_MATRICES)
					float3 PlayerCenterCamera = ( unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1] ) / 2;
				#else
					float3 PlayerCenterCamera = _WorldSpaceCameraPos.xyz;
				#endif

				uint operationID = pid;
				uint thisop = operationID;
				const uint totalsat = (512*461);
				const uint thisstar = thisop;

				// +1 in y term says to skip first row.
				uint2 thisStarImport = uint2( (thisstar % 256), (thisstar / 256) );
				
				float4 StarBlockA = _Hip2.Load( int3( thisStarImport.x*2+0, _Hip2_TexelSize.w - 1 - thisStarImport.y, 0 ) );
				// block B is currently unused.
				float4 StarBlockB = _Hip2.Load( int3( thisStarImport.x*2+1, _Hip2_TexelSize.w - 1 - thisStarImport.y, 0 ) );
				float4 InfoBlock = _ManagementTexture.Load( int3( 0, _ManagementTexture_TexelSize.w - 1, 0 ) );
				float4 ManagementBlock2 = _ManagementTexture.Load( int3( 0, _ManagementTexture_TexelSize.w - 2, 0 ) );
				float jdDay = InfoBlock.y;
				float jdFrac = InfoBlock.z;
				
				int4 StarBlockIntA = asuint( StarBlockA );
				uint4 StarBlockUIntA = asuint( StarBlockA );
				
				
				
				
				
				
				
				
				
				
				
				
				g2f po;

                UNITY_INITIALIZE_OUTPUT(g2f, po);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(po);
  				UNITY_TRANSFER_VERTEX_OUTPUT_STEREO( po, p[0] );

#if defined(UNITY_STEREO_MULTIVIEW_ENABLED) && defined(SHADER_API_GLES3)
				po.gl_Layer = eye;
#endif
				
				float2 srascention, sdeclination;
				sincos( ((uint(StarBlockIntA.r))/4294967296.0) * 6.2831852, srascention.x, srascention.y );
				sincos( StarBlockIntA.g/2147483647.0 * 3.14159, sdeclination.x, sdeclination.y );
				float3 objectCenter = normalize ( float3( -srascention.x * sdeclination.y, srascention.y * sdeclination.y, sdeclination.x )  ).xzy  ;

				float3 newCenter = mul ( UNITY_MATRIX_M, float4(objectCenter.xyz, 0.0 ) )* (_ProjectionParams.z*.98) + PlayerCenterCamera;

				// Emit special block at end.
				float4 csCenter = mul( UNITY_MATRIX_VP, float4( newCenter, 1.0 ) );

				StarBlockB = float4( 
					StarBlockUIntA.b & 0xffff,
					StarBlockUIntA.b >> 16,
					StarBlockUIntA.a & 0xffff,
					StarBlockUIntA.a >> 16 ) / float4( 1000, 1000, 1000, 1000 );
				po.starcolor = StarBlockB.rgba;
				float initmag = StarBlockB.a;

				
				float relsize = _StarSizeRel * initmag;
				float4 rsize = float4( _ScreenParams.y/_ScreenParams.x, 1, 0, 1. ) * relsize +
					float4( 2.0/_ScreenParams.xy, 0.0, 0.0 );
				
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
					po.vertex = csCenter + vtx_ofs[i] * rsize * (_ProjectionParams.z*.98);

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
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( i );

				fixed4 col = float4( i.starcolor.rgb, 1.0 );

				float sedge = length(i.cppos.xy) * .9; // better fill
				
				float disa = i.starcolor.a - sedge;
				col.a = saturate( disa );

				//col.a += 0.05;
				return col;
			}
			ENDCG
		}
	}
}
