Shader "cnlohr/Earth"
{
	//based on Shader "d4rkpl4y3r/BRDF PBS Macro"
	
	Properties
	{
		[Enum(Off, 0, Front, 1, Back, 2)] _Culling ("Culling Mode", Int) = 2
		_Cutoff("Cutout", Range(0,1)) = .5
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
			"RenderType"="Opaque"
			"Queue"="Geometry"
		}

		Cull [_Culling]

		CGINCLUDE
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			#include "UnityPBSLighting.cginc"

			uniform float4 _Color;
			uniform float _Metallic;
			uniform float _Smoothness;
			float _RayTrace;
			uniform sampler2D _MainTexDay, _MainTexNight;
			//uniform sampler2D _MainTexDay, _MainTexNight;
			uniform float4 _MainTexDay_ST;
			uniform float _Cutoff, _EarthMidnightRotation;
			float4 _ManagementTexture_TexelSize;
			Texture2D< float4 > _ManagementTexture;

			struct v2f
			{
				float3 objectOrigin : OBP;
				float3 rayOrigin : RAYORIGIN;
				float3 rayDir : RAYDIR;

				#ifndef UNITY_PASS_SHADOWCASTER
				float4 pos : SV_POSITION;
				float3 normal : NORMAL;
				float3 wPos : WPOSC;
				float3 vPos : VPOSC;
				
				
				SHADOW_COORDS(3)
				#else
				V2F_SHADOW_CASTER;
				#endif
				float2 uv : TEXCOORD1;
			};

			v2f vert(appdata_base v)
			{
				v2f o;
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
				
				
				#ifdef UNITY_PASS_SHADOWCASTER
				TRANSFER_SHADOW_CASTER_NOPOS(o, o.pos);
				#else
				o.wPos = mul(unity_ObjectToWorld, v.vertex);
				o.vPos = v.vertex;
				o.pos = UnityWorldToClipPos(o.wPos);
				o.normal = UnityObjectToWorldNormal(v.normal);
				TRANSFER_SHADOW(o);
				#endif
				o.uv = TRANSFORM_TEX(v.texcoord.xy, _MainTexDay);
				return o;
			}

			#ifndef UNITY_PASS_SHADOWCASTER
			float4 frag(v2f i) : SV_TARGET
			{
				float3 normal = normalize(i.normal);
				float2 uv = i.uv;
				float2 uvbase = uv;
				float3 wPos = i.wPos.xyz;
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
					wPos = mul( UNITY_MATRIX_M, float4( bestHitPosition, 1.0 ) );
					normal = normalize( mul( UNITY_MATRIX_M, float4( bestHitNormal, 0.0 ) ) );
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
				
				
				float dayness = saturate( dot( normal, normalize(_WorldSpaceLightPos0.xyz) )  * 6.0);
				float4 texCol = lerp( tex2Dgrad(_MainTexNight, uv, ddx(uvbase), ddy(uvbase) ), tex2Dgrad(_MainTexDay, uv, ddx(uvbase), ddy(uvbase)), dayness ) * _Color;
				clip(texCol.a - _Cutoff);
				

				UNITY_LIGHT_ATTENUATION(attenuation, i, wPos);

				float3 specularTint;
				float oneMinusReflectivity;
				float smoothness = _Smoothness;
				float3 albedo = DiffuseAndSpecularFromMetallic(
					texCol, _Metallic, specularTint, oneMinusReflectivity
				);
				
				float3 viewDir = normalize(_WorldSpaceCameraPos - wPos);
				UnityLight light;
				light.color = attenuation * _LightColor0.rgb;
				light.dir = normalize(UnityWorldSpaceLightDir(i.wPos));
				UnityIndirect indirectLight;
				#ifdef UNITY_PASS_FORWARDADD
				indirectLight.diffuse = indirectLight.specular = 0;
				#else
				indirectLight.diffuse = max(0, ShadeSH9(float4(normal, 1)));
				float3 reflectionDir = reflect(-viewDir, normal);
				Unity_GlossyEnvironmentData envData;
				envData.roughness = 1 - smoothness;
				envData.reflUVW = reflectionDir;
				indirectLight.specular = Unity_GlossyEnvironment(
					UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData
				);
				#endif

				float3 col = UNITY_BRDF_PBS(
					albedo, specularTint,
					oneMinusReflectivity, smoothness,
					normal, viewDir,
					light, indirectLight
				);

				#ifdef UNITY_PASS_FORWARDADD
				return float4(col, 0);
				#else
				return float4(col, 1);
				#endif
			}
			#else
			float4 frag(v2f i) : SV_Target
			{
				float alpha = _Color.a;
				if (_Cutoff > 0)
					alpha *= tex2D(_MainTexDay, i.uv).a;
				clip(alpha - _Cutoff);
				SHADOW_CASTER_FRAGMENT(i)
			}
			#endif
		ENDCG

		Pass
		{
			Tags { "LightMode" = "ForwardBase" }
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase_fullshadows
			#pragma multi_compile UNITY_PASS_FORWARDBASE
			ENDCG
		}

		Pass
		{
			Tags { "LightMode" = "ForwardAdd" }
			Blend One One
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile UNITY_PASS_FORWARDADD
			ENDCG
		}

		Pass
		{
			Tags { "LightMode" = "ShadowCaster" }
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster
			#pragma multi_compile UNITY_PASS_SHADOWCASTER
			ENDCG
		}
	}
}
