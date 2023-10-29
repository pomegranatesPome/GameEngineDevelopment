#ifndef HLSL_LIGHTHELPER
#define HLSL_LIGHTHELPER

// Light and material structs
struct SurfaceInfo
{
	float3 pos;
	float3 normal;
	float4 diffuse;
	float4 spec;
};

//------------------------------------------------------------------------------
// Constants
//------------------------------------------------------------------------------

// calculation functions for each type of light
float3 ParallelLight(SurfaceInfo v, Light L, float3 eyePos)
{
	float3 litColor = make_float3(0, 0, 0);
	
	//Light vector (opposite photon direction) //?: + and now works
	float3 lightVec = -L.xyzDir_w.xyz;
	
	//Add the ambient term.
	litColor += v.diffuse.xyz * L.ambient.xyz;
	
	//Add diffuse and spec term, if surface has los to the light
	float diffuseFactor = max(dot(lightVec, v.normal), 0.0);
	
	float specPower = max(v.spec.a, 1.0);
	float3 toEye	= -normalize(eyePos - v.pos);//?: + and now works
	float3 R		= reflect(lightVec, v.normal);
	float specFactor = pow(max(dot(R, toEye), 0.0), specPower);
		
	//diffuse and sepcular terms
	litColor += diffuseFactor * v.diffuse.xyz * L.diffuse.xyz;
	litColor += specFactor * v.spec.xyz * L.spec.xyz;
	
	return litColor;
}

float3 PointLight(SurfaceInfo v, Light l, float3 eyePos, float shadowFactor)
{
	float3 litColor = make_float3(0, 0, 0);
	
	// Surface to light vector
	float3 lightVec =  l.xyzPos_w.xyz - v.pos;
	
	// Distance from surface to light
	float d = length(lightVec);
	
	
	if( d > l.xRange_yType_zw.x )
		return litColor;
		
	// Normalize the light vector
	lightVec /= d;
	
	
	
	float diffuseFactor = max(dot(lightVec, v.normal), 0.0);
	float specPower		= max(v.spec.a, 1.0);
	float3 toEye		= normalize(eyePos - v.pos);
	float3 R			= reflect( -lightVec, v.normal);
	float specFactor	= pow(max(dot(R, toEye), 0.0), specPower);
	
	litColor += shadowFactor * diffuseFactor * v.diffuse.xyz * l.diffuse.xyz;
	litColor += shadowFactor * specFactor * v.spec.xyz * l.spec.xyz;

	
	// attenuate
	litColor /= dot(l.xyzAtt_wSpotPwr.xyz, make_float3(1.0, d, d*d));
	
	// Add ambient light
	litColor += v.diffuse.xyz * l.ambient.xyz;
	
	return litColor;
}


float3 SpotLight(SurfaceInfo v, Light L, float3 eyePos, float shadowFactor)
{
	float3 litColor = PointLight(v, L, eyePos, shadowFactor);
	
	//The vector from the surface to the light
	float3 lightVec = normalize(L.xyzPos_w.xyz- v.pos);
	
	//Scale color by spotlight factor
	float s = pow(max(dot(-lightVec, L.xyzDir_w.xyz), 0.0), L.xyzAtt_wSpotPwr.w);
	
	return litColor * s;
}

float3 RenderLight(SurfaceInfo v, Light l, float3 eyePos, float shadowFactor)
{
    if (l.xRange_yType_zw.y < 0.1) // == 0)
		return PointLight(v, l, eyePos, shadowFactor);
	else if (l.xRange_yType_zw.y < 1.1) // == 1)
		return ParallelLight(v, l, eyePos);
	else if (l.xRange_yType_zw.y < 2.1) // == 2)
		return SpotLight(v, l, eyePos, shadowFactor);
	else
		return PointLight(v, l, eyePos, shadowFactor);
}
 
float Quantize(float intensity)
{
	if (intensity < 0.2f)
		return 0.0f;
	else if (intensity < 0.4f)
		return 0.2f;
	else if (intensity < 0.6f)
		return 0.4f;
	else if (intensity < 0.8f)
		return 0.6f;
	else
		return 1.0f;
}

float3 Palette1(float intensity)
{
	if (intensity == 0.0f)
		return make_float3(0.0f, 0.0f, 0.0f);
	
	else if (intensity == 0.2f)
		return make_float3(0.16f, 0.21f, 0.09f);
		
	else if (intensity == 0.4f)
		return make_float3(0.38f, 0.42f, 0.22f);
		
	else if (intensity == 0.6f)
		return make_float3(0.69f, 0.70f, 0.55f);
		
	else
		return make_float3(1.f, 0.98f, 0.88f);

}

float3 QuantizedPalette1(float3 litColor)
{
	float intensity = (litColor.r + litColor.g + litColor.b) / 3.0f;
	
	if (intensity <= 0.2f)
		return make_float3(0.0f, 0.0f, 0.0f);

	else if (intensity <= 0.4f)
		return make_float3(0.16f, 0.21f, 0.09f);
		
	else if (intensity <= 0.6f)
		return make_float3(0.38f, 0.42f, 0.22f);
		
	else if (intensity <= 0.9f)
		return make_float3(0.69f, 0.70f, 0.55f);
		
	else
		return make_float3(1.f, 0.98f, 0.88f);
}

//=======================================================
//================M2 MODIFICATION ON CEL SHADING==========
//====================================================

