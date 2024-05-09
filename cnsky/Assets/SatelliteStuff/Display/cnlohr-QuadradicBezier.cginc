
float ComputeGeometryWidthIncrease( float z );
float _TailThick;
float _BaseSizeUpscale;

float ComputeGeometryWidthIncrease( float dist )
{
	const float localExtra = 1.5;
	const float distantExtra = 1.5;
	return 
		localExtra * _TailThick * (abs(dist)+1*_BaseSizeUpscale) / _ScreenParams.x * 100.0
		+
		distantExtra * abs(dist)  / _ScreenParams.x; // For distant objects, draw an extra pixel around them, so they don't flutter.
}

float cross2d( float2 A, float2 B )
{
	return A.x * B.y - A.y * B.x;
}

void ResolveBezierGeometry( out float3 viewspacepos[5], float3 bez[3])
{
	float3 base[3] = {
		(bez[0]),
		(bez[1]),
		(bez[2]) };

	// Axis to expand from: In X-Y.
	// we assume -Z goes into the screen.
	
	float dist = ComputeGeometryWidthIncrease( min( min( base[0].z, base[2].z ), base[1].z ) );
	
	float3 orthos[3];
	orthos[0] = normalize( cross( base[0] - base[1], base[0] ) );
	orthos[2] = normalize( cross( base[2] - base[1], base[2] ) );
	orthos[0] = normalize( orthos[0] )*dist ;
	orthos[2] = normalize( orthos[2] )*dist ;
	
	// TODO: Try to expand from point on line from A--B orthogonal to center point.
	orthos[1] = normalize( orthos[0] - orthos[2] ) * dist ;
		
	float clockwisiness = sign( cross2d( base[2].xy - base[1].xy, base[0].xy - base[1].xy ) );
	
	viewspacepos[0] = base[0] - float3( orthos[0] ) * clockwisiness;
	viewspacepos[1] = base[0] + float3( orthos[0] ) * clockwisiness;
	viewspacepos[2] = base[1] - float3( orthos[1] ) * clockwisiness;
	viewspacepos[3] = base[2] - float3( orthos[2] ) * clockwisiness;
	viewspacepos[4] = base[2] + float3( orthos[2] ) * clockwisiness;
}
