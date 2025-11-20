#pragma once

/* configuration defines, define these before including this file!
 * Define each keyword to 1 to enable a multi-compile, >=2 to define it as
 * always on for options that support it. Disable or set to permanently on
 * as many options as you can, multi-compiles exponentially increase your
 * compilation time even if the keywords get stripped!
 * Use SHADER_API_MOBILE keyword to change settings for android separately
 * Example config:

--------------------------SNIP-------------------------

#if defined(SHADER_API_MOBILE) // Android/iOS
    #define R_ADDITIONAL_LIGHTS_FRAG    0
    #define R_ADDITIONAL_LIGHTS_VTX     2 
    #define R_FORWARD_PLUS              0
    #define R_SCREEN_SPACE_GI           0
#else // PC
    #define R_ADDITIONAL_LIGHTS_FRAG    1
    #define R_ADDITIONAL_LIGHTS_VTX     0
    #define R_FORWARD_PLUS              2
    #define R_SCREEN_SPACE_GI           0
#endif

#define R_ADAPTIVE_PROBE_VOLUMES    1   // 1 - multi-compile L1 and L2, 2 - L1 forced on, 3 - l1+l2 forced on
#define R_LIGHTMAP_VARIANTS         0
#define R_LIGHT_LAYERS              0
#define R_USE_RENDERING_LAYERS      0
#define R_DOTS_INSTANCING           0 
#define R_DECAL_BUFFER              0

#define _NORMALMAP 

--------------------------SNIP-------------------------

*/

#if !defined(R_ADDITIONAL_LIGHTS_FRAG)
    #error R_ADDITIONAL_LIGHTS_FRAG must be defined as 0 (off), 1 (multi-compile), or 2 (always on)
#endif

#if !defined(R_ADDITIONAL_LIGHTS_VTX)
    #error R_ADDITIONAL_LIGHTS_VTX must be defined as 0 (off), 1 (multi-compile), or 2 (always on)
#endif

#if !defined(R_FORWARD_PLUS)
    #error R_FORWARD_PLUS must be defined as 0 (off), 1 (multi-compile), or 2 (always on)
#endif

#if !defined(R_LIGHT_LAYERS)
    #error R_LIGHT_LAYERS must be defined as 0 (off), 1 (multi-compile), or 2 (always on)
#endif

#if !defined(R_SCREEN_SPACE_GI)
    #error R_SCREEN_SPACE_GI must be defined as 0 (off) or 1 (multi-compile)
#endif

#if !defined(R_ADAPTIVE_PROBE_VOLUMES)
    #error R_ADAPTIVE_PROBE_VOLUMES must be defined as 0 (off), 1 (multi-compile), 2 (always L1 only), or 3 (always L1+L2)
#endif

#if !defined(R_LIGHTMAP_VARIANTS)
    #error R_LIGHTMAP_VARIANTS must be defined as either 0 or 1
#endif

#if !defined(R_DOTS_INSTANCING)
    #error R_DOTS_INSTANCING must be defined as either 0 or 1
#endif

#if !defined(R_USE_RENDERING_LAYERS)
    #error R_USE_RENDERING_LAYERS must be defined as either 0 or 1
#endif

#if !defined(R_DECAL_BUFFER)
    #error R_DECAL_BUFFER must be defined as either 0 or 1
#endif

// Prefer to use the DXC compiler. Superior in every way to the old FXC.
// This does not turn on DXC for DX12 since unity makes no distinction
// between 11 and 12, and DXC can't compile for DX11. Additionally, 
// this cannot be used with multi-view stereo without modifying core RP
// includes to change the stereo macros to declare and use the view index
// directly. By default unity uses hlslcc to modify the shader code during
// translation to glsl to replace a dummy variable with the view index. 
// Also, does not work with non-fixed size instancing buffers on Android!
// DXC does not allow using specialization constants as array lengths, and
// unity uses HLSLcc to replace the instancing array lengths with a spec
// constant. Somehow, it still works on nVidia hardware even though it turns
// into out of bounds array accesses?
#if !defined(STEREO_MULTIVIEW_ON)
#pragma use_dxc vulkan
#endif

// Use dynamic branch fog, costs basically nothing and quarters shader size
#define USE_DYNAMIC_BRANCH_FOG_KEYWORD 1
#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Fog.hlsl"


///-------------------------------------------------------------------------
/// Lights
///-------------------------------------------------------------------------


/// Forward+
#if R_FORWARD_PLUS == 1
    #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
    #pragma multi_compile_fragment _ _REFLECTION_PROBE_ATLAS
#elif R_FORWARD_PLUS == 2
    #define _CLUSTER_LIGHT_LOOP
    #define _REFLECTION_PROBE_ATLAS
#endif


// soft shadows. Explicit low/med/high keywords unnecessary, the unqualified _SHADOWS_SOFT does a dynamic branch on the quality
#pragma multi_compile_fragment _ _SHADOWS_SOFT //_SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH

// Assume more than 1 cascade if there's shadows. Not worth adding another 
// keyword for the 1 cascade case. Ignore screenspace shadows as well
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

#pragma multi_compile _ SHADOWS_SHADOWMASK
#pragma multi_compile_fragment _ _LIGHT_COOKIES

#if R_ADDITIONAL_LIGHTS_FRAG == 1
    #pragma multi_compile _ _ADDITIONAL_LIGHTS
    #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
#elif R_ADDITIONAL_LIGHTS_FRAG == 2
    #define  _ADDITIONAL_LIGHTS
    #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
#endif

#if R_ADDITIONAL_LIGHTS_VTX == 1
    #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX
#elif R_ADDITIONAL_LIGHTS_FRAG == 2
    #define _ADDITIONAL_LIGHTS_VERTEX
#endif

#if R_LIGHT_LAYERS == 1
    #pragma multi_compile _ _LIGHT_LAYERS
#elif R_LIGHT_LAYERS == 2
    #define _LIGHT_LAYERS
#endif

// box projection is cheap enough that it isn't worth a keyword ever
#define _REFLECTION_PROBE_BOX_PROJECTION

#pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
#pragma multi_compile_fragment _ REFLECTION_PROBE_ROTATION

#if R_SCREEN_SPACE_GI
    #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
    #pragma multi_compile_fragment _ _SCREEN_SPACE_IRRADIANCE
#endif

#if R_DECAL_BUFFER
    #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
#endif

#include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"

#pragma multi_compile_fragment _ DEBUG_DISPLAY

#if R_ADAPTIVE_PROBE_VOLUMES == 1
    #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ProbeVolumeVariants.hlsl"
#elif R_ADAPTIVE_PROBE_VOLUMES == 2
    #define PROBE_VOLUMES_L1
#elif R_ADAPTIVE_PROBE_VOLUMES == 3
    #define PROBE_VOLUMES_L2
#endif

//--------------------------------------
// GPU Instancing
#pragma multi_compile_instancing


#if R_USE_RENDERING_LAYERS
    #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"
    #pragma instancing_options renderinglayer
#endif


#if R_DOTS_INSTANCING
    #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
#endif

#if R_LIGHTMAP_VARIANTS
    #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
    #pragma multi_compile _ DIRLIGHTMAP_COMBINED
    #pragma multi_compile _ LIGHTMAP_ON
    #pragma multi_compile _ DYNAMICLIGHTMAP_ON
    #pragma multi_compile _ USE_LEGACY_LIGHTMAPS
    #pragma multi_compile_fragment _ LIGHTMAP_BICUBIC_SAMPLING
#endif

#define REQUIRES_WORLD_SPACE_POS_INTERPOLATOR

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"


