Shader "Unlit/QuestGEO"
{
	Properties
	{
	}
	SubShader
	{
		Tags { "RenderQueue"="Overlay" "RenderType"="Transparent" }
		Blend One One // Additive
		ZTest Off
		
		Pass
		{
			GLSLPROGRAM
			#version 320 es

	#extension GL_EXT_multiview_tessellation_geometry_shader : enable
	#extension GL_OVR_multiview2 : enable

// Neither this extension or gl_ViewIndex are present.
//	#extXXXension XXXGL_EXT_multiview : require 


#ifdef STEREO_INSTANCING_ON
	// Not used.
    #extension GL_NV_viewport_array2 : enable
    #extension GL_AMD_vertex_shader_layer : enable
    #extension GL_ARB_fragment_layer_viewport : enable
#endif

// ON QUEST, STEREO_MULTIVIEW_ON is enabled.


			#include "UnityCG.glslinc"
			#include "UnityStereoSupport.glslinc"
			
			#pragma vertex vert
			#pragma fragment frag
			#pragma geometry geo

#ifdef VERTEX

in  vec2 in_TEXCOORD0;
in  vec4 in_POSITION0;
out vec3 ouve;

uniform  OVR_multiview
{
	uint _ViewID;
	uint numViews_2;
};

layout(std140) uniform UnityStereoEyeIndices {
	vec4 unity_StereoEyeIndices[2];
};

void main ()
{

/*
	if( (int(unity_StereoEyeIndex) & 1) > 0 )
	{
		// When geometry shader is active on Quest, this is never true.
		// But in case someone fixes geo shaders ever... keep this so we
		// don't double-draw.
		gl_Position = vec4( 0.0 );
		return;
	}
*/

	ouve.xy = in_TEXCOORD0;

	//ouve.z = 0.0;
	//ouve.z = float(gl_ViewID); // Always 0. (Or undefined, depending)
	ouve.z = float(_ViewID); // Always 0.
	//ouve.z = float(gl_InstanceID); // Always 0.
	//ouve.z = float(unity_StereoEyeIndices[gl_ViewID_OVR].x); // Flashes back and forth, just as gl_ViewID_OVR is random.
	//ouve.z = float((gl_ViewID_OVR>>30)&uint(15)); // view ID is kinda random.
	//ouve.z = uintBitsToFloat(gl_ViewID_OVR); // view ID is kinda random.
	//ouve.z = float(unity_StereoEyeIndex); // Always 0
	//ouve.z = float(gl_ViewIndex); // Will not compile.
	gl_Position  = in_POSITION0;
}
#endif 

#ifdef GEOMETRY


layout(triangles) in;
layout(triangle_strip, max_vertices=150) out;

/*
    out gl_PerVertex {
        vec4 gl_Position;
        float gl_PointSize;
        float gl_ClipDistance[];
    };
*/


in vec3 ouve[3];
out vec3 ouvf;

//layout(num_views = 2) in;

#if defined(STEREO_MULTIVIEW_ON) || defined(STEREO_INSTANCING_ON)
layout(invocations = 2) in;
#endif

// For now, each invocation outputs a triangle to each eye.

	void main()
	{
		int eyeid = 0;
		int x, y;
		for( x = 0; x < 5; x ++ )
		for( y = 0; y < 5; y++ )
		{
#if defined(STEREO_MULTIVIEW_ON) || defined(STEREO_INSTANCING_ON)
		//for( eyeid = 0; eyeid < 2; eyeid++ )
		//eyeid = int(ouve.z+0.5);  // If testing the input instance ID code, uncomment this, and comment out the above line.
		//eyeid = gl_ViewID_OVR;
		eyeid = gl_InvocationID;
#endif
		{
			#if defined(STEREO_MULTIVIEW_ON) || defined(STEREO_INSTANCING_ON)
				mat4 stereoVP = unity_StereoMatrixVP[eyeid];
			#else
				mat4 stereoVP = unity_MatrixVP;
			#endif
			for(int i=0; i<3; i++)
			{
				gl_Position = stereoVP * unity_ObjectToWorld * ( gl_in[i].gl_Position + vec4( x*2, y*2, 0, 0 ) );
				gl_Layer = eyeid;
				vec3 uv = ouve[i];
				EmitVertex();
				ouvf = uv;
			}
			EndPrimitive();
		}
		}
	}

#endif

#ifdef FRAGMENT 
			in vec3 ouvf;
			layout (location = 0) out vec4 color;

			void main()
			{
				color = vec4( vec3( max( 0.0, 1.0 - length( ((ouvf.x) - ouvf.z) * 4.0 ) ) ), 1.0 );
				return;
				/*
				float check = ( floor(ouvf * 4.0).x + floor(ouvf * 4.0).y*3.0 );
				if( length( eyeo - check ) < 1.0 )
					color = vec4( 0.5 );
				else
					color = vec4( 0.01 );
					*/
			}
			
			
			
			
#endif
			ENDGLSL
		}
	}
}
