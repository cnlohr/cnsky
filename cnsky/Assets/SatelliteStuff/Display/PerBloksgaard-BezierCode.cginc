// Copyright Per Bloksgaard, 2014 - https://perbloksgaard.dk
// I was inspired by https://www.shadertoy.com/view/XsX3zf but instead of a fast 
// distance approximation, I wanted the exact distance to a quadratic bezier spline.

//Blog article about this shader below. (In danish)
//http://www.hinnerup.net/permanent/2014/01/23/bezier_spline_shader/

#define dd(a) dot(a,a)
float addv(float2 a) { return a.x + a.y; }

//Find roots using Cardano's method. http://en.wikipedia.org/wiki/Cubic_function#Cardano.27s_method
float2 solveCubic2(float3 a)
{
	float p = a.y-a.x*a.x/3.;
	float p3 = p*p*p;
	float q = a.x*(2.*a.x*a.x-9.*a.y)/27.+a.z;
	float d = q*q+4.*p3/27.;
	if(d>.0)
	{
		float2 x = (float2(1,-1)*sqrt(d)-q)*.5;
		return (addv(sign(x)*pow(abs(x),(1./3.)))-a.x/3.).xx;
	}
	float v = acos(-sqrt(-27./p3)*q*.5)/3.;
	float m = cos(v);
	float n = sin(v)*1.732050808;
	return float2(m+m,-n-m)*sqrt(-p/3.)-a.x/3.;
}

// How to solve the equation below can be seen on this image.
// http://www.perbloksgaard.dk/research/DistanceToQuadraticBezier.jpg
float calculateDistanceToQuadraticBezier(out float t, float2 p, float2 a, float2 b, float2 c)
{
	b += lerp((1e-4).xx,(0.).xx,abs(sign(b*2.-a-c)));
	float2 A = b-a;
	float2 B = c-b-A;
	float2 C = p-a;
	float2 D = A*2.;
	float2 T = clamp((solveCubic2(float3(-3.*dot(A,B),dot(C,B)-2.*dd(A),dot(C,A))/-dd(B))),0.,1.);
	
	// Added to know where you are along the line.
	float Ma = dd(C-(D+B*T.x)*T.x);
	float Mb = dd(C-(D+B*T.y)*T.y);
	t = (Ma<Mb)?T.x:T.y;
	return sqrt(min(Ma,Mb));
}

float cross2d( float2 A, float2 B )
{
	return A.x * B.y - A.y * B.x;
}

void ResolveBezierGeometry( out float4 clippos[5], float3 bez[3], float expand)
{
	float4 clippos_base[3] = {
		UnityObjectToClipPos(bez[0]),
		UnityObjectToClipPos(bez[1]),
		UnityObjectToClipPos(bez[2]) };

	float2 clip2d[3] = {
		clippos_base[0].xy / clippos_base[0].w,
		clippos_base[1].xy / clippos_base[1].w,
		clippos_base[2].xy / clippos_base[2].w,
	};

	float2 orthos[3];
	orthos[0] = (clip2d[0] - clip2d[1]).yx * float2( 1.0, -1.0 );
	orthos[2] = (clip2d[2] - clip2d[1]).yx * float2( 1.0, -1.0 );
	orthos[0] = normalize( orthos[0] )*expand;
	orthos[2] = normalize( orthos[2] )*expand;
	
	// TODO: Try to expand from point on line from A--B orthogonal to center point.
	orthos[1] = normalize( orthos[0] - orthos[2] ) * expand;
		
	float clockwisiness = sign( cross2d( clip2d[2].xy - clip2d[1].xy, clip2d[0].xy - clip2d[1].xy ) );
	
	clippos[0] = clippos_base[0] - float4( orthos[0], 0.0, 0.0 ) * clockwisiness;
	clippos[1] = clippos_base[0] + float4( orthos[0], 0.0, 0.0 ) * clockwisiness;
	clippos[2] = clippos_base[1] - float4( orthos[1], 0.0, 0.0 ) * clockwisiness;
	clippos[3] = clippos_base[2] - float4( orthos[2], 0.0, 0.0 ) * clockwisiness;
	clippos[4] = clippos_base[2] + float4( orthos[2], 0.0, 0.0 ) * clockwisiness;
}
