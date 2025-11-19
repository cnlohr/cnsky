Shader "cnlohr/Earth"
{
	//based on Shader "d4rkpl4y3r/BRDF PBS Macro"
	
	Properties
	{
		[Enum(Off, 0, Front, 1, Back, 2)] _Culling ("Culling Mode", Int) = 2
		_RangeFalloff("Cutout", Range(0,1)) = .5
		_MainTexDay("DayText", 2D) = "white" {}
		_MainTexNight("NightTex", 2D) = "white" {}
		[hdr] _Color("Albedo", Color) = (1,1,1,1)
		[Gamma] _Metallic("Metallic", Range(0, 1)) = 0
		_Smoothness("Smoothness", Range(0, 1)) = 0
		_EarthMidnightRotation("Earth Midnight Rotation", float) = 0
		_ManagementTexture ("Management", 2D) = "white" {}
		[UIToggle] _RayTrace ("Ray Trace", float) = 1.0
	}
	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque"
			"RenderPipeline" = "UniversalPipeline"
		}

		Cull [_Culling]

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


			uniform float4 _Color;
			uniform float _Metallic;
			uniform float _Smoothness;
			float _RayTrace;
			uniform sampler2D _MainTexDay, _MainTexNight;
			//uniform sampler2D _MainTexDay, _MainTexNight;
			uniform float4 _MainTexDay_ST;
			uniform float _RangeFalloff, _EarthMidnightRotation;
			float4 _ManagementTexture_TexelSize;
			Texture2D< float4 > _ManagementTexture;


			struct appdata
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float2 uv : TEXCOORD0;
#ifdef LIGHTMAP_ON
				float2 lightmapUV : TEXCOORD1;
#endif
#ifdef DYNAMICLIGHTMAP_ON
				float2 dynamicLightmapUV : TEXCOORD2;
#endif
			};

			struct v2f
			{
				float3 objectOrigin : OBP;
				float3 rayOrigin : RAYORIGIN;
				float3 rayDir : RAYDIR;
				float vtxFogFactor : FOGFACTOR;
				float2 uv : TEXCOORD1;

#ifdef LIGHTMAP_ON
				float2 lightmapUV : LIGHTMAPUV;
#endif
#ifdef DYNAMICLIGHTMAP_ON
				float2 dynamicLightmapUV : DYNAMICLIGHTMAPUV;
#endif
#if R_ADDITIONAL_LIGHTS_VTX
				float3 vtxLightContrib : VERTEXLIGHTCONTRIB;
#endif

				float4 pos : SV_POSITION;
				float3 vtxNormalWS : NORMALWS;
				float4 vtxTangentWS : TANGENT;
				float3 positionWS : POSITIONWS;
				float3 vPos : VPOSC;
			};


			v2f vert(appdata v)
			{
				v2f o = (v2f)0;
				o.objectOrigin = mul(unity_ObjectToWorld, float4(0.0,0.0,0.0,1.0) );
				// Thanks ben dot com.
				// I saw these ortho shadow substitutions in a few places, but bgolus explains them
				// https://bgolus.medium.com/rendering-a-sphere-on-a-quad-13c92025570c
				float howOrtho = UNITY_MATRIX_P._m33; // instead of unity_OrthoParams.w
				float3 worldSpaceCameraPos = UNITY_MATRIX_I_V._m03_m13_m23; // instead of _WorldSpaceCameraPos
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex);
				float3 cameraToVertex = worldPos - worldSpaceCameraPos;
				float3 orthoFwd = -UNITY_MATRIX_I_V._m02_m12_m22; // often seen: -UNITY_MATRIX_V[2].xyz;
				float3 orthoRayDir = orthoFwd * dot(cameraToVertex, orthoFwd);
				// start from the camera plane (can also just start from o.vertex if your scene is contained within the geometry)
				float3 orthoCameraPos = worldPos - orthoRayDir;

				o.rayOrigin = lerp(worldSpaceCameraPos, orthoCameraPos, howOrtho );
				o.rayDir = normalize( lerp( cameraToVertex, orthoRayDir, howOrtho ) );
				
				// Switch to view
				o.rayOrigin = mul( UNITY_MATRIX_V, float4( o.rayOrigin, 1.0 ) );
				o.rayDir = mul( UNITY_MATRIX_V, float4( o.rayDir, 0.0 ) );
				
				// Switch back to object.
				o.rayOrigin = mul( float4( o.rayOrigin, 1.0 ), UNITY_MATRIX_IT_MV );
				o.rayDir = mul( float4( o.rayDir, 0.0 ), UNITY_MATRIX_IT_MV ); //?!?!?! Why broke?
				

				o.positionWS = mul(unity_ObjectToWorld, v.vertex);
				o.vPos = v.vertex;
				o.pos = TransformWorldToHClip(o.positionWS);
				o.vtxNormalWS = TransformObjectToWorldNormal(v.normal);
				o.vtxTangentWS = float4( TransformObjectToWorldNormal(v.tangent.xyz), v.tangent.w * GetOddNegativeScale() );
				o.uv = TRANSFORM_TEX(v.uv, _MainTexDay);
#ifdef LIGHTMAP_ON
				OUTPUT_LIGHTMAP_UV( v.lightmapUV, unity_LightmapST, o.lightmapUV );
#endif
#ifdef DYNAMICLIGHTMAP_ON
				o.dynamicLightmapUV = v.dynamicLightmapUV * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#endif
				// Has to be here because we need the pre-clip value.
				// TODO: Error says we can back out the divide-by-w in the fragment shader so
				// we could skip an extra varying. (Raspi users will rejoice)
				o.vtxFogFactor = ComputeFogFactor(o.pos.z);

#if R_ADDITIONAL_LIGHTS_VTX
				o.vtxLightContrib = VertexLighting( o.positionWS, o.vtxNormalWS );
#endif

				return o;
			}

			float4 frag(v2f i) : SV_TARGET
			{
				float4 positionCS = i.pos;
				float3 vtxNormalWS = normalize(i.vtxNormalWS);
				float4 vtxTangentWS = i.vtxTangentWS;
				float2 uv = i.uv;
#ifdef LIGHTMAP_ON
				float2 lightmapUV = i.lightmapUV;
#endif
#ifdef DYNAMICLIGHTMAP_ON
				float2 dynamicLightmapUV = i.dynamicLightmapUV;
#endif
				float2 uvbase = uv;
				float3 positionWS = i.positionWS.xyz;
				float3 vPos = i.vPos.xyz;
				float vtxFogFactor = i.vtxFogFactor;
				float4 shadowCoord = TransformWorldToShadowCoord( positionWS );
				float3 normalTS = float3( 0., 0., 1. );
#if R_ADDITIONAL_LIGHTS_VTX
				float3 vtxLightContrib = i.vtxLightContrib;
#endif
				float smoothness = _Smoothness;
				float metallic = _Metallic;
				float clearCoat = 0.;
				float clearCoatSmoothness = 0.;


				float4 InfoBlock0 = _ManagementTexture.Load( int3( 0, _ManagementTexture_TexelSize.w - 1, 0 ) );
				float fFTime = InfoBlock0.z;
				
				float lambda;
				float phi;
				
				if( _RayTrace )
				{
					float3 rayOrigin = i.rayOrigin;
					float3 rayDir = normalize( vPos - rayOrigin );//(i.rayDir);

					float4 sphere = float4( 0, 0, 0, 0.5 );
					float bestHitDistance = 1e20;
					float3 bestHitNormal = 0.0;
					float3 bestHitPosition = 0.0;
					// Calculate distance along the ray where the sphere is intersected
					float3 d = rayOrigin - sphere.xyz;
					float p1 = -dot(rayDir, d);
					float p2sqr = p1 * p1 - dot(d, d) + sphere.w * sphere.w;
					if (p2sqr < 0)
						discard;
					float p2 = sqrt(p2sqr);
					float t = p1 - p2 > 0 ? p1 - p2 : p1 + p2;
					if (t > 0 && t < bestHitDistance)
					{
						bestHitPosition = rayOrigin + t * rayDir;
						bestHitNormal = normalize(bestHitPosition - sphere.xyz);
						bestHitDistance = t;
					}
					else
					{
						discard;
					}

	
					lambda = atan2( bestHitPosition.z, bestHitPosition.x );
					phi = atan2( length(bestHitPosition.xz), bestHitPosition.y );
					vPos = bestHitPosition;
					positionWS = mul( UNITY_MATRIX_M, float4( bestHitPosition, 1.0 ) );
					vtxNormalWS = normalize( mul( UNITY_MATRIX_M, float4( bestHitNormal, 0.0 ) ) );
				}
				else
				{
					lambda = atan2( i.vPos.z, i.vPos.x );
					phi = atan2( length(i.vPos.xz), i.vPos.y );
				}
				
				lambda -= fFTime*3.1415926535*2 + _EarthMidnightRotation;
				
				uv.x = (lambda/2.0);
				uv.y = -phi;
				
				uv.x = frac( uv.x / 3.1415926535 + 1 ); 
				uv.y = frac( uv.y / 3.1415926535 + 1 ); 
				//uv = clamp( uv, 0.0, .99 );
				
				
				float dayness = saturate( dot( vtxNormalWS, normalize(_MainLightPosition.xyz) )  * 6.0);
				float4 texCol = lerp( tex2Dgrad(_MainTexNight, uv, ddx(uvbase), ddy(uvbase) ), tex2Dgrad(_MainTexDay, uv, ddx(uvbase), ddy(uvbase)), dayness ) * _Color;
				clip(texCol.a - _RangeFalloff);

				float4 albedo = texCol;
				float4 emission = 0;

				//////////////////////////////////////////////////////////////////////////////////

				FragData fd;
				fd.positionCS = positionCS;
				fd.positionWS = positionWS;
				fd.vtxNormalWS = vtxNormalWS;
				fd.vtxTangentWS = vtxTangentWS;
				fd.uv = uv;
#ifdef LIGHTMAP_ON
				fd.lightmapUV = lightmapUV;
#endif
#ifdef DYNAMICLIGHTMAP_ON
				fd.dynamicLightmapUV = dynamicLightmapUV;
#endif
#if R_ADDITIONAL_LIGHTS_VTX
			    fd.vertexLight = vtxLightContrib;
#else
				fd.vertexLight = 0;
#endif
				fd.fogFactor = vtxFogFactor;
    			fd.shadowCoord = shadowCoord;
				fd.vertexSH = 0; // Basis unsupported (Very slow)
			    fd.probeOcclusion = 1;


				InputData id = (InputData)0;
				InitializeInputData(fd, normalTS, id);
				InitializeBakedGIData(fd, id);

				SurfaceData sd = (SurfaceData)0;
				sd.albedo = albedo;
				sd.metallic = metallic;
				sd.specular = 1.0;
				sd.smoothness = smoothness;
				sd.normalTS = normalTS;
				sd.emission = emission;
				sd.occlusion = 1.; // TODO: Do we have an occlusion texture.
				sd.alpha = albedo.w;
				sd.clearCoatMask = clearCoat;
				sd.clearCoatSmoothness = clearCoatSmoothness;

				float4 col = UniversalFragmentPBR( id, sd );

				//col.xyz = vtxTangentWS;
				return col;
			}

			float4 fragDepth(v2f i) : SV_Target
			{
				float alpha = _Color.a;
				if (_RangeFalloff > 0)
					alpha *= tex2D(_MainTexDay, i.uv).a;
				clip(alpha - _RangeFalloff);
				//SHADOW_CASTER_FRAGMENT(i)
				return 1.0;
			}

			float4 fragNormal(v2f i) : SV_Target
			{
				float alpha = _Color.a;
				if (_RangeFalloff > 0)
					alpha *= tex2D(_MainTexDay, i.uv).a;
				clip(alpha - _RangeFalloff);


				float3 vtxNormalWS = normalize(i.vtxNormalWS);
				float2 uv = i.uv;
				float2 uvbase = uv;
				float3 positionWS = i.positionWS.xyz;
				float3 vPos = i.vPos.xyz;
				
				float4 InfoBlock0 = _ManagementTexture.Load( int3( 0, _ManagementTexture_TexelSize.w - 1, 0 ) );
				float fFTime = InfoBlock0.z;
				
				float lambda;
				float phi;

				if( _RayTrace )
				{
					float3 rayOrigin = i.rayOrigin;
					float3 rayDir = normalize( vPos - rayOrigin );//(i.rayDir);

					float4 sphere = float4( 0, 0, 0, 0.5 );
					float bestHitDistance = 1e20;
					float3 bestHitNormal = 0.0;
					float3 bestHitPosition = 0.0;
					// Calculate distance along the ray where the sphere is intersected
					float3 d = rayOrigin - sphere.xyz;
					float p1 = -dot(rayDir, d);
					float p2sqr = p1 * p1 - dot(d, d) + sphere.w * sphere.w;
					if (p2sqr < 0)
						discard;
					float p2 = sqrt(p2sqr);
					float t = p1 - p2 > 0 ? p1 - p2 : p1 + p2;
					if (t > 0 && t < bestHitDistance)
					{
						bestHitPosition = rayOrigin + t * rayDir;
						bestHitNormal = normalize(bestHitPosition - sphere.xyz);
						bestHitDistance = t;
					}
					else
					{
						discard;
					}

					lambda = atan2( bestHitPosition.z, bestHitPosition.x );
					phi = atan2( length(bestHitPosition.xz), bestHitPosition.y );
					vPos = bestHitPosition;
					positionWS = mul( UNITY_MATRIX_M, float4( bestHitPosition, 1.0 ) );
					vtxNormalWS = normalize( mul( UNITY_MATRIX_M, float4( bestHitNormal, 0.0 ) ) );
				}
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
}
