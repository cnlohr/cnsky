Shader "Custom/TestURP"
{
	Properties
	{
		[MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
		[MainTexture] _BaseMap("Base Map", 2D) = "white"
	}

	SubShader
	{
		Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

		HLSLINCLUDE


#pragma target 5.0

			#define _WorldSpaceLightPos0 _MainLightPosition
			#define UNITY_UNIFIED_SHADER_PRECISION_MODEL
			#define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) float destName = 1.0;
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

/*
...for the Light struct...
half3 direction 	The direction of the light.
half3 color 	The color of the light.
float distanceAttenuation 	The strength of the light, based on its distance from the object.
half shadowAttenuation 	The strength of the light, based on whether the object is in shadow.
uint layerMask 	The layer mask of the light.*/

#define _LightColor0 GetMainLight().color
//#define UnityWorldSpaceLightDir( float3 pos ) (GetMainLight().dir)

struct UnityLight
{
    half3 color;
    half3 dir;
    half  ndotl; // Deprecated: Ndotl is now calculated on the fly and is no longer stored. Do not used it.
};

#ifdef UNITY_COLORSPACE_GAMMA
#define unity_ColorSpaceGrey fixed4(0.5, 0.5, 0.5, 0.5)
#define unity_ColorSpaceDouble fixed4(2.0, 2.0, 2.0, 2.0)
#define unity_ColorSpaceDielectricSpec half4(0.220916301, 0.220916301, 0.220916301, 1.0 - 0.220916301)
#define unity_ColorSpaceLuminance half4(0.22, 0.707, 0.071, 0.0) // Legacy: alpha is set to 0.0 to specify gamma mode
#else // Linear values
#define unity_ColorSpaceGrey fixed4(0.214041144, 0.214041144, 0.214041144, 0.5)
#define unity_ColorSpaceDouble fixed4(4.59479380, 4.59479380, 4.59479380, 2.0)
#define unity_ColorSpaceDielectricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04) // standard dielectric reflectivity coef at incident angle (= 4%)
#define unity_ColorSpaceLuminance half4(0.0396819152, 0.458021790, 0.00609653955, 1.0) // Legacy: alpha is set to 1.0 to specify linear mode
#endif

inline half OneMinusReflectivityFromMetallic(half metallic)
{
    // We'll need oneMinusReflectivity, so
    //   1-reflectivity = 1-lerp(dielectricSpec, 1, metallic) = lerp(1-dielectricSpec, 0, metallic)
    // store (1-dielectricSpec) in unity_ColorSpaceDielectricSpec.a, then
    //   1-reflectivity = lerp(alpha, 0, metallic) = alpha + metallic*(0 - alpha) =
    //                  = alpha - metallic * alpha
    half oneMinusDielectricSpec = unity_ColorSpaceDielectricSpec.a;
    return oneMinusDielectricSpec - metallic * oneMinusDielectricSpec;
}
			inline half3 DiffuseAndSpecularFromMetallic (half3 albedo, half metallic, out half3 specColor, out half oneMinusReflectivity)
			{
				specColor = lerp (unity_ColorSpaceDielectricSpec.rgb, albedo, metallic);
				oneMinusReflectivity = OneMinusReflectivityFromMetallic(metallic);
				return albedo * oneMinusReflectivity;
			}

		struct Attributes
		{
			float4 positionOS : POSITION;
			float2 uv : TEXCOORD0;
		};

		struct Varyings
		{
			float4 positionHCS : SV_POSITION;
			float2 uv : TEXCOORD0;
		};

		TEXTURE2D(_BaseMap);
		SAMPLER(sampler_BaseMap);

		CBUFFER_START(UnityPerMaterial)
			half4 _BaseColor;
			float4 _BaseMap_ST;
		CBUFFER_END

		Varyings vert(Attributes IN)
		{
			Varyings OUT;
			OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
			OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
			return OUT;
		}

		half4 frag(Varyings IN) : SV_Target
		{
			half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
			return color;
		}
		half4 fragDepth(Varyings IN) : SV_Target
		{
			half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
			return color;
		}
		half4 fragNormal(Varyings IN) : SV_Target
		{
			half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
			return color;
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
}
