// From https://gist.github.com/bgolus/3a561077c86b5bfead0d6cc521097bae
// Thanks to BGolus
Shader "Custom/FloorShader"
{
	Properties
	{
		_Color ("Color", Color) = (1,1,1,1)
		_ColorFloor("Color Floor", Color) = (0,0,0,1)
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
		
		[KeywordEnum(X, Y, Z)] _Axis ("Plane Axis", Float) = 1.0
		[IntRange] _MajorGridDiv ("Major Grid Divisions", Range(2,25)) = 10.0
		_AxisLineWidth ("Axis Line Width", Range(0,1.0)) = 0.04
		_MajorLineWidth ("Major Line Width", Range(0,1.0)) = 0.02
		_MinorLineWidth ("Minor Line Width", Range(0,1.0)) = 0.01

		_MajorLineColor ("Major Line Color", Color) = (1,1,1,1)
		_MinorLineColor ("Minor Line Color", Color) = (1,1,1,1)
		_BaseColor ("Base Color", Color) = (0,0,0,1)

		_XAxisColor ("X Axis Line Color", Color) = (1,0,0,1)
		_XAxisDashColor ("X Axis Dash Color", Color) = (0.5,0,0,1)
		_YAxisColor ("Y Axis Line Color", Color) = (0,1,0,1)
		_YAxisDashColor ("Y Axis Dash Color", Color) = (0,0.5,0,1)
		_ZAxisColor ("Z Axis Line Color", Color) = (0,0,1,1)
		_ZAxisDashColor ("Z Axis Dash Color", Color) = (0,0,0.5,1)
		_AxisDashScale ("Axis Dash Scale", Float) = 1.33
		_CenterColor ("Axis Center Color", Color) = (1,1,1,1)
		_Fade ("Fade", Float) = 0.0
		
		_TANoiseTex( "TANoise", 2D) = "" {}
	}
	SubShader
	{
		Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
		LOD 200

		HLSLINCLUDE
		// Physically based Standard lighting model, and enable shadows on all light types
		//#pragma shader_feature _ _AXIS_X _AXIS_Z // _AXIS_Y is default
		//#pragma surface surf Standard fullforwardshadows

		// Use shader model 3.0 target, to get nicer looking lighting
		//#pragma target 3.0

		#define UNITY_UNIFIED_SHADER_PRECISION_MODEL
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

		#define fixed4 float4
		#define fixed2 float2
		#include "Assets/cnsky/cnlohr/tanoise/tanoise.cginc"
		#include "Assets/cnsky/cnlohr/hashwithoutsine/hashwithoutsine.cginc"
		
		sampler2D _MainTex;

		struct Input
		{
			float2 uv_MainTex;
			float3 wPos;
			float3 screenPos;
		};

		float _MajorLineWidth, _MinorLineWidth, _AxisLineWidth, _AxisDashScale;
		half4 _MajorLineColor, _MinorLineColor, _XAxisColor, _XAxisDashColor, _YAxisColor, _YAxisDashColor, _ZAxisColor, _ZAxisDashColor, _CenterColor;

		half _Glossiness;
		half _Metallic;
		fixed4 _Color, _ColorFloor;
		float _Fade;

		float _GridScale, _MajorGridDiv;

		#if defined(_AXIS_X)
			#define AXIS_COMPONENTS yz
		#elif defined(_AXIS_Z)
			#define AXIS_COMPONENTS xy
		#else
			#define AXIS_COMPONENTS xz
		#endif


		// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
		// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
		// #pragma instancing_options assumeuniformscaling
		UNITY_INSTANCING_BUFFER_START(Props)
			// put more per-instance properties here
		UNITY_INSTANCING_BUFFER_END(Props)

		struct Attributes
		{
			float4 positionOS : POSITION;
			float2 uv : TEXCOORD0;
		};

		struct Varyings
		{
			float4 positionHCS : SV_POSITION;
			float2 uv : TEXCOORD0;
			float3 wPos : WPOSC;
		};

		TEXTURE2D(_BaseMap);
		SAMPLER(sampler_BaseMap);

		CBUFFER_START(UnityPerMaterial)
			half4 _BaseColor;
			float4 _BaseMap_ST;
		CBUFFER_END

		Varyings vert(Attributes IN)
		{
			Varyings o;
			o.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
			o.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
			o.wPos = mul(unity_ObjectToWorld, IN.positionOS.xyzw);
			return o;
		}


		half4 frag(Varyings IN) : SV_Target
		{
		//	half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
		//	return color;
		//void surf (Input IN, inout SurfaceOutputStandard o)

			float calpha = 1.0;
		#if defined(USING_STEREO_MATRICES)
			float3 PlayerCenterCamera = ( unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1] ) / 2;
		#else
			float3 PlayerCenterCamera = _WorldSpaceCameraPos.xyz;
		#endif
			float4 col = 0.0;
			
			float bright = 1;
			//float cutoff = ( .1 + chash13( float3( IN.wPos.xy * 40, _Time.x*10 ) ) )* ( (  length(IN.wPos-PlayerCenterCamera) - _Fade)); 
			
			float cutoff = ( tanoise4_1d( float4( IN.wPos.xyz*10.0, _Time.x ) )+.1 ) * ( (  length(IN.wPos-PlayerCenterCamera) - _Fade));
			if( _Fade > 0 ) 
				clip(bright - cutoff-.2);
			
			
			
			float div = max(2.0, round(_MajorGridDiv));

			// trick to reduce visual artifacts when far from the world origin
			
			float3 cameraCenteringOffset = floor(_WorldSpaceCameraPos / div) * div;
			float4 uv;
			uv.yx = (IN.wPos - cameraCenteringOffset).AXIS_COMPONENTS;
			uv.wz = IN.wPos.AXIS_COMPONENTS;
			
			float4 uvDDXY = float4(ddx(uv.xy), ddy(uv.xy));
			float2 uvDeriv = float2(length(uvDDXY.xz), length(uvDDXY.yw));

			float axisLineWidth = max(_MajorLineWidth, _AxisLineWidth);
			float2 axisDrawWidth = max(axisLineWidth, uvDeriv);
			float2 axisLineAA = uvDeriv * 1.5;
			float2 axisLines2 = smoothstep(axisDrawWidth + axisLineAA, axisDrawWidth - axisLineAA, abs(uv.zw * 2.0));
			axisLines2 *= saturate(axisLineWidth / axisDrawWidth);

			float2 majorUVDeriv = uvDeriv / div;
			float majorLineWidth = _MajorLineWidth / div;
			float2 majorDrawWidth = clamp(majorLineWidth, majorUVDeriv, 0.5);
			float2 majorLineAA = majorUVDeriv * 1.5;
			float2 majorGridUV = 1.0 - abs(frac(uv.xy / div) * 2.0 - 1.0);
			float2 majorAxisOffset = (1.0 - saturate(abs(uv.zw / div * 2.0))) * 2.0;
			majorGridUV += majorAxisOffset; // adjust UVs so center axis line is skipped
			float2 majorGrid2 = smoothstep(majorDrawWidth + majorLineAA, majorDrawWidth - majorLineAA, majorGridUV);
			majorGrid2 *= saturate(majorLineWidth / majorDrawWidth);
			majorGrid2 = saturate(majorGrid2 - axisLines2); // hack
			majorGrid2 = lerp(majorGrid2, majorLineWidth, saturate(majorUVDeriv * 2.0 - 1.0));

			float minorLineWidth = min(_MinorLineWidth, _MajorLineWidth);
			bool minorInvertLine = minorLineWidth > 0.5;
			float minorTargetWidth = minorInvertLine ? 1.0 - minorLineWidth : minorLineWidth;
			float2 minorDrawWidth = clamp(minorTargetWidth, uvDeriv, 0.5);
			float2 minorLineAA = uvDeriv * 1.5;
			float2 minorGridUV = abs(frac(uv.xy) * 2.0 - 1.0);
			minorGridUV = minorInvertLine ? minorGridUV : 1.0 - minorGridUV;
			float2 minorMajorOffset = (1.0 - saturate((1.0 - abs(frac(uv.zw / div) * 2.0 - 1.0)) * div)) * 2.0;
			minorGridUV += minorMajorOffset; // adjust UVs so major division lines are skipped
			float2 minorGrid2 = smoothstep(minorDrawWidth + minorLineAA, minorDrawWidth - minorLineAA, minorGridUV);
			minorGrid2 *= saturate(minorTargetWidth / minorDrawWidth);
			minorGrid2 = saturate(minorGrid2 - axisLines2); // hack
			minorGrid2 = lerp(minorGrid2, minorTargetWidth, saturate(uvDeriv * 2.0 - 1.0));
			minorGrid2 = minorInvertLine ? 1.0 - minorGrid2 : minorGrid2;
			minorGrid2 = abs(uv.zw) > 0.5 ? minorGrid2 : 0.0;

			half minorGrid = lerp(minorGrid2.x, 1.0, minorGrid2.y);
			half majorGrid = lerp(majorGrid2.x, 1.0, majorGrid2.y);

			float2 axisDashUV = abs(frac((uv.zw + axisLineWidth * 0.5) * _AxisDashScale) * 2.0 - 1.0) - 0.5;
			float2 axisDashDeriv = uvDeriv * _AxisDashScale * 1.5;
			float2 axisDash = smoothstep(-axisDashDeriv, axisDashDeriv, axisDashUV);
			axisDash = uv.zw < 0.0 ? axisDash : 1.0;

		#if defined(UNITY_COLORSPACE_GAMMA)
			half4 xAxisColor = half4(GammaToLinearSpace(_XAxisColor.rgb), _XAxisColor.a);
			half4 yAxisColor = half4(GammaToLinearSpace(_YAxisColor.rgb), _YAxisColor.a);
			half4 zAxisColor = half4(GammaToLinearSpace(_ZAxisColor.rgb), _ZAxisColor.a);
			half4 xAxisDashColor = half4(GammaToLinearSpace(_XAxisDashColor.rgb), _XAxisDashColor.a);
			half4 yAxisDashColor = half4(GammaToLinearSpace(_YAxisDashColor.rgb), _YAxisDashColor.a);
			half4 zAxisDashColor = half4(GammaToLinearSpace(_ZAxisDashColor.rgb), _ZAxisDashColor.a);
			half4 centerColor = half4(GammaToLinearSpace(_CenterColor.rgb), _CenterColor.a);
			half4 majorLineColor = half4(GammaToLinearSpace(_MajorLineColor.rgb), _MajorLineColor.a);
			half4 minorLineColor = half4(GammaToLinearSpace(_MinorLineColor.rgb), _MinorLineColor.a);
			half4 baseColor = half4(GammaToLinearSpace(_BaseColor.rgb), _BaseColor.a);
		#else
			half4 xAxisColor = _XAxisColor;
			half4 yAxisColor = _YAxisColor;
			half4 zAxisColor = _ZAxisColor;
			half4 xAxisDashColor = _XAxisDashColor;
			half4 yAxisDashColor = _YAxisDashColor;
			half4 zAxisDashColor = _ZAxisDashColor;
			half4 centerColor = _CenterColor;
			half4 majorLineColor = _MajorLineColor;
			half4 minorLineColor = _MinorLineColor;
			half4 baseColor = _BaseColor;
		#endif

		#if defined(_AXIS_X)
			half4 aAxisColor = yAxisColor;
			half4 bAxisColor = zAxisColor;
			half4 aAxisDashColor = yAxisDashColor;
			half4 bAxisDashColor = zAxisDashColor;
		#elif defined(_AXIS_Z)
			half4 aAxisColor = xAxisColor;
			half4 bAxisColor = yAxisColor;
			half4 aAxisDashColor = xAxisDashColor;
			half4 bAxisDashColor = yAxisDashColor;
		#else
			half4 aAxisColor = xAxisColor;
			half4 bAxisColor = zAxisColor;
			half4 aAxisDashColor = xAxisDashColor;
			half4 bAxisDashColor = zAxisDashColor;
		#endif

			aAxisColor = lerp(aAxisDashColor, aAxisColor, axisDash.y);
			bAxisColor = lerp(bAxisDashColor, bAxisColor, axisDash.x);
			aAxisColor = lerp(aAxisColor, centerColor, axisLines2.y);

			half4 axisLines = lerp(bAxisColor * axisLines2.y, aAxisColor, axisLines2.x);

			col = lerp(baseColor, minorLineColor, minorGrid *  minorLineColor.a);
			col = lerp(col, majorLineColor, majorGrid * majorLineColor.a);
			col = col * (1.0 - axisLines.a) + axisLines;

		#if defined(UNITY_COLORSPACE_GAMMA)
			col = half4(LinearToGammaSpace(col.rgb), col.a);
		#endif

			// Albedo comes from a texture tinted by color
			//fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			
			float3 c = col * _Color + _ColorFloor;
						
			float3 Albedo = c.rgb;
			// Metallic and smoothness come from slider variables
			float Metallic = _Metallic;
			float Smoothness = _Glossiness;
			float Alpha = calpha;
			return float4( Albedo, 1.0 );
		}
		ENDHLSL


		Pass
		{
			Tags { "LightMode" = "DepthOnly" }
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			ENDHLSL
		}

		Pass
		{
			Tags { "LightMode" = "DepthNormals" }
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
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
