Shader "Unlit/Stars"
{
    Properties
    {
		_Hip2 ("HIPPARCOS Data", 2D) = "" {}
		_ManagementTexture ("Management Texture", 2D) = "" {}
		_InverseScale("InverseScale", float) = 6000
		_StarSizeBase("Satellite Size Base", float)=0.025
		_StarSizeRel("Satellite Size Rel", float)=0.025
		_BaseSizeUpscale("Base Size Upscale", float)=1.0
    }
    SubShader
	{
		// UNITY_SHADER_NO_UPGRADE 
		Tags {"Queue"="Transparent-10" "RenderType"="Background"}
		Blend SrcAlpha OneMinusSrcAlpha
		Blend SrcAlpha One // Additive
		Cull Off
		ZWrite Off
		ZTest On
		
		Pass
		{
			CGPROGRAM
			#include "UnityCG.cginc"

			#pragma vertex vert
			#pragma geometry geo
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile_fog
			
			#include "Assets/MSDFShaderPrintf/MSDFShaderPrintf.cginc"
			
			struct appdata
			{
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2g
			{
				uint id : ID;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			struct g2f
			{
				UNITY_VERTEX_OUTPUT_STEREO
				float4 vertex : SV_POSITION;
				float4 cppos : CPP;
				nointerpolation float4 starinfo : STARINFO;
				nointerpolation float3 starcolor : STARCOLOR;
				UNITY_FOG_COORDS(1)
			};

			float _InverseScale;
			float _TailAlpha;
			float _SatelliteAlpha;
			float _BaseSizeUpscale;
			float _StarSizeRel;
			float _StarSizeBase;
			Texture2D< float4 > _ManagementTexture;
			float4 _ManagementTexture_TexelSize;
			Texture2D< float4 > _Hip2;
			float4 _Hip2_TexelSize;

			v2g vert (appdata v, uint id : SV_VertexID, uint iid : SV_InstanceID  )
			{
				v2g t;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_OUTPUT(v2g, t);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(t);
				t.id = id;
				return t;
			}

		
			[maxvertexcount(36)]
			void geo(point v2g p[1], inout TriangleStream<g2f> triStream, uint pid : SV_PrimitiveID )
			{
				#if defined(USING_STEREO_MATRICES)
					float3 PlayerCenterCamera = ( unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1] ) / 2;
				#else
					float3 PlayerCenterCamera = _WorldSpaceCameraPos.xyz;
				#endif

				uint operationID = pid;
				uint thisop = operationID;
				const uint totalsat = (512*461);
				const uint thisstar = thisop;

				// +1 in y term says to skip first row.
				uint2 thisStarImport = uint2( (thisstar % 256), (thisstar / 256) );
				
				float4 StarBlockA = _Hip2.Load( int3( thisStarImport.x*2+0, _Hip2_TexelSize.w - 1 - thisStarImport.y, 0 ) );
				float4 StarBlockB = _Hip2.Load( int3( thisStarImport.x*2+1, _Hip2_TexelSize.w - 1 - thisStarImport.y, 0 ) );
				float4 InfoBlock = _ManagementTexture.Load( int3( 0, _ManagementTexture_TexelSize.w - 1, 0 ) );
				float4 ManagementBlock2 = _ManagementTexture.Load( int3( 0, _ManagementTexture_TexelSize.w - 2, 0 ) );
				float jdDay = InfoBlock.y;
				float jdFrac = InfoBlock.z;
				
				int4 StarBlockIntA = asuint( StarBlockA );
				
				float2 srascention, sdeclination;
				sincos( ((uint(StarBlockIntA.r))/4294967296.0) * 6.2831852, srascention.x, srascention.y );
				sincos( StarBlockIntA.g/2147483647.0 * 3.14159, sdeclination.x, sdeclination.y );
				float3 objectCenter = normalize ( float3( -srascention.x * sdeclination.y, srascention.y * sdeclination.y, sdeclination.x )  ).xzy  * (_ProjectionParams.z*.998) + PlayerCenterCamera;
		
				g2f po;
				UNITY_INITIALIZE_OUTPUT(g2f, po);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(po);
				
				// Emit special block at end.
				float4 csCenter = mul( UNITY_MATRIX_VP, float4( objectCenter.xyz, 1.0 ) );
				float3 csWorldCenter = mul( UNITY_MATRIX_M, float4( objectCenter, 1.0 ) );
				
				// Parallax
				// MAG
				// BV
				// VI
				float4 starinfo = po.starinfo = StarBlockB;
				
				float4 rsize = float4( _ScreenParams.y/_ScreenParams.x, 1, 0, 1. ) * _StarSizeRel + _StarSizeBase;
				
				
				
				float bv = StarBlockB.b;
				float vi = StarBlockB.a;

				//Color temperature in kelvin
				float t = 4600 * ((1 / ((0.92 * bv) + 1.7)) +(1 / ((0.92 * bv) + 0.62)) );
				// t to xyY
				float x = 0, y = 0;
				if (t>=1667 && t<=4000) {
				  x = ((-0.2661239 * pow(10,9)) / pow(t,3)) + ((-0.2343580 * pow(10,6)) / pow(t,2)) + ((0.8776956 * pow(10,3)) / t) + 0.179910;
				} else if (t > 4000 && t <= 25000) {
				  x = ((-3.0258469 * pow(10,9)) / pow(t,3)) + ((2.1070379 * pow(10,6)) / pow(t,2)) + ((0.2226347 * pow(10,3)) / t) + 0.240390;
				}

				if (t >= 1667 && t <= 2222) {
				  y = -1.1063814 * pow(x,3) - 1.34811020 * pow(x,2) + 2.18555832 * x - 0.20219683;
				} else if (t > 2222 && t <= 4000) {
				  y = -0.9549476 * pow(x,3) - 1.37418593 * pow(x,2) + 2.09137015 * x - 0.16748867;
				} else if (t > 4000 && t <= 25000) {
				  y = 3.0817580 * pow(x,3) - 5.87338670 * pow(x,2) + 3.75112997 * x - 0.37001483;
				}
				float Y = (y == 0)? 0 : 1;
				float X = (y == 0)? 0 : (x * Y) / y;
				float Z = (y == 0)? 0 : ((1 - x - y) * Y) / y;
				po.starcolor =  float3(
					 0.41847 * X - 0.15866 * Y - 0.082835 * Z,
					 -0.091169 * X + 0.25243 * Y + 0.015708 * Z,
					0.00092090 * X - 0.0025498 * Y + 0.17860 * Z );


				
				float4 vtx_ofs[4] = {
					{-1, -1, 0, 0},
					{ 1, -1, 0, 0},
					{-1,  1, 0, 0},
					{ 1,  1, 0, 0}
					};
				int i;
				for( i = 0; i < 4; i++ )
				{
					po.cppos = vtx_ofs[i];
					po.vertex = csCenter + vtx_ofs[i] * rsize * (_ProjectionParams.z*.998);

					UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(po);
					UNITY_TRANSFER_FOG(po,po.vertex);
					triStream.Append(po);
				}
			}
			
			float3 projectIntoPlane( float3 n,  float3 b )
			{
				n = normalize( n );
				return cross( n, cross( b, n ) ) + n * dot( n, b );
			}
			
			fixed4 frag (g2f i) : SV_Target
			{
				float initialmag = (15.-i.starinfo.y)/16;
				float mag = exp(-i.starinfo.y);
				float bright = mag*200.+.15;
				
				fixed4 col = float4( i.starcolor, 1.0 );
				
				float sedge = length(i.cppos.xy);
				
				
				float disa = initialmag - sedge;
				col.rgb *= bright;
				col.a = saturate( disa );

				#if 0
				 // Add offset
				uv.x += 0.33;
				uv.y -= 0.0;

				uv = uv * float2( 8.0, 4.0 ) * clamp( .05 + distscale, 0.1, 1.0 );

				uint2 textcoord = floor( uv );
				if( uv.x < 0 || uv.y < 0 || uv.y > 2 || distscale < 0.1 || textcoord.x >= 12 )
				{
					//Outside bounds
				}
				else
				{
					// When in zoom mode, bez2 contains where we can look for more info.
					float c = 1.0;
					col.rgb = c.xxx;
					//col.rgb = lerp( col.rgb, saturate( c.xxx ), saturate( distscale * 2.0 ) );
				}					
				
				col.a *= saturate(2.0-sedge*2.0) * _SatelliteAlpha;
				#endif
				//col.a += 0.05;
				return col;
			}
			ENDCG
		}
	}
}
