// Import raw data in a PNG fle as a float buffer.
// This is NaN preserving.
Shader "SatelliteStuff/FloatImport"
{
	Properties
	{
		_ImportTexture ("ImportTexture", 2D) = "white" {}
		[ToggleUI] _DoNotSRGBConvert ("Don't SRGB Convert", float) = 0.0
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }

		Cull Off
		Lighting Off		
		ZWrite Off
		ZTest Always

		Pass
		{
			CGPROGRAM

			#include "UnityCustomRenderTexture.cginc"
			#pragma vertex CustomRenderTextureVertexShader
			#pragma fragment frag
			#pragma target 5.0

			#define glsl_mod(x,y) (((x)-(y)*floor((x)/(y))))
			
			#include "UnityCG.cginc"
			
			Texture2D<float4> _ImportTexture;
			float _DoNotSRGBConvert;
			
			/*
			inline float GammaToLinearSpaceExact (float value)
			{
				if (value <= 0.04045F)
					return value / 12.92F;
				else if (value < 1.0F)
					return pow((value + 0.055F)/1.055F, 2.4F);
				else
					return pow(value, 2.2F);
			}
			*/
			
			float4 ColorCorrect4( float4 value )
			{
				if( _DoNotSRGBConvert > 0.5 ) return value;
				return float4(
					LinearToGammaSpaceExact( value.x + 0.0001),
					LinearToGammaSpaceExact( value.y + 0.0001),
					LinearToGammaSpaceExact( value.z + 0.0001),
					value.w );
				return value;
			}
			
			uint4 frag (v2f_customrendertexture IN) : SV_Target
			{

				//int2 Coord = float2(IN.localTexcoord.x,1.-IN.localTexcoord.y) * float2( _CustomRenderTextureWidth, _CustomRenderTextureHeight );
				int2 Coord = IN.localTexcoord.xy * float2( _CustomRenderTextureWidth, _CustomRenderTextureHeight );

				uint4 im0 = ColorCorrect4( _ImportTexture[ int2( Coord.x * 4 + 0, Coord.y ) ] ) * 255.55;
				uint4 im1 = ColorCorrect4( _ImportTexture[ int2( Coord.x * 4 + 1, Coord.y ) ] ) * 255.55;
				uint4 im2 = ColorCorrect4( _ImportTexture[ int2( Coord.x * 4 + 2, Coord.y ) ] ) * 255.55;
				uint4 im3 = ColorCorrect4( _ImportTexture[ int2( Coord.x * 4 + 3, Coord.y) ] ) * 255.55;

				uint4 binrep = uint4(
					(im0.a << (uint)24) + (im0.b << (uint)16) + (im0.g << (uint)8) + (im0.r << (uint)0),
					(im1.a << (uint)24) + (im1.b << (uint)16) + (im1.g << (uint)8) + (im1.r << (uint)0),
					(im2.a << (uint)24) + (im2.b << (uint)16) + (im2.g << (uint)8) + (im2.r << (uint)0),
					(im3.a << (uint)24) + (im3.b << (uint)16) + (im3.g << (uint)8) + (im3.r << (uint)0)
				);
				return binrep;
				//loat4 ret = asfloat( binrep );
				//return ret;
			}

			ENDCG
		}
	}
}
