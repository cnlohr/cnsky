Shader "Unlit/TextureMSDFPrint"
{
	Properties
	{
		_MSDFTex ("MSDF Texture", 2DArray) = "white" {}
		_CheckTexture ("Check Texture", 2D) = "white" {}
		[ToggleUI] _HexDisplay( "Hex Display", float ) = 0.0
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
			#include "Packages/com.llealloo.audiolink/Runtime/Shaders/AudioLink.cginc"
		
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

			Texture2D<float4> _CheckTexture;	
			uniform float4 _CheckTexture_TexelSize;
			float _HexDisplay;

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
				float4 col = 0.0;
				
				int lines = 12;
				int columns = 10;
				int supercolumns = 5;
				float2 inuv = i.uv;
				inuv.y = 1.0 - inuv.y;
				float2 uv = inuv * float2( supercolumns * columns, lines );
				int2 dig = floor( uv );

				
				float2 fielduv = inuv;
				fielduv *= float2( supercolumns, lines );
				
				uint2 dpycoord = floor( fielduv );
				uint2 tc = dpycoord / uint2( 1.0, 4.0 );
				
				uint3 datacoord = uint3( tc.x, _CheckTexture_TexelSize.w - tc.y - 1, 0 );

				float4 v4 = _CheckTexture.Load( datacoord );
				float value = 0.0;
				switch( dpycoord.y&3 )
				{
				case 0: value = v4.x; break;
				case 1: value = v4.y; break;
				case 2: value = v4.z; break;
				case 3: value = v4.w; break;
				}

				if( _HexDisplay > 0.5 )
				{
					col += MSDFPrintHex( asuint(value), fielduv, 10, 2 ).xxxy;
				}
				else
				{
					col += MSDFPrintNum( value, fielduv, 14, 6, false, 0 ).xxxy;
				}
				switch (dpycoord.y & 3) { case 0: col.y = 0; col.z = 0; break; case 1: col.x = 0; col.z = 0; break; case 2: col.x = 0; col.y = 0; break; };


				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
