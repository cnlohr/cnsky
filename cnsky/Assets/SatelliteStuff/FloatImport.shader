// Import raw data in a PNG fle as a float buffer.
// This is NaN preserving.
Shader "SatelliteStuff/FloatImport"
{
	Properties
	{
		_ImportTexture ("ImportTexture", 2D) = "white" {}
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

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
			#pragma target 4.0

			#define glsl_mod(x,y) (((x)-(y)*floor((x)/(y))))
			
			#include "UnityCG.cginc"
			
			Texture2D<float4> _ImportTexture;
			
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
				return float4(
					LinearToGammaSpaceExact( value.x + 0.0001),
					LinearToGammaSpaceExact( value.y + 0.0001),
					LinearToGammaSpaceExact( value.z + 0.0001),
					value.w );
				return value;
			}
			
			float4 frag (v2f_customrendertexture IN) : SV_Target
			{

				//int2 Coord = float2(IN.localTexcoord.x,1.-IN.localTexcoord.y) * float2( _CustomRenderTextureWidth, _CustomRenderTextureHeight );
				int2 Coord = IN.localTexcoord.xy * float2( _CustomRenderTextureWidth, _CustomRenderTextureHeight );

				uint4 im0 = ColorCorrect4( _ImportTexture.Load( int3( Coord.x * 4 + 0, Coord.y, 0 ) ) ) * 255.55;
				uint4 im1 = ColorCorrect4( _ImportTexture.Load( int3( Coord.x * 4 + 1, Coord.y, 0 ) ) ) * 255.55;
				uint4 im2 = ColorCorrect4( _ImportTexture.Load( int3( Coord.x * 4 + 2, Coord.y, 0 ) ) ) * 255.55;
				uint4 im3 = ColorCorrect4( _ImportTexture.Load( int3( Coord.x * 4 + 3, Coord.y, 0 ) ) ) * 255.55;
								
				uint4 binrep = uint4(
					(im0.a << 24) + (im0.b << 16) + (im0.g << 8) + (im0.r << 0),
					(im1.a << 24) + (im1.b << 16) + (im1.g << 8) + (im1.r << 0),
					(im2.a << 24) + (im2.b << 16) + (im2.g << 8) + (im2.r << 0),
					(im3.a << 24) + (im3.b << 16) + (im3.g << 8) + (im3.r << 0)
				);
				float4 ret = asfloat( binrep );
				//if( isnan( ret.g ) ) ret.g = 44;
				return ret;
			}

			ENDCG
		}
	}
}
