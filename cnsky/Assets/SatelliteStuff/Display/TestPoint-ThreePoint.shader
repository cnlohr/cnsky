Shader "Unlit/TestPoint"
{
	Properties
	{
		_TailThick ("Tail Thickness", float) = 0.01
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
			
			#include "IQ-QuadradicBezier.cginc"
			#include "cnlohr-QuadradicBezier.cginc"
			
			struct appdata
			{
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2g
			{
				uint id : ID;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			struct g2f
			{
				float4 vertex : SV_POSITION;
				float4 bez0 : BEZ0;
				float4 bez1 : BEZ1;
				float4 bez2 : BEZ2;
				float4 cppos : CPP;
				UNITY_VERTEX_OUTPUT_STEREO
				UNITY_FOG_COORDS(1)
			};

			
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

				bez[0].xyz += offset;
				bez[1].xyz += offset;
				bez[2].xyz += offset;				
				
				g2f po;
				
				// TODO Roll this into the resolve bezier geo.
				po.bez0 = UnityObjectToClipPos( bez[0] );
				po.bez1 = UnityObjectToClipPos( bez[1] );
				po.bez2 = UnityObjectToClipPos( bez[2] );

				float3 viewpos[5];
				ResolveBezierGeometry( viewpos, bez );

				// UNRESOLVED, Handle shape where center is behind one of the other two.
				
				int vtx;
				for( vtx = 0; vtx < 5; vtx++ )
				{
				
					float4 cp = mul( UNITY_MATRIX_P, float4( viewpos[vtx], 1.0 ) );
					po.vertex = cp;
					po.cppos = ( float4( viewpos[vtx], 1.0  ));

					UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(po);

					UNITY_TRANSFER_FOG(po,po.vertex);

					triStream.Append(po);
				}
			}

			fixed4 frag (g2f i) : SV_Target
			{
				fixed4 col = float4( 1.0, 1.0, 1.0, 1.0 );

				float3 cp = i.cppos;
				float3 bez0 =  i.bez0;
				float3 bez1 =  i.bez1;
				float3 bez2 =  i.bez2;
				
				// Project bezier onto visual plane (cppos is our "local" view vector)
				// We can't project it onto the normal view vector otherwise it will warp around.
				// What if we project cp into bezproj plane instead?

				// build basis for forward vector.
				// Need to pick the correct direction otherwise we will get artifacting.
				float3 forward = normalize( cp );
				
				float3 up = float3( 0, 1, 0 );
				float3 right = normalize( cross( forward, up ) );
				float3 newup = normalize( cross( right, forward ) ); 
				float3x3 matr = float3x3( right, newup, forward );

				bez0 = mul( matr, bez0);
				bez1 = mul( matr, bez1 );
				bez2 = mul( matr, bez2  );
				cp = mul( matr, cp );
				float3 cpbase = cp;
				cp = normalize( cp );
				
				bez0.z *= 0.000;
				bez1.z *= 0.000;
				bez2.z *= 0.000;
				cp.z   *= 0.000;
				

				float t;
				float2 outQ;
				float f = sdBezierMod( cp, bez0, bez1, bez2, outQ, t );
				f = abs(f);

				//float tT = (i.reltime.y - i.reltime.x) / (i.reltime.z - i.reltime.x);
				//float tDelta = (t-tT);

				float fLoD = length( fwidth( cpbase.xy ) );
				//float fDist = f*ComputeTailThickness( cpbase.z );
				
				// Get rid of tail in front of satellite.
				//fDist += saturate( tDelta*2000);
				//col.a = saturate( 1.0-fDist );
				// Fade out tail.  Based on nr segs, and where in the front we expect the satellite to be.
				//col.a *= saturate((4.5+tDelta)/4.5); 
				col.a *= 0.2;  // Overall fade.

				col.a += 0.01;

		
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
