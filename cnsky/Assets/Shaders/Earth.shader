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
			uniform sampler2D _MainTexDay, _MainTexNight;
			uniform float4 _MainTexDay_ST;
			uniform float _Cutoff;

			struct v2f
			{
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
				
				float lambda = atan2( i.vPos.z, i.vPos.x );
				float phi = atan2( length(i.vPos.xz), i.vPos.y );
				uv.x = lambda/2.0;
				uv.y = -phi;
				
				uv.x = frac( uv.x / 3.14159 + 1 ); 
				uv.y = frac( uv.y / 3.14159 + 1 ); 
				//uv = clamp( uv, 0.0, .99 );
				
				float dayness = saturate( dot( normal, normalize(_WorldSpaceLightPos0.xyz) )  * 6.0);
				float4 texCol = lerp( tex2D(_MainTexNight, uv), tex2D(_MainTexDay, uv), dayness ) * _Color;
				clip(texCol.a - _Cutoff);
				

				UNITY_LIGHT_ATTENUATION(attenuation, i, i.wPos.xyz);

				float3 specularTint;
				float oneMinusReflectivity;
				float smoothness = _Smoothness;
				float3 albedo = DiffuseAndSpecularFromMetallic(
					texCol, _Metallic, specularTint, oneMinusReflectivity
				);
				
				float3 viewDir = normalize(_WorldSpaceCameraPos - i.wPos);
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
