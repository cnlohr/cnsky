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
#elif defined(DEBUG_DISPLAY)
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
#endif
}


////////////////////////////////////////////////////////////////////////////////////////////////

#ifdef LIGHTMAP_ON
#define BASIS_APPDATA_LIGHTMAP float2 lightmapUV : TEXCOORD1;
#else
#define BASIS_APPDATA_LIGHTMAP
#endif

#ifdef DYNAMICLIGHTMAP_ON
#define BASIS_APPDATA_DYNAMICLIGHTMAP float2 dynamicLightmapUV : TEXCOORD2;
#else
#define BASIS_APPDATA_DYNAMICLIGHTMAP 
#endif

#define BASIS_APPDATA_DEFAULT \
	float4 vertex : POSITION; \
	float3 normal : NORMAL; \
	float4 tangent : TANGENT; \
	float2 uv : TEXCOORD0; \
	BASIS_APPDATA_DYNAMICLIGHTMAP \
	BASIS_APPDATA_LIGHTMAP \
	UNITY_VERTEX_INPUT_INSTANCE_ID



#ifdef LIGHTMAP_ON
#define V2F_BASIS_DEFAULT_LIGHTMAP float2 lightmapUV : LIGHTMAPUV;
#else
#define V2F_BASIS_DEFAULT_LIGHTMAP
#endif

#ifdef DYNAMICLIGHTMAP_ON
#define V2F_BASIS_DEFAULT_DYNAMICLIGHTMAP float2 dynamicLightmapUV : DYNAMICLIGHTMAPUV;
#else
#define V2F_BASIS_DEFAULT_DYNAMICLIGHTMAP
#endif

#if R_ADDITIONAL_LIGHTS_VTX
#define V2F_BASIS_DEFAULT_VTX_LIGHTS float3 vtxLightContrib : VERTEXLIGHTCONTRIB;
#else
#define V2F_BASIS_DEFAULT_VTX_LIGHTS
#endif



#define V2F_BASIS_DEFAULT \
	float4 pos : SV_POSITION; \
	float2 uv : TEXCOORD1; \
	V2F_BASIS_DEFAULT_LIGHTMAP \
	V2F_BASIS_DEFAULT_DYNAMICLIGHTMAP \
	V2F_BASIS_DEFAULT_VTX_LIGHTS \
	float3 vtxNormalWS : NORMALWS; \
	float4 vtxTangentWS : TANGENT; \
	float3 positionWS : POSITIONWS; \
	float3 vPos : VPOSC; \
	UNITY_VERTEX_INPUT_INSTANCE_ID \
	UNITY_VERTEX_OUTPUT_STEREO \
	float vtxFogFactor : FOG;


#define BASIS_VERT_DEFAULT_SETUP( o, v ) \
	UNITY_SETUP_INSTANCE_ID(v); \
	UNITY_TRANSFER_INSTANCE_ID(v, o); \
	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

#ifdef LIGHTMAP_ON
#define BASIS_VERT_DEFAULT_LIGHTMAP( o, v )				OUTPUT_LIGHTMAP_UV( v.lightmapUV, unity_LightmapST, o.lightmapUV );
#else
#define BASIS_VERT_DEFAULT_LIGHTMAP( o, v )
#endif

#ifdef DYNAMICLIGHTMAP_ON
#define BASIS_VERT_DEFAULT_DYNAMICLIGHTMAP( o, v )		o.dynamicLightmapUV = v.dynamicLightmapUV * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#else
#define BASIS_VERT_DEFAULT_DYNAMICLIGHTMAP( o, v )
#endif


#if R_ADDITIONAL_LIGHTS_VTX
#define BASIS_VERT_DEFAULT_VTX_LIGHTS( o, v ) o.vtxLightContrib = VertexLighting( o.positionWS, o.vtxNormalWS );
#else
#define BASIS_VERT_DEFAULT_VTX_LIGHTS( o, v )
#endif

// Note: Fog Has to be here because we need the pre-clip value.
// TODO: Error says we can back out the divide-by-w in the fragment shader so
// we could skip an extra varying. (Raspi users will rejoice)

#define BASIS_VERT_DEFAULT( o, v ) \
	o.positionWS = mul(unity_ObjectToWorld, v.vertex); \
	o.vPos = v.vertex; \
	o.pos = TransformWorldToHClip(o.positionWS); \
	o.vtxNormalWS = TransformObjectToWorldNormal(v.normal); \
	o.vtxTangentWS = float4( TransformObjectToWorldNormal(v.tangent.xyz), v.tangent.w * GetOddNegativeScale() ); \
	BASIS_VERT_DEFAULT_LIGHTMAP( o, v ) \
	BASIS_VERT_DEFAULT_DYNAMICLIGHTMAP( o, v ) \
	o.vtxFogFactor = ComputeFogFactor(o.pos.z); \
	BASIS_VERT_DEFAULT_VTX_LIGHTS( o, v )


