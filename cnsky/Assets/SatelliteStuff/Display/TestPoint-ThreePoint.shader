Shader "Unlit/TestPoint"
{
	Properties
	{
		_Thickness ("Thickness", float) = 0.1
	}
	SubShader
	{
		Tags {"Queue"="Transparent" "RenderType"="Transparent"}
		Blend SrcAlpha OneMinusSrcAlpha
		//Blend One One // Additive
		Cull Off
			//ZWrite Off
		
		Pass
		{
			CGPROGRAM
			#include "UnityCG.cginc"

			#pragma vertex vert
			#pragma geometry geo
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile_fog
			
			#include "PerBloksgaard-BezierCode.cginc"
			
			struct appdata
			{
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2g
			{
				uint id : ID;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct g2f
			{
				float4 vertex : SV_POSITION;
				float4 bez0 : BEZ0;
				float4 bez1 : BEZ1;
				float4 bez2 : BEZ2;
				float4 cppos : CPP;
				UNITY_FOG_COORDS(1)
			};

			float _Thickness;
			
			v2g vert (appdata v, uint id : SV_VertexID, uint iid : SV_InstanceID  )
			{
				v2g t;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_OUTPUT(v2g, t);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(t);
				t.id = id;
				return t;
			}
			
			[maxvertexcount(32)]
			void geo(point v2g p[1], inout TriangleStream<g2f> triStream, uint pid : SV_PrimitiveID )
			{
				float3 offset = float3( pid* 1.5, 0, 0 );

				float3 bez[3] = {
					{ 0, 0, 0 },
					{ 0, 1, 0 },
					{ 1, 0, 1 } };
					
				bez[1].x = cos( 20*_Time.x )*.2+1;
				bez[1].z = sin( 20*_Time.x )*.2+1;

				bez[0] += offset;
				bez[1] += offset;
				bez[2] += offset;				
				
				g2f po;
				
				// TODO Roll this into the resolve bezier geo.
				po.bez0 = UnityObjectToClipPos( bez[0] );
				po.bez1 = UnityObjectToClipPos( bez[1] );
				po.bez2 = UnityObjectToClipPos( bez[2] );

				float4 clippos[5];
				ResolveBezierGeometry( clippos, bez, _Thickness );

				// UNRESOLVED, Handle shape where center is behind one of the other two.
				
				int vtx;
				for( vtx = 0; vtx < 5; vtx++ )
				{
					float4 cp = clippos[vtx];
					po.vertex = cp;
					po.cppos = po.vertex.xyzw;

					UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(po);

					UNITY_TRANSFER_FOG(po,po.vertex);

					triStream.Append(po);
				}
			}

			fixed4 frag (g2f i) : SV_Target
			{
				fixed4 col = float4( 1.0, 1.0, 1.0, 1.0 );

				float2 cp = i.cppos / i.cppos.w;
				float2 bez0 = i.bez0 / i.bez0.w;
				float2 bez1 = i.bez1 / i.bez1.w;
				float2 bez2 = i.bez2 / i.bez2.w;

				float deres = length( fwidth( cp ) );

				float t;
				float f = calculateDistanceToQuadraticBezier( t, cp, bez0, bez1, bez2 );
				f *= clamp( i.cppos.w, 0.5, .01/deres );

				float tT = frac( _Time.y );
				float tDelta = (t-tT);
				tDelta *= clamp( i.cppos.w, 0.5, .01/deres );
				
				float satDist = length( float2( tDelta, f) );
				satDist *= 50.0;
				float fDist = f*100;
				col.a = saturate( 1.0-fDist ) * 0.5 + saturate( 1.0-satDist ) + .03;
				
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