SurfaceData GetDefaultSurfaceData()
{
    SurfaceData s =
    {
		half3(1, 1, 1),         // half3 albedo;
		kDielectricSpec.xyz,    // half3 specular;
		half(0),                // half  metallic;
		half(0.25),             // half  smoothness;
		half3(0, 0, 1),         // half3 normalTS;
		half3(0, 0, 0),         // half3 emission;
		half(1),                // half  occlusion;
		half(1),                // half  alpha;
		half(0),                // half  clearCoatMask;
		half(0)                 // half  clearCoatSmoothness;
	};
    return s;
}

struct FragData
{
	float4  positionCS;
	float3  positionWS;
	float3  vtxNormalWS;
	half4   vtxTangentWS;
	float2  uv;
	float2  lightmapUV;
	float2  dynamicLightmapUV;
    half3   vertexLight;
	half    fogFactor;
    float4  shadowCoord;
	half3   vertexSH;
    float4  probeOcclusion;
};

FragData GetDefaultFragData()
{
    FragData outp = 
    {
        (float4) 0,         // float4  positionCS;
    	(float3) 0,         // float3  positionWS;
    	float3(0, 1, 0),    // float3  vtxNormalWS;
    	half4(1,0,0,1),     // half4   vtxTangentWS;
    	(float2) 0,         // float2  uv;
    	(float2) 0,         // float2  lightmapUV;
    	(float2) 0,         // float2  dynamicLightmapUV;
        (half3) 0,          // half3   vertexLight;
    	(half) 0,           // half    fogFactor;
        float4(0,0,0,0),    // float4  shadowCoord;
    	(half3)0,           // half3   vertexSH;
        float4(1, 1, 1, 1)  // float4  probeOcclusion;
    };
    return outp;
}

void InitializeInputData(FragData input, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    inputData.positionWS = input.positionWS;
#endif

#if defined(DEBUG_DISPLAY)
    inputData.positionCS = input.positionCS;
#endif

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
#if defined(_NORMALMAP) || defined(_DETAIL)
    float sgn = input.vtxTangentWS.w;      // should be either +1 or -1
    float3 bitangent = sgn * cross(input.vtxNormalWS.xyz, input.vtxTangentWS.xyz);
    half3x3 tangentToWorld = half3x3(input.vtxTangentWS.xyz, bitangent.xyz, input.vtxNormalWS.xyz);

    #if defined(_NORMALMAP)
    inputData.tangentToWorld = tangentToWorld;
    #endif
    inputData.normalWS = TransformTangentToWorld(normalTS, tangentToWorld);
#else
    inputData.normalWS = input.vtxNormalWS;
#endif

    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = viewDirWS;

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    inputData.shadowCoord = input.shadowCoord;
#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
#else
    inputData.shadowCoord = float4(0, 0, 0, 0);
#endif
#ifdef _ADDITIONAL_LIGHTS_VERTEX
    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor.x);
    inputData.vertexLighting = input.VertexLight.xyz;
#else
    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);
#endif

    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);

    #if defined(DEBUG_DISPLAY)
    #if defined(DYNAMICLIGHTMAP_ON)
    inputData.dynamicLightmapUV = input.dynamicLightmapUV;
    #endif
    #if defined(LIGHTMAP_ON)
    inputData.staticLightmapUV = input.staticLightmapUV;
    #else
    inputData.vertexSH = input.vertexSH;
    #endif
    #if defined(USE_APV_PROBE_OCCLUSION)
    inputData.probeOcclusion = input.probeOcclusion;
    #endif
    #endif
}

void InitializeBakedGIData(FragData input, inout InputData inputData)
{
#if defined(DYNAMICLIGHTMAP_ON)
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
#elif !defined(LIGHTMAP_ON) && (defined(PROBE_VOLUMES_L1) || defined(PROBE_VOLUMES_L2))
    inputData.bakedGI = SAMPLE_GI(input.vertexSH,
        GetAbsolutePositionWS(inputData.positionWS),
        inputData.normalWS,
        inputData.viewDirectionWS,
        input.positionCS.xy,
        input.probeOcclusion,
        inputData.shadowMask);
#else
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
#endif
}


