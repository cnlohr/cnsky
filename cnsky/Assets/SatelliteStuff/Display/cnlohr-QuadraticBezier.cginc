
float cross2d( float2 A, float2 B )
{
	return A.x * B.y - A.y * B.x;
}

void ResolveBezierGeometry( out float3 viewspacepos[5], float3 bez[3], float expand)
{
	float3 base[3] = {
		(bez[0]),
		(bez[1]),
		(bez[2]) };

	float3 clip2d[3] = {
		base[0].xyz,
		base[1].xyz,
		base[2].xyz,
	};

	// Axis to expand from: In X-Y, 
	
	float3 orthos[3];
	orthos[0] = normalize( cross( clip2d[0] - clip2d[1], clip2d[0] ) ); //(clip2d[0] - clip2d[1]).yx * float2( 1.0, -1.0 );
	orthos[2] = normalize( cross( clip2d[2] - clip2d[1], clip2d[2] ) ); //(clip2d[2] - clip2d[1]).yx * float2( 1.0, -1.0 );
	orthos[0] = normalize( orthos[0] )*expand;
	orthos[2] = normalize( orthos[2] )*expand;
	
	// TODO: Try to expand from point on line from A--B orthogonal to center point.
	orthos[1] = normalize( orthos[0] - orthos[2] ) * expand;
		
	float clockwisiness = sign( cross2d( clip2d[2].xy - clip2d[1].xy, clip2d[0].xy - clip2d[1].xy ) );
	
	viewspacepos[0] = base[0] - float3( orthos[0] ) * clockwisiness;
	viewspacepos[1] = base[0] + float3( orthos[0] ) * clockwisiness;
	viewspacepos[2] = base[1] - float3( orthos[1] ) * clockwisiness;
	viewspacepos[3] = base[2] - float3( orthos[2] ) * clockwisiness;
	viewspacepos[4] = base[2] + float3( orthos[2] ) * clockwisiness;
}