// calculation functions for each type of light
float3 ParallelLight_Cel(SurfaceInfo v, Light L, float3 eyePos)
{
	float3 litColor = make_float3(0, 0, 0);
	
	//Light vector (opposite photon direction) //?: + and now works
	float3 lightVec = -L.xyzDir_w.xyz; // from point of surface to light source
	float3 toEye	= -normalize(eyePos - v.pos);//?: + and now works


	//Add diffuse term
	float kDiff = smoothstep(0.001, 0.10, dot(lightVec, v.normal));
	litColor += kDiff * v.diffuse.xyz * L.diffuse.xyz; 

	// if (kDiff != dot(lightVec, v.normal)){
	// 	// add sss
	// 	float sssConcentration = 0.5f;
	// 	float sssScale = 0.1f;
		
	// 	float lightAndSurface = dot(v.normal, lightVec);
	// 	float sssAmount = pow(lightAndSurface, sssConcentration) * sssScale ;
	// 	float3 sssColor = make_float3(0.85, 0.48, 0.74) * sssAmount;
	// 	float3 sssColorTest = make_float3(0.95f, 0.95f, 0.95f) * sssAmount;
	// 	float3 sssColorTestgreen = make_float3(0.36, 0.64, 0.17) * sssAmount;

	// 	float angle = dot(-toEye, v.normal);
	
	// 	litColor = lerp(litColor, sssColor, angle);
	// }
	
	// NEW Specular stuff
	float3 halfVector = normalize(lightVec + toEye);
	float specular = dot(v.normal, halfVector);
	specular = pow(specular * kDiff, 100); // random glossiness number
	float smoothSpec = smoothstep(0.001, 0.1, specular);

	litColor += smoothSpec * v.diffuse.xyz *  L.diffuse.xyz; 

	// //add sss
	// float sssConcentration = 0.5f;
	// float sssScale = 0.1f;
	
	// float lightAndSurface = dot(v.normal, lightVec);
	// float sssAmount = pow(lightAndSurface, sssConcentration) * sssScale ;
	// // float3 sssColor = make_float3(0.85, 0.48, 0.74) * sssAmount;
	// // float3 sssColorTest = make_float3(0.5f, 0.3f, 0.3f) * sssAmount;
	// // float3 sssColorTestgreen = make_float3(0.36, 0.64, 0.17) * sssAmount;
	// float3 sssColorMap = litColor + make_float3(0.1, 0.05, 0.07);

	// float angle = dot(-toEye, v.normal);

	// litColor = lerp(litColor, sssColorMap, (1-angle));
	
	return litColor;

}

float3 PointLight_Cel(SurfaceInfo v, Light l, float3 eyePos, float shadowFactor)
{
	float3 litColor = make_float3(0, 0, 0);
	
	// Surface to light vector
	float3 lightVec =  l.xyzPos_w.xyz - v.pos;
	
	// Distance from surface to light
	float d = length(lightVec);
	
	
	if( d > l.xRange_yType_zw.x )
		return litColor;
		
	// Normalize the light vector
	lightVec /= d;
	
	float diffuseFactor = smoothstep(0.001, 0.1, dot(lightVec, v.normal));
	float specPower		= max(v.spec.a, 1.0); // OLD STUFF
	float3 toEye		= normalize(eyePos - v.pos);
	float3 R			= reflect( -lightVec, v.normal);

	// NEW STUFF TEST
	float3 halfVector = normalize(lightVec + toEye);
	float specular = dot(v.normal, halfVector);
	specular = pow(specular * diffuseFactor, 100); // random glossiness number
	float smoothSpec = smoothstep(0.001, 0.08, specular);

	litColor += shadowFactor * (diffuseFactor + smoothSpec) * v.diffuse.xyz * l.diffuse.xyz ;
	
	//add sss
	// float sssConcentration = 0.5f;
	// float sssScale = 0.1f;
	
	// float lightAndSurface = dot(v.normal, lightVec);
	// float sssAmount = pow(lightAndSurface, sssConcentration) * sssScale ;
	// float3 sssColor = make_float3(0.75, 0.48, 0.74) * sssAmount;
	// float3 sssColorTest = make_float3(0.5f, 0.3f, 0.3f) * sssAmount;
	// float3 sssColorTestgreen = make_float3(0.36, 0.64, 0.17) * sssAmount;

	// float angle = dot(toEye, v.normal);

	// litColor = lerp(litColor, sssColor, (1-angle));
	
	return litColor;
	
}

float3 SpotLight_Cel(SurfaceInfo v, Light L, float3 eyePos, float shadowFactor)
{
	float3 litColor = PointLight_Cel(v, L, eyePos, shadowFactor);
	
	//The vector from the surface to the light
	float3 lightVec = normalize(L.xyzPos_w.xyz- v.pos);
	
	//Scale color by spotlight factor
	float s = pow(max(dot(-lightVec, L.xyzDir_w.xyz), 0.0), L.xyzAtt_wSpotPwr.w);
	
	return litColor * s;
}

float3 RenderLight_Cel(SurfaceInfo v, Light l, float3 eyePos, float shadowFactor)
{
    if (l.xRange_yType_zw.y < 0.1) // == 0)
		return PointLight_Cel(v, l, eyePos, shadowFactor);
	else if (l.xRange_yType_zw.y < 1.1) // == 1)
		return ParallelLight_Cel(v, l, eyePos);
	else if (l.xRange_yType_zw.y < 2.1) // == 2)
		return SpotLight_Cel(v, l, eyePos, shadowFactor);
	else
		return PointLight_Cel(v, l, eyePos, shadowFactor);
}

#endif
