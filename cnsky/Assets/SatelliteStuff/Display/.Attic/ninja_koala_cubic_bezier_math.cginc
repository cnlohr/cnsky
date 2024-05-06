// Cubic bezier approx distance 2
// https://www.shadertoy.com/view/3lsSzS
// By NinjaKoala

// Hacked up later by charlesl.
			
//#define SECOND_ORDER
#define HYBRID


//const float cb_dot_size=.005;
//const float3 cb_point_col=float3(1,1,0);
//const float cb_zoom=1.;
//const float cb_pi=3.1415926535;
//const int cb_num_segments=5;

//cb_factor should be positive
//it decreases the step size when lowered.
//Lowering the cb_factor and increasing iterations increases the area in which
//the iteration converges, but this is quite costly
#define cb_factor 1.
#define cb_eps .005

float newton_iteration3(float3 coeffs, float x){
	float a2=coeffs[2]+x;
	float a1=coeffs[1]+x*a2;

	float f=coeffs[0]+x*a1;
	float f1=((x+a2)*x)+a1;

	return x-f/f1;
}

float halley_iteration3(float3 coeffs, float x){
	float a2=coeffs[2]+x;
	float a1=coeffs[1]+x*a2;

	float f=coeffs[0]+x*a1;

	float b2=a2+x;

	float f1=a1+x*b2;
	float f2=2.*(b2+x);

	return x-(2.*f*f1)/(2.*f1*f1-f*f2);
}

//From Trisomie21
//But instead of his cancellation fix i'm using a newton iteration
int solve_cubic(float a, float b, float c, out float3 r){
	float p = b - a*a / 3.0;
	float q = a * (2.0*a*a - 9.0*b) / 27.0 + c;
	float p3 = p*p*p;
	float d = q*q + 4.0*p3 / 27.0;
	float offset = -a / 3.0;
	if(d >= 0.0) { // Single solution
		float z = sqrt(d);
		float u = (-q + z) / 2.0;
		float v = (-q - z) / 2.0;
		u = sign(u)*pow(abs(u),1.0/3.0);
		v = sign(v)*pow(abs(v),1.0/3.0);
		r[0] = offset + u + v;	

		//Single newton iteration to account for cancellation
		float f = ((r[0] + a) * r[0] + b) * r[0] + c;
		float f1 = (3. * r[0] + 2. * a) * r[0] + b;

		r[0] -= f / f1;

		return 1;
	}
	float u = sqrt(-p / 3.0);
	float v = acos(-sqrt( -27.0 / p3) * q / 2.0) / 3.0;
	float m = cos(v), n = sin(v)*1.732050808;

	//Single newton iteration to account for cancellation
	//(once for every root)
	r[0] = offset + u * (m + m);
    r[1] = offset - u * (n + m);
    r[2] = offset + u * (n - m);

	float3 f = ((r + a) * r + b) * r + c;
	float3 f1 = (3. * r + 2. * a) * r + b;

	r -= f / f1;

	return 3;
}

//Sign computation is pretty straightforward:
//I'm solving a cubic equation to get the intersection count
//of a ray from the current point to infinity and parallel to the x axis
//Also i'm computing the intersection count with the tangent in the end points of the curve
float cubic_bezier_sign(float2 uv, float2 p0, float2 p1, float2 p2, float2 p3){

	float cu=(-p0.y+3.*p1.y-3.*p2.y+p3.y);
	float qu=(3.*p0.y-6.*p1.y+3.*p2.y);
	float li=(-3.*p0.y+3.*p1.y);
	float co=p0.y-uv.y;

	float3 roots;
	int n_roots=solve_cubic(qu/cu,li/cu,co/cu,roots);

	int n_ints=0;

	for(int i=0;i<3;i++){
		if(i<n_roots){
			if(roots[i]>=0. && roots[i]<=1.){
				float x_pos=((((-p0.x+3.*p1.x-3.*p2.x+p3.x)*roots[i]+(3.*p0.x-6.*p1.x+3.*p2.x))*roots[i])+(-3.*p0.x+3.*p1.x))*roots[i]+p0.x;
				if(x_pos<uv.x){
					n_ints++;
				}
			}
		}
	}

	float2 tang1=p0.xy-p1.xy;
	float2 tang2=p2.xy-p3.xy;

	float2 nor1=float2(tang1.y,-tang1.x);
	float2 nor2=float2(tang2.y,-tang2.x);

	if(p0.y<p1.y){
		if((uv.y<=p0.y) && (dot(uv-p0.xy,nor1)<0.)){
			n_ints++;
		}
	}
	else{
		if(!(uv.y<=p0.y) && !(dot(uv-p0.xy,nor1)<0.)){
			n_ints++;
		}
	}

	if(p2.y<p3.y){
		if(!(uv.y<=p3.y) && dot(uv-p3.xy,nor2)<0.){
			n_ints++;
		}
	}
	else{
		if((uv.y<=p3.y) && !(dot(uv-p3.xy,nor2)<0.)){
			n_ints++;
		}
	}

	if(n_ints==0 || n_ints==2 || n_ints==4){
		return 1.;
	}
	else{
		return -1.;
	}
}

