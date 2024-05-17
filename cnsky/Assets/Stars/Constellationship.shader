Shader "Unlit/Constellationship"
{
    Properties
    {
		_Hip2 ("HIPPARCOS Data", 2D) = "" {}
		_ManagementTexture ("Management Texture", 2D) = "" {}
		_ConstellationshipTexture ("Management Texture", 2D) = "" {}
		
		_InverseScale("InverseScale", float) = 6000
		_BaseAlpha("Base Alpha", float ) = 0.1
		_StarSizeBase("Line Size Base", float)=0.025
		_StarSizeRel("Line Size Rel", float)=0.025
		_BaseSizeUpscale("Base Size Upscale", float)=1.0
    }
    SubShader
	{
		// UNITY_SHADER_NO_UPGRADE 
		Tags {"Queue"="Transparent-2" "RenderType"="Background"}
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
				nointerpolation float3 starcolor : STARCOLOR;
				UNITY_FOG_COORDS(1)
			};

			float _BaseAlpha;
			float _InverseScale;
			float _TailAlpha;
			float _SatelliteAlpha;
			float _BaseSizeUpscale;
			float _StarSizeRel;
			float _StarSizeBase;
			Texture2D< float4 > _ConstellationshipTexture;
			float4 _ConstellationshipTexture_TexelSize;
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
				const uint thisconst = thisop;

				// +1 in y term says to skip first row.
				uint2 thisConstImport = uint2( (thisconst % 1024), 1 );
				float4 ConstSel = _ConstellationshipTexture.Load( int3( thisConstImport.x, _ConstellationshipTexture_TexelSize.w - 1 - thisConstImport.y, 0 ) );
				uint4 StarCodes = asuint( ConstSel );

				float4 InfoBlock = _ManagementTexture.Load( int3( 0, _ManagementTexture_TexelSize.w - 1, 0 ) );
				float4 ManagementBlock2 = _ManagementTexture.Load( int3( 0, _ManagementTexture_TexelSize.w - 2, 0 ) );
				float jdDay = InfoBlock.y;
				float jdFrac = InfoBlock.z;

				float4 rsize = float4( _ScreenParams.y/_ScreenParams.x, 1, 0, 1. ) * _StarSizeRel + _StarSizeBase;

				uint2 thisStarImport;
				thisStarImport = uint2( (StarCodes.x % 256), (StarCodes.x / 256) );
				int4 Star1 = asuint( _Hip2.Load( int3( thisStarImport.x*2+0, _Hip2_TexelSize.w - 1 - thisStarImport.y, 0 ) ) );
				thisStarImport = uint2( (StarCodes.y % 256), (StarCodes.y / 256) );
				int4 Star2 = asuint( _Hip2.Load( int3( thisStarImport.x*2+0, _Hip2_TexelSize.w - 1 - thisStarImport.y, 0 ) ) );
				thisStarImport = uint2( (StarCodes.z % 256), (StarCodes.z / 256) );
				int4 Star3 = asuint( _Hip2.Load( int3( thisStarImport.x*2+0, _Hip2_TexelSize.w - 1 - thisStarImport.y, 0 ) ) );
				thisStarImport = uint2( (StarCodes.w % 256), (StarCodes.w / 256) );
				int4 Star4 = asuint( _Hip2.Load( int3( thisStarImport.x*2+0, _Hip2_TexelSize.w - 1 - thisStarImport.y, 0 ) ) );
				
				int4 StarBlockIntA = Star1;
				
				float2 srascention, sdeclination;
				sincos( ((uint(StarBlockIntA.r))/4294967296.0) * 6.2831852, srascention.x, srascention.y );
				sincos( StarBlockIntA.g/2147483647.0 * 3.14159, sdeclination.x, sdeclination.y );
				float3 objectCenter0 = normalize ( float3( -srascention.x * sdeclination.y, srascention.y * sdeclination.y, sdeclination.x )  ).xzy  * (_ProjectionParams.z*.99) + PlayerCenterCamera;

				StarBlockIntA = Star2;
				sincos( ((uint(StarBlockIntA.r))/4294967296.0) * 6.2831852, srascention.x, srascention.y );
				sincos( StarBlockIntA.g/2147483647.0 * 3.14159, sdeclination.x, sdeclination.y );
				float3 objectCenter1 = normalize ( float3( -srascention.x * sdeclination.y, srascention.y * sdeclination.y, sdeclination.x )  ).xzy  * (_ProjectionParams.z*.99) + PlayerCenterCamera;

				StarBlockIntA = Star3;
				sincos( ((uint(StarBlockIntA.r))/4294967296.0) * 6.2831852, srascention.x, srascention.y );
				sincos( StarBlockIntA.g/2147483647.0 * 3.14159, sdeclination.x, sdeclination.y );
				float3 objectCenter2 = normalize ( float3( -srascention.x * sdeclination.y, srascention.y * sdeclination.y, sdeclination.x )  ).xzy  * (_ProjectionParams.z*.99) + PlayerCenterCamera;

				StarBlockIntA = Star4;
				sincos( ((uint(StarBlockIntA.r))/4294967296.0) * 6.2831852, srascention.x, srascention.y );
				sincos( StarBlockIntA.g/2147483647.0 * 3.14159, sdeclination.x, sdeclination.y );
				float3 objectCenter3 = normalize ( float3( -srascention.x * sdeclination.y, srascention.y * sdeclination.y, sdeclination.x )  ).xzy  * (_ProjectionParams.z*.99) + PlayerCenterCamera;
		
				g2f po;
				UNITY_INITIALIZE_OUTPUT(g2f, po);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(po);
				
				// Emit special block at end.
				float4 csCenter[4];
				float3 csWorldCenter[4];
				csCenter[0] = mul( UNITY_MATRIX_VP, float4( objectCenter0.xyz, 1.0 ) );
				csWorldCenter[0] = mul( UNITY_MATRIX_M, float4( objectCenter0, 1.0 ) );
				csCenter[1] = mul( UNITY_MATRIX_VP, float4( objectCenter1.xyz, 1.0 ) );
				csWorldCenter[1] = mul( UNITY_MATRIX_M, float4( objectCenter1, 1.0 ) );
				csCenter[2] = mul( UNITY_MATRIX_VP, float4( objectCenter2.xyz, 1.0 ) );
				csWorldCenter[2] = mul( UNITY_MATRIX_M, float4( objectCenter2, 1.0 ) );
				csCenter[3] = mul( UNITY_MATRIX_VP, float4( objectCenter3.xyz, 1.0 ) );
				csWorldCenter[3] = mul( UNITY_MATRIX_M, float4( objectCenter3, 1.0 ) );

				float4 vtx_ofs[4] = {
					{-1, 0, 0, 0 },
					{ 1, 0, 0, 0 },
					{-1,  1, 0, 0 },
					{ 1,  1, 0, 0 } };

				int i;
				int seg;
				for( seg = 0; seg < 2; seg++ )
				{
					float4 csFrom = csCenter[seg*2+0];
					float3 csWorldFrom = csWorldCenter[seg*2+0];
					float4 csTo = csCenter[seg*2+1];
					float3 csWorldTo = csWorldCenter[seg*2+1];
					
					float4 csOrtho = float4( normalize(csTo.xy - csFrom.xy).yx * float2( -1, 1 ), 0, 0 );
					float4 csExtend = float4( normalize(csTo.xy - csFrom.xy).xy * float2( 1, 1 ), 0, 0 );
					
					float scale = ( rsize * (_ProjectionParams.z*.997));
					float genlen = length( csTo.xy - csFrom.xy );
					float3 csOrthoWorld = normalize(csWorldTo.xyz - csWorldFrom.xyz);
					
					po.cppos = float4( vtx_ofs[0].xy, genlen, scale );
					po.vertex = csFrom + ( csOrtho - csExtend )* rsize * (_ProjectionParams.z*.997);
					UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(po); UNITY_TRANSFER_FOG(po,po.vertex); triStream.Append(po);

					po.cppos = float4( vtx_ofs[1].xy, genlen, scale );
					po.vertex = csFrom + ( -csOrtho - csExtend ) * rsize * (_ProjectionParams.z*.997);
					UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(po); UNITY_TRANSFER_FOG(po,po.vertex); triStream.Append(po);

					po.cppos = float4( vtx_ofs[2].xy, genlen, scale );
					po.vertex = csTo + ( csOrtho + csExtend ) * rsize * (_ProjectionParams.z*.997);
					UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(po); UNITY_TRANSFER_FOG(po,po.vertex); triStream.Append(po);

					po.cppos = float4( vtx_ofs[3].xy, genlen, scale );
					po.vertex = csTo + ( -csOrtho + csExtend ) * rsize * (_ProjectionParams.z*.997);
					UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(po); UNITY_TRANSFER_FOG(po,po.vertex); triStream.Append(po);
					triStream.RestartStrip();

				}
			}
			
			float3 projectIntoPlane( float3 n,  float3 b )
			{
				n = normalize( n );
				return cross( n, cross( b, n ) ) + n * dot( n, b );
			}
			
			fixed4 frag (g2f i) : SV_Target
			{
				float4 col = 1.0;
				float4 cppos = i.cppos;
				float genlen = cppos.z;
				float scale = cppos.w;

				cppos.y = ( cppos.y*((genlen+2))/scale-1);
				float dist =  length( cppos.x );
				float dist2 = length( cppos.xy );

				float cpposy2 = ( (1.0-i.cppos.y)*((genlen+2))/scale-1);
				float dist3 = length( float2( cppos.x, cpposy2 ) );
				
				//return cppos.y;
				if( cppos.y < 0 ) 
					dist = dist2;	
					
				if( cpposy2 < 0 )
					dist = dist3;

				col.a = 1.0 - dist;
				col.a *= _BaseAlpha;
				return saturate( col );
			}
			ENDCG
		}
	}
}
