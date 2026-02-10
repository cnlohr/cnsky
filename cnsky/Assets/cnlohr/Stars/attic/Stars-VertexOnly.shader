Shader "Unlit/Stars-VertexOnly"
{
    Properties
    {
		_Hip2 ("HIPPARCOS Data", 2D) = "" {}
		_ManagementTexture ("Management Texture", 2D) = "" {}
		_InverseScale("InverseScale", float) = 6000
		//_StarSizeBase("Star Size Base", float)=0.025
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
			#pragma fragment frag
			#pragma target 5.0
			
//			#pragma multi_compile_instancing
			#pragma multi_compile_fog
			
			struct appdata
			{
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f
			{
				UNITY_VERTEX_INPUT_INSTANCE_ID 
				UNITY_VERTEX_OUTPUT_STEREO
				
				float4 vertex : SV_POSITION;
				float4 cppos : CPP;
				nointerpolation float4 starcolor : STARCOLOR;
				UNITY_FOG_COORDS(1)
			};

			float _InverseScale;
			float _TailAlpha;
			float _SatelliteAlpha;
			float _BaseSizeUpscale;
			float _StarSizeRel;
			//float _StarSizeBase;
			Texture2D< float4 > _ManagementTexture;
			float4 _ManagementTexture_TexelSize;
			Texture2D< float4 > _Hip2;
			float4 _Hip2_TexelSize;

			v2f vert (appdata v, uint id : SV_VertexID, uint iid : SV_InstanceID  )
			{
				v2f t;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_OUTPUT(v2f, t);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(t);
	
				#if defined(USING_STEREO_MATRICES)
					float3 PlayerCenterCamera = ( unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1] ) / 2;
				#else
					float3 PlayerCenterCamera = _WorldSpaceCameraPos.xyz;
				#endif

				const uint thisstar = id/4;

				// +1 in y term says to skip first row.
				uint2 thisStarImport = uint2( (thisstar % 256), (thisstar / 256) );
				
				float4 StarBlockA = _Hip2.Load( int3( thisStarImport.x*2+0, _Hip2_TexelSize.w - 1 - thisStarImport.y, 0 ) );
				// block B is currently unused.
				float4 StarBlockB = _Hip2.Load( int3( thisStarImport.x*2+1, _Hip2_TexelSize.w - 1 - thisStarImport.y, 0 ) );

				int4 StarBlockIntA = asuint( StarBlockA );
				uint4 StarBlockUIntA = asuint( StarBlockA );

				float2 srascention, sdeclination;
				sincos( ((uint(StarBlockIntA.r))/4294967296.0) * 6.2831852, srascention.x, srascention.y );
				sincos( StarBlockIntA.g/2147483647.0 * 3.14159, sdeclination.x, sdeclination.y );
				float3 objectCenter = normalize ( float3( -srascention.x * sdeclination.y, srascention.y * sdeclination.y, sdeclination.x )  ).xzy  ;

				float farPlane = _ProjectionParams.z * .97;
				float3 newCenter = mul( UNITY_MATRIX_MV, float4(objectCenter.xyz, 0.0 ) ) * (farPlane);

				// Emit special block at end.
				float4 csCenter = mul( UNITY_MATRIX_P, float4( newCenter, 1.0 ) );

				StarBlockB = float4( 
					StarBlockUIntA.b & 0xffff,
					StarBlockUIntA.b >> 16,
					StarBlockUIntA.a & 0xffff,
					StarBlockUIntA.a >> 16 ) / float4( 1000, 1000, 1000, 1000 );
				t.starcolor = StarBlockB.rgba;
				float initmag = StarBlockB.a;
				
				float relsize = _StarSizeRel * initmag;
				float4 rsize = float4( _ScreenParams.y/_ScreenParams.x, 1, 0, 1. ) * relsize +
					float4( 2.0/_ScreenParams.xy, 0.0, 0.0 );

				float4 vtx_ofs[4] = {
					{-1, -1, 0, 0},
					{ 1, -1, 0, 0},
					{ 1,  1, 0, 0},
					{-1,  1, 0, 0}
					};
				uint io = id % 4;
				{
					t.cppos = vtx_ofs[io];
					t.vertex = csCenter + vtx_ofs[io] * rsize * (farPlane*.98);
					UNITY_TRANSFER_FOG(t,t.vertex);
				}

				return t;
			}

			float3 projectIntoPlane( float3 n,  float3 b )
			{
				n = normalize( n );
				return cross( n, cross( b, n ) ) + n * dot( n, b );
			}
			
			fixed4 frag (v2f i) : SV_Target
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
