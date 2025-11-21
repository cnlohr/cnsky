Shader "Custom/ClampTexture"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Metallic ("Metallic", Range(0,1)) = 0.0
		_Smoothness("Smoothness", Range(0, 1)) = 0
    }
    SubShader
    {
		Tags
		{
			"RenderType" = "Opaque"
			"RenderPipeline" = "UniversalPipeline"
		}

		Cull [_Culling]

		//ZWrite Off  (If you want it for instance)
		Blend SrcAlpha OneMinusSrcAlpha


		HLSLINCLUDE

		#pragma target 5.0
		

#define UNITY_UNIFIED_SHADER_PRECISION_MODEL

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

#if defined(SHADER_API_MOBILE) // Android/iOS
    #define R_ADDITIONAL_LIGHTS_FRAG    0
    #define R_ADDITIONAL_LIGHTS_VTX     2 
    #define R_FORWARD_PLUS              0
    #define R_SCREEN_SPACE_GI           0
#else // PC
    #define R_ADDITIONAL_LIGHTS_FRAG    1
    #define R_ADDITIONAL_LIGHTS_VTX     0
    #define R_FORWARD_PLUS              1 // Was 2
    #define R_SCREEN_SPACE_GI           0
#endif

#define R_ADAPTIVE_PROBE_VOLUMES    1   // 1 - multi-compile L1 and L2, 2 - L1 forced on, 3 - l1+l2 forced on
#define R_LIGHTMAP_VARIANTS         1
#define R_LIGHT_LAYERS              1
#define R_USE_RENDERING_LAYERS      0
#define R_DOTS_INSTANCING           0 
#define R_DECAL_BUFFER              0

#define _NORMALMAP 

#include_with_pragmas "/Assets/cnsky/URPDefaultLighting.hlsl"



		float4 _Color;
        sampler2D _MainTex;
		float _Metallic;
		float _Smoothness;


		struct appdata
		{	
			BASIS_APPDATA_DEFAULT
		};

		struct v2f
		{
			V2F_BASIS_DEFAULT
		};

		v2f vert(appdata v)
		{
			v2f o = (v2f)0;
			BASIS_VERT_DEFAULT_SETUP( o, v )

			o.uv = v.uv;
		
			BASIS_VERT_DEFAULT( o, v )
			return o;
		}


		float4 frag(v2f i) : SV_TARGET
		{
			BASIS_FRAG_DEFAULT_SETUP( i )
		    float4 col = saturate( tex2D (_MainTex, i.uv) ) * _Color;

			//////////////////////////////////////////////////////////////////////////////////
			albedo = col;
			emission = 0.0;

			BASIS_FRAG_DEFAULT_END()

			return colorShaded;
		}


		float4 fragDepth(v2f i) : SV_Target
		{
			BASIS_FRAG_DEFAULT_SETUP( i )
			return 1.0;
		}

		float4 fragNormal(v2f i) : SV_Target
		{
			BASIS_FRAG_DEFAULT_SETUP( i )
			return float4( vtxNormalWS, 1.0 );
		}

        ENDHLSL

		Pass
		{
			Tags { "LightMode" = "DepthOnly" }
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment fragDepth
			ENDHLSL
		}

		Pass
		{
			Tags { "LightMode" = "DepthNormals" }
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment fragNormal
			ENDHLSL
		}

		Pass
		{
			Tags { "LightMode" = "UniversalForward" }
			Blend One Zero
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			ENDHLSL
		}

    }
    FallBack "Diffuse"
}
