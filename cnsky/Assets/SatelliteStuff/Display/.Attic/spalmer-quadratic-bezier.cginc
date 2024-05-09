// THIS CODE IS NOT LICENSED, DO NOT COPY OR PASTE FROM THIS FILE UNLESS
// SPECIFICALLY PERMITTED BY SPALMER.
// From Shadertoy https://www.shadertoy.com/view/4fVSWD
//
// THIS CODE IS NOT IN USE IN THIS PROJECT.
//
// HERE FOR REFERENCE: I benchmarked this implementation to 30.5 MS reference, compared to 25 for IQ code and 30 for Per Bloksgaard code.
//
// ABANDONING NOW.
//
/*
REFERENCE

#if 1
				float f = calculateDistanceToQuadraticBezier3( t, cp, bez0, bez1, bez2 );
#elif 1
				float2 outQ;
				t = sdBezier( cp, bez0, bez1, bez2, outQ );
				float f = min(outQ.x, outQ.y);
				f = abs(t);
#else
				float2 outQ;
				float nd2;
				t = bezierSpalmer(cp, bez0, bez1, bez2, outQ, nd2);
				float f = min(outQ.x, outQ.y);
				//f = abs(t);
#endif
*/
// This is a demonstration of one of the failure cases of the spalmer quadratic bezier solution, here: https://www.shadertoy.com/view/3tsczH
// Simplified code/solution follows:



// I finally made a decent spline solver, and dusted off my old spline stuff,
// Hope it helps somebody.

// iq did http://shadertoy.com/view/ldj3Wh and others in 2013!
// bloxard posted in 2014-01-03.  Influenced by both and others.

// I refactored their solvers and spline code out.
// I also managed to port iq's clever cubic solver fix
// using taylor series expansion to avoid cancellation errors
// back to other solvers, that took a lot of coffee.

// Extra special thanks to Steve Noskowicz, who
// long ago taught me everything I know about splines.

// It's getting real hard to find my way around in this toy now,
// so I moved a bunch of the solvers back to http://shadertoy.com/view/flyGDD
// and moved other people's reference spline code into Common
// just to get out of the way.

// if an inexact approximation is good enough,
// see also Bezier Quadric Approx at http://shadertoy.com/view/dsj3Wy

// http://shadertoy.com/view/flyGDD

float2 CubicSpalmerInlined(float4 k)
{
    float NaN = asfloat(0x7f800001u);
    float d = k.x, c = k.y, b = k.z, a = k.w;
    if (a == 0.) { // quadratic inlined
        if (b == 0.)
            return float2(-d/c, NaN); // handle malformed eqn, let divide handle c == 0 case
        float n = c * c - 4. * b * d; // discriminant
        return float2(n < 0. ? NaN :
            .5 / b * (sign(b) * sqrt(n) - c) // two solutions, lesser first (may be identical)
            , NaN);
    }
    d /= a; c /= a; b /= a;
    float x = b/-3.; // inflection point
    d += (c - 2.*x*x)*x; c += b*x; // depress cubic
    float l = c / 3.,
        s = l * l * l,
        m = d * d + 4. * s;
    if (m > 0.) { // 1 real root
        float2 w = sqrt(m) * float2(1,-1) - d;
        float v = abs(w.x) < abs(w.y) ? w.y : w.x;
        v = sign(v) * pow(.5 * abs(v), 1. / 3.);
        return float2(v - l / v, NaN) + x; // Blinn single cbrt idea
    }
    // 2 or 3 distinct roots
    return 2. * sign(c) * sqrt(abs(l)) * cos((atan2(sqrt(-m), -sign(c) * d) - acos(-1.) * float2(0,4)) / 3.) + x;
}

float2 Cubic(float4 k)
{
    return CubicSpalmerInlined(k).xy;
//    if (k.w == 0.) return Quadratic(k.xyz);
//    return Cubic(k.xyz/k.w);
}


float sqr(float x) { return x * x; }
float sqr(float2  x) { return dot(x, x); }
float2 eval(float t, in float2 p[2])
{
    return p[1] * t + p[0];
}

float2 eval(float t, in float2 p[3])
{
    return (p[2] * t + p[1]) * t + p[0];
}

float2 eval(float t, in float2 p[4])
{
    return ((p[3] * t + p[2]) * t + p[1]) * t + p[0];
}

float2 eval2(float t, in float2 p[3])
{
    //return eval(t*t, p); // NO
    float2 r = eval(t, p); return r*r;
    //return sqr(eval(t, p)); // NO
}



// fork of FabriceNeyret2  http://shadertoy.com/view/XtdyDn  origin: bloxard
float bezierSpalmer(float2 p, float2 qa, float2 qb, float2 qc, out float2 nv, out float nd2)
{
    float2 u = qb - qa, v = qc - qb, b = v - u, d = qa - p;
    float2 s[3] = { d, 2.*u, b };
    float4 k = float4(
        dot(d,u),
        2.*sqr(u) + dot(d,b),
        3.*dot(b,u),
        sqr(b)+0.00001);

    float2 r = Cubic(k);
    
    
    r = clamp(r, 0., 1.);
    // check distance to both solutions and return closer root
    float2 qx = eval(r.x, s), qy = eval(r.y, s);
    float dx = dot(qx,qx), dy = dot(qy,qy);
    float t;
    // since already found closest point on curve and quadrance to it, 
    // return those too so caller doesn't need to recompute
    if (dx < dy) {
        t = r.x; nv = qx; nd2 = dx;
    } else {
        t = r.y; nv = qy; nd2 = dy;
    }
    return t;
}
