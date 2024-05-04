Shader "Unlit/TestMSDFSurface"
{
	Properties
	{
		_MSDFTex ("MSDF Texture", 2DArray) = "white" {}
	}
	SubShader
	{
		Tags {"Queue"="Transparent" "RenderType"="Transparent"}

		Pass
		{
			//ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha
		
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog

			#include "UnityCG.cginc"
			#include "../MSDFShaderPrintf.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
			};

	
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				// sample the texture
				float2 inuv = i.uv;
				inuv.y = 1.0 - inuv.y;
				
				float2 tuv = frac( inuv * 16 );
				float2 iuv = floor( inuv * 16 );
				float index = iuv.x + iuv.y * 16;
				
				float2 smoothUv = inuv*16.0;
				float2 screenPxRange = MSDFCalcScreenPxRange( smoothUv );
				float base = MSDFEval(tuv, index, screenPxRange, smoothUv);
				float shadow = MSDFEval(tuv, index, screenPxRange, smoothUv, 15, 0.3);
				fixed4 col = float4( base.xxx, shadow.x );

				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
