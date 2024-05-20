Shader "Hirabiki/ScreenSpace/Vignette"
{
	Properties {
		_Color("Color", Color) = (0,0,0,1)
		_Size("Size", Range(0,5)) = 1
	}
    SubShader
    {
        // Draw ourselves after all opaque geometry
        Tags { "Queue" = "Transparent" }
		Blend SrcAlpha OneMinusSrcAlpha
		Cull Front
		ZTest Always
		ZWrite Off
		
		GrabPass
		{
			"_BackgroundTexture"
		}
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
			
			uniform float _Size;
			uniform half4 _Color;
			
            struct v2f
            {
                float4 grabPos : TEXCOORD0;
                float4 pos : SV_POSITION;
            };

            v2f vert(appdata_base v) {
                v2f o;
                // use UnityObjectToClipPos from UnityCG.cginc to calculate 
                // the clip-space of the vertex
                o.pos = UnityObjectToClipPos(v.vertex);
                // use ComputeGrabScreenPos function from UnityCG.cginc
                // to get the correct texture coordinate
                o.grabPos = ComputeGrabScreenPos(o.pos);
                return o;
            }
			
			// Partial local copy from cginc file
			float2 unnormalizeUV(float2 grabUV, float eye, float convergence) {
				float2 projectionOffset = float2(unity_CameraProjection._m02, unity_CameraProjection._m12) * float2(0.25, 0.5);
				float2 scrUVPre = grabUV + projectionOffset;
				float2 scrUVFinal = lerp(scrUVPre, frac(scrUVPre * float2(2.0, 1.0)), abs(eye));
				scrUVFinal.x += convergence * 0.5 / unity_CameraProjection._m00 * eye;
				
				float2 fov = float2(
					(1.0 / unity_CameraProjection._m00),
					(1.0 / unity_CameraProjection._m11)
				);
				return (2.0 * scrUVFinal - 1.0) * fov;
			}
			
            half4 frag(v2f i) : SV_Target
            {
				float4 fovLRBT;
				
				half eye = 0.0;
#if defined(USING_STEREO_MATRICES)
				eye = unity_StereoEyeIndex * 2.0 - 1.0;
#endif
				float2 scrUVRaw = i.grabPos.xy/i.grabPos.w;
				half2 scrUV = unnormalizeUV(scrUVRaw, eye, 0.012);
				
				half dist = smoothstep(0.0, 1.0, lerp(saturate(length((scrUV) / _Size)), 1.0, smoothstep(1.0, 0.0, _Size)));
				half4 col = half4(_Color.rgb, dist * _Color.a * lerp(1.0, 0.0, saturate(_Size * 0.25 - 0.25)));
				
                return col;
            }
			
            ENDCG
        }

    }
}