// Import raw data in a PNG fle as a float buffer.
// This is NaN preserving.
Shader "Stars/FloatImport"
{
	Properties
	{
		_ImportTexture ("ImportTexture", 2D) = "white" {}
		[ToggleUI] _DoNotSRGBConvert ("Don't SRGB Convert", float) = 0.0
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
				
				
				///////////////////////////////////////////////////////
				///////////////////////////////////////////////////////
				
				// Parallax
				// MAG
				// BV
				// VI
				
				float4 StarBlockB = float4( 
					binrep.b & 0xffff,
					binrep.b >> 16,
					binrep.a & 0xffff,
					binrep.a >> 16 ) / float4( 100, 1000, 1000, 1000 );

				float4 starinfo = StarBlockB;
				
				
				
				float bv = StarBlockB.b;
				float vi = StarBlockB.a;

				//Color temperature in kelvin
				float tS = 4600 * ((1 / ((0.92 * bv) + 1.7)) +(1 / ((0.92 * bv) + 0.62)) );
				// tS to xyY
				float x = 0, y = 0;
				if (tS>=1667 && tS<=4000) {
				  x = ((-0.2661239 * pow(10,9)) / pow(tS,3)) + ((-0.2343580 * pow(10,6)) / pow(tS,2)) + ((0.8776956 * pow(10,3)) / tS) + 0.179910;
				} else if (tS > 4000 && tS <= 25000) {
				  x = ((-3.0258469 * pow(10,9)) / pow(tS,3)) + ((2.1070379 * pow(10,6)) / pow(tS,2)) + ((0.2226347 * pow(10,3)) / tS) + 0.240390;
				}

				if (tS >= 1667 && tS <= 2222) {
				  y = -1.1063814 * pow(x,3) - 1.34811020 * pow(x,2) + 2.18555832 * x - 0.20219683;
				} else if (tS > 2222 && tS <= 4000) {
				  y = -0.9549476 * pow(x,3) - 1.37418593 * pow(x,2) + 2.09137015 * x - 0.16748867;
				} else if (tS > 4000 && tS <= 25000) {
				  y = 3.0817580 * pow(x,3) - 5.87338670 * pow(x,2) + 3.75112997 * x - 0.37001483;
				}
				float Y = (y == 0)? 0 : 1;
				float X = (y == 0)? 0 : (x * Y) / y;
				float Z = (y == 0)? 0 : ((1 - x - y) * Y) / y;
				float3 starcolor =  float3(
					 0.41847 * X - 0.15866 * Y - 0.082835 * Z,
					 -0.091169 * X + 0.25243 * Y + 0.015708 * Z,
					0.00092090 * X - 0.0025498 * Y + 0.17860 * Z );



				float initialmag = (15.-starinfo.y)/16;
				float mag = exp(-starinfo.y);
				float starbright = mag*200.+.15;

				starcolor *= starbright;
				
				uint R = starcolor.r * 1000;
				uint G = starcolor.g * 1000;
				uint B = starcolor.b * 1000;
				uint SPARE = initialmag*1000.0; // Unused
				binrep.b = R | (G<<16);
				binrep.a = B | (SPARE<<16);
				
				float4 ret = asfloat( binrep );
				
				return ret;
			}

			ENDCG
		}
	}
}
