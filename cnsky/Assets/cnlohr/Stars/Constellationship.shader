Shader "Unlit/Constellationship-VERT"
{
    Properties
    {
		_Hip2 ("HIPPARCOS Data", 2D) = "" {}
		_ConstellationshipTexture ("Constellationship Texture", 2D) = "" {}
		
		_InverseScale("InverseScale", float) = 6000
		_BaseAlpha("Base Alpha", float ) = 0.1
		_StarSizeBase("Line Size Base", float)=0.025
		_StarSizeRel("Line Size Rel", float)=0.025
		_BaseSizeUpscale("Base Size Upscale", float)=1.0
		
		_EnableHorizonness( "Enable Horizonness", float ) = 0.0
		_HorizonnessShift( "Horizonness Shift", float ) = 0.0
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
			#pragma fragment frag
			#pragma target 5.0

			struct appdata
			{
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f
			{
				UNITY_VERTEX_OUTPUT_STEREO
				float4 vertex : SV_POSITION;
				float4 cppos : CPP;
				float horizonness : HORIZONNESS;
			};

			float _BaseAlpha;
			float _InverseScale;
			float _TailAlpha;
			float _SatelliteAlpha;
			float _BaseSizeUpscale;
			float _StarSizeRel;
			float _StarSizeBase;
			float _EnableHorizonness;
			float _HorizonnessShift;
			Texture2D< float4 > _ConstellationshipTexture;
			float4 _ConstellationshipTexture_TexelSize;

			Texture2D< float4 > _Hip2;
			float4 _Hip2_TexelSize;

			v2f vert (appdata v, uint id : SV_VertexID  )
			{
				UNITY_SETUP_INSTANCE_ID(v);

				v2f po = (v2f)0;
                UNITY_INITIALIZE_OUTPUT(v2f, po);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(po);

				int segid = id % 6;
				if( segid >= 3 ) segid -= 2;
				// segid = 0..3 for the point on the square.
				int quadno = id / 6;

				#if defined(USING_STEREO_MATRICES)
					float3 PlayerCenterCamera = ( unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1] ) / 2;
				#else
					float3 PlayerCenterCamera = _WorldSpaceCameraPos.xyz;
				#endif

				uint thisconst = quadno / 2;

				// +1 in y term says to skip first row.
				uint2 thisConstImport = uint2( (thisconst % 1024), 1 );
				float4 ConstSel = _ConstellationshipTexture.Load( int3( thisConstImport.x, _ConstellationshipTexture_TexelSize.w - 1 - thisConstImport.y, 0 ) );
				uint4 StarCodes = asuint( ConstSel );
				
				uint2 StarCodesPair = ( quadno % 2 ) ? StarCodes.xy : StarCodes.zw;

				float4 rsize = float4( _ScreenParams.y/_ScreenParams.x, 1, 0, 1. ) * _StarSizeRel + _StarSizeBase;

				uint2 thisStarImport;
				thisStarImport = uint2( (StarCodesPair.x % 256), (StarCodesPair.x / 256) );
				int4 Star1 = asuint( _Hip2.Load( int3( thisStarImport.x*2+0, _Hip2_TexelSize.w - 1 - thisStarImport.y, 0 ) ) );
				thisStarImport = uint2( (StarCodesPair.y % 256), (StarCodesPair.y / 256) );
				int4 Star2 = asuint( _Hip2.Load( int3( thisStarImport.x*2+0, _Hip2_TexelSize.w - 1 - thisStarImport.y, 0 ) ) );
				
				int4 StarBlockIntA = Star1;
				
				float2 srascention, sdeclination;
				sincos( ((uint(StarBlockIntA.r))/4294967296.0) * 6.2831852, srascention.x, srascention.y );
				sincos( StarBlockIntA.g/2147483647.0 * 3.14159, sdeclination.x, sdeclination.y );
				float3 objectCenter0 = normalize ( float3( -srascention.x * sdeclination.y, srascention.y * sdeclination.y, sdeclination.x )  ).xzy;

				StarBlockIntA = Star2;
				sincos( ((uint(StarBlockIntA.r))/4294967296.0) * 6.2831852, srascention.x, srascention.y );
				sincos( StarBlockIntA.g/2147483647.0 * 3.14159, sdeclination.x, sdeclination.y );
				float3 objectCenter1 = normalize ( float3( -srascention.x * sdeclination.y, srascention.y * sdeclination.y, sdeclination.x )  ).xzy;

				// Emit special block at end.
				float4 csCenter[2];
				float3 csWorldCenter[2];
				float3 newCenter0 = mul ( UNITY_MATRIX_M, float4(objectCenter0.xyz, 0.0 ) )* (_ProjectionParams.z*.97) + PlayerCenterCamera;
				float3 newCenter1 = mul ( UNITY_MATRIX_M, float4(objectCenter1.xyz, 0.0 ) )* (_ProjectionParams.z*.97) + PlayerCenterCamera;

				// Emit special block at end.
				csCenter[0] = mul( UNITY_MATRIX_VP, float4( newCenter0, 1.0 ) );
				csWorldCenter[0] = float4( newCenter0, 1.0 );
				csCenter[1] = mul( UNITY_MATRIX_VP, float4( newCenter1, 1.0 ) );
				csWorldCenter[1] = float4( newCenter1, 1.0 );

				float4 vtx_ofs[4] = {
					{-1, 0, 0, 0 },
					{ 1, 0, 0, 0 },
					{-1,  1, 0, 0 },
					{ 1,  1, 0, 0 } };


				float4 csFrom = csCenter[0];
				float3 csWorldFrom = csWorldCenter[0];
				float4 csTo = csCenter[1];
				float3 csWorldTo = csWorldCenter[1];
				
				float4 csOrtho = float4( normalize(csTo.xy - csFrom.xy).yx * float2( -1, 1 ), 0, 0 );
				float4 csExtend = float4( normalize(csTo.xy - csFrom.xy).xy * float2( 1, 1 ), 0, 0 );
				
				float scale = ( rsize * (_ProjectionParams.z*.98));
				float genlen = length( csTo.xy - csFrom.xy );
				float3 csOrthoWorld = normalize(csWorldTo.xyz - csWorldFrom.xyz);
				
				float2 rsc = vtx_ofs[segid].xy;
				
				po.cppos = float4( vtx_ofs[segid].xy, genlen, scale );
				//po.vertex = csFrom + ( csOrtho * rsc.x + csExtend * rsc.y* genlen ) * rsize * (_ProjectionParams.z*.98);
				po.vertex = ((segid<2)?csFrom:csTo) + ( csOrtho * rsc.x ) * rsize * (_ProjectionParams.z*.97);

				float3 ncnorm = normalize(((segid<2)?newCenter0:newCenter1) - PlayerCenterCamera );
				float yness = ncnorm.y;
				float calcHorizonness = 1.0 - yness * 10.0;
				po.horizonness = saturate( 1.0 - (calcHorizonness * _EnableHorizonness + _HorizonnessShift) );
				return po;
			}
			
			float3 projectIntoPlane( float3 n,  float3 b )
			{
				n = normalize( n );
				return cross( n, cross( b, n ) ) + n * dot( n, b );
			}
			
			fixed4 frag (v2f i) : SV_Target
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
				
				col.a *= i.horizonness;
				
				col.a *= _BaseAlpha;
				return saturate( col );
			}
			ENDCG
		}
	}
}