//cubic bezier distance by segmentation based on the one by iq
//see https://www.shadertoy.com/view/XdVBWd

float length2( float2 v ) { return dot(v,v); }

float segment_dis_sq( float2 p, float2 a, float2 b ){
	float2 pa = p-a, ba = b-a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
	return length2( pa - ba*h );
}

float cubic_bezier_segments_dis_sq(float2 uv, float2 p0, float2 p1, float2 p2, float2 p3){   
    float d0 = 1e38;
    float2 a = p0;
	const int cb_num_segments=5;
    for( int i=1; i<cb_num_segments; i++ )
    {
        float t = float(i)/float(cb_num_segments-1);
        float s = 1.0-t;
        float2 b = p0*s*s*s + p1*3.0*s*s*t + p2*3.0*s*t*t + p3*t*t*t;
        d0 = min(d0,segment_dis_sq(uv, a, b ));
        a = b;
    }
    
    return d0;
}

float cubic_bezier_segments_dis(float2 uv, float2 p0, float2 p1, float2 p2, float2 p3){
	return sqrt(cubic_bezier_segments_dis_sq(uv,p0,p1,p2,p3));
}

float cubic_bezier_normal_iteration(float t, float2 a0, float2 a1, float2 a2, float2 a3){
	//horner's method
	float2 a_2=a2+t*a3;
	float2 a_1=a1+t*a_2;
	float2 b_2=a_2+t*a3;

	float2 uv_to_p=a0+t*a_1;
	float2 tang=a_1+t*b_2;

	float l_tang=dot(tang,tang);
	return t-cb_factor*dot(tang,uv_to_p)/l_tang;
}

float cubic_bezier_normal_iteration2(float t, float2 a0, float2 a1, float2 a2, float2 a3){
	//horner's method
	float2 a_2=a2+t*a3;
	float2 a_1=a1+t*a_2;
	float2 b_2=a_2+t*a3;

	float2 uv_to_p=a0+t*a_1;
	float2 tang=a_1+t*b_2;
	float2 snd_drv=2.*(b_2+t*a3);

	float l_tang=dot(tang,tang);

	float fac=dot(tang,snd_drv)/(2.*l_tang);
	float d=-dot(tang,uv_to_p);

	float t2=d/(l_tang+fac*d);

	return t+cb_factor*t2;
}

float cubic_bezier_normal_iteration3(float t, float2 a0, float2 a1, float2 a2, float2 a3){
	float2 tang=(3.*a3*t+2.*a2)*t+a1;
	float3 poly=float3(dot(a0,tang),dot(a1,tang),dot(a2,tang))/dot(a3,tang);

	/* newton iteration on this polynomial is equivalent to cubic_bezier_normal_iteration */
	return newton_iteration3(poly,t);

	/* halley iteration on this polynomial is equivalent to cubic_bezier_normal_iteration2 */
	//return halley_iteration3(poly,t);
}

float2 cubic_bezier_dis_approx_sq(float2 uv, float2 p0, float2 p1, float2 p2, float2 p3){
	float2 a3 = (-p0 + 3. * p1 - 3. * p2 + p3);
	float2 a2 = (3. * p0 - 6. * p1 + 3. * p2);
	float2 a1 = (-3. * p0 + 3. * p1);
	float2 a0 = p0 - uv;

	float d0 = 1e38;

	float t0=0.;
	float t;

	const int cb_num_iterations=3;
	const int cb_num_start_params=3;


	for(int i=0;i<cb_num_start_params;i++){
		t=t0;
		for(int j=0;j<cb_num_iterations;j++){
			#ifdef SECOND_ORDER
			t=cubic_bezier_normal_iteration2(t,a0,a1,a2,a3);
			#else
			t=cubic_bezier_normal_iteration(t,a0,a1,a2,a3);
			#endif
		}
		t=clamp(t,0.,1.);
		float2 uv_to_p=((a3*t+a2)*t+a1)*t+a0;
		d0=min(d0,dot(uv_to_p,uv_to_p));

		t0+=1./float(cb_num_start_params-1);
	}

	return float2( d0, t );
}

float2 cubic_bezier_dis_approx(float2 uv, float2 p0, float2 p1, float2 p2, float2 p3){
	float2 rev = cubic_bezier_dis_approx_sq(uv,p0,p1,p2,p3);
	return float2( sqrt(rev.x), rev.y );
}

float2 cubic_bezier_dis_approx_hybrid(float2 uv, float2 p0, float2 p1, float2 p2, float2 p3){
	float2 d0=cubic_bezier_dis_approx_sq(uv,p0,p1,p2,p3);

	if(d0.x>cb_eps){
		d0.x=min(d0.x,cubic_bezier_segments_dis_sq(uv,p0,p1,p2,p3));
	}

	return float2( sqrt(d0.x), d0.y );
}