#ifdef LIGHTMAP_ON
#define BASIS_FRAG_DEFAULT_SETUP_LIGHTMAP( i ) float2 lightmapUV = i.lightmapUV;
#else
#define BASIS_FRAG_DEFAULT_SETUP_LIGHTMAP( i )
#endif

#ifdef DYNAMICLIGHTMAP_ON
#define BASIS_FRAG_DEFAULT_SETUP_DYNAMICLIGHTMAP( i ) float2 dynamicLightmapUV = i.dynamicLightmapUV;
#else
#define BASIS_FRAG_DEFAULT_SETUP_DYNAMICLIGHTMAP( i )
#endif

#if R_ADDITIONAL_LIGHTS_VTX
#define BASIS_FRAG_DEFAULT_SETUP_ADDITIONAL_LIGHTS_VTX( i ) float3 vtxLightContrib = i.vtxLightContrib;
#else
#define BASIS_FRAG_DEFAULT_SETUP_ADDITIONAL_LIGHTS_VTX( i )
#endif

#define BASIS_FRAG_DEFAULT_SETUP( i ) \
	UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i); \
	float4 positionCS = i.pos; \
	float3 vtxNormalWS = normalize(i.vtxNormalWS); \
	float4 vtxTangentWS = i.vtxTangentWS; \
	float2 uv = i.uv; \
	BASIS_FRAG_DEFAULT_SETUP_LIGHTMAP( i ) \
	BASIS_FRAG_DEFAULT_SETUP_DYNAMICLIGHTMAP( i ) \
	float2 uvbase = uv; \
	float3 positionWS = i.positionWS.xyz; \
	float3 vPos = i.vPos.xyz; \
	float vtxFogFactor = i.vtxFogFactor; \
	float4 shadowCoord = TransformWorldToShadowCoord( positionWS ); \
	float3 normalTS = float3( 0., 0., 1. ); \
	BASIS_FRAG_DEFAULT_SETUP_ADDITIONAL_LIGHTS_VTX( i ) \
	float smoothness = _Smoothness; \
	float metallic = _Metallic; \
	float clearCoat = 0.; \
	float clearCoatSmoothness = 0.; \
	float4 albedo = 0.0; \
	float4 emission = 0.0;



#ifdef LIGHTMAP_ON
#define BASIS_FRAG_DEFAULT_END_LIGHTMAP  fd.lightmapUV = lightmapUV;
#else
#define BASIS_FRAG_DEFAULT_END_LIGHTMAP
#endif

#ifdef DYNAMICLIGHTMAP_ON
#define BASIS_FRAG_DEFAULT_END_DYNAMICLIGHTMAP fd.dynamicLightmapUV = dynamicLightmapUV;
#else
#define BASIS_FRAG_DEFAULT_END_DYNAMICLIGHTMAP
#endif

#if R_ADDITIONAL_LIGHTS_VTX
#define BASIS_FRAG_DEFAULT_END_ADDITIONAL_LIGHTS  fd.vertexLight = vtxLightContrib;
#else
#define BASIS_FRAG_DEFAULT_END_ADDITIONAL_LIGHTS  fd.vertexLight = 0;
#endif


#define BASIS_FRAG_DEFAULT_END() \
	FragData fd; \
	fd.positionCS = positionCS; \
	fd.positionWS = positionWS; \
	fd.vtxNormalWS = vtxNormalWS; \
	fd.vtxTangentWS = vtxTangentWS; \
	fd.uv = uv; \
	BASIS_FRAG_DEFAULT_END_LIGHTMAP \
	BASIS_FRAG_DEFAULT_END_DYNAMICLIGHTMAP \
	BASIS_FRAG_DEFAULT_END_ADDITIONAL_LIGHTS \
	fd.fogFactor = vtxFogFactor; \
	fd.shadowCoord = shadowCoord; \
	fd.vertexSH = 0; /* Basis unsupported (Very slow) */ \
    fd.probeOcclusion = 1; \
	InputData id = (InputData)0; \
	InitializeInputData(fd, normalTS, id); \
	InitializeBakedGIData(fd, id); \
	SurfaceData sd = (SurfaceData)0; \
	sd.albedo = albedo; \
	sd.metallic = metallic; \
	sd.specular = 1.0; \
	sd.smoothness = smoothness; \
	sd.normalTS = normalTS; \
	sd.emission = emission; \
	sd.occlusion = 1.; /* TODO: Do we have an occlusion texture. */ \
	sd.alpha = albedo.w; \
	sd.clearCoatMask = clearCoat; \
	sd.clearCoatSmoothness = clearCoatSmoothness; \
	float4 colorShaded = UniversalFragmentPBR( id, sd ); \



/** FYI For unlit shaders...
  appdata contains 	UNITY_VERTEX_INPUT_INSTANCE_ID
  v2f contains 	UNITY_VERTEX_OUTPUT_STEREO
  UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o) in vertex shader
  UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i) in fragment shader
*/


