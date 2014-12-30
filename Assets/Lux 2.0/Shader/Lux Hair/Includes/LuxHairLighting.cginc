#ifndef UNITY_PBS_LIGHTING_INCLUDED
#define UNITY_PBS_LIGHTING_INCLUDED

#include "UnityStandardConfig.cginc"
#include "UnityStandardBRDF.cginc"
#include "UnityStandardUtils.cginc"

//-------------------------------------------------------------------------------------

fixed4 _AnisoDir;
fixed4 _SpecularColor1;
fixed4 _SpecularColor2;
float _PrimaryShift;
float _SecondaryShift;
half _RimStrength;

//-------------------------------------------------------------------------------------

struct UnityGI
{
	UnityLight light;
	#ifdef DIRLIGHTMAP_SEPARATE
		#ifdef LIGHTMAP_ON
			UnityLight light2;
		#endif
		#ifdef DYNAMICLIGHTMAP_ON
			UnityLight light3;
		#endif
	#endif
	UnityIndirect indirect;
};

struct UnityGIInput 
{
	UnityLight light; // pixel light, sent from the engine

	float3 worldPos;
	float3 worldViewDir;
	half atten;
	half4 ambientOrLightmapUV;

	float4 boxMax[2];
	float4 boxMin[2];
	float4 probePosition[2];
	float4 probeHDR[2];
};

UNITY_DECLARE_TEXCUBE(unity_SpecCube);
UNITY_DECLARE_TEXCUBE(unity_SpecCube1);

inline UnityGI UnityStandardGlobalIllumination (UnityGIInput data, half occlusion, half oneMinusRoughness, half3 normalWorld)
{
	UnityGI o_gi;
	UNITY_INITIALIZE_OUTPUT(UnityGI, o_gi);
#if defined(SHADER_API_PSP2)
// critical to avoid internal shader compiler errors on PSP2 (unable to use generic UNITY_INITIALIZE_OUTPUT elsewhere though)
	o_gi = (UnityGI)0;
#endif	
	
	o_gi.indirect.diffuse = 0;
	o_gi.indirect.specular = 0;

	#if UNITY_SHOULD_SAMPLE_SH
		#if UNITY_SAMPLE_FULL_SH_PER_PIXEL
			half3 sh = ShadeSH9(half4(normalWorld, 1.0));
		#elif (SHADER_TARGET >= 30)
			half3 sh = data.ambientOrLightmapUV.rgb + ShadeSH12Order(half4(normalWorld, 1.0));
		#else
			half3 sh = data.ambientOrLightmapUV.rgb;
		#endif
	
		o_gi.indirect.diffuse += sh;
	#endif

	#if !defined(LIGHTMAP_ON)
		o_gi.light = data.light;
		o_gi.light.color *= data.atten;
		//o_gi.atten = data.atten;

	#else
		// Baked lightmaps
		fixed4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, data.ambientOrLightmapUV.xy); 
		half3 bakedColor = DecodeLightmap(bakedColorTex);
		
		#ifdef DIRLIGHTMAP_OFF
			o_gi.indirect.diffuse = bakedColor;

			#ifdef SHADOWS_SCREEN
				o_gi.indirect.diffuse = MixLightmapWithRealtimeAttenuation (o_gi.indirect.diffuse, data.atten, bakedColorTex);
			#endif // SHADOWS_SCREEN

		#elif DIRLIGHTMAP_COMBINED
			fixed4 bakedDirTex = UNITY_SAMPLE_TEX2D_SAMPLER (unity_LightmapInd, unity_Lightmap, data.ambientOrLightmapUV.xy);
			o_gi.indirect.diffuse = DecodeDirectionalLightmap (bakedColor, bakedDirTex, normalWorld);

			#ifdef SHADOWS_SCREEN
				o_gi.indirect.diffuse = MixLightmapWithRealtimeAttenuation (o_gi.indirect.diffuse, data.atten, bakedColorTex);
			#endif // SHADOWS_SCREEN

		#elif DIRLIGHTMAP_SEPARATE
			// Left halves of both intensity and direction lightmaps store direct light; right halves - indirect.

			// Direct
			fixed4 bakedDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, data.ambientOrLightmapUV.xy);
			o_gi.indirect.diffuse += DecodeDirectionalSpecularLightmap (bakedColor, bakedDirTex, normalWorld, false, 0, o_gi.light);

			// Indirect
			half2 uvIndirect = data.ambientOrLightmapUV.xy + half2(0.5, 0);
			bakedColor = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, uvIndirect));
			bakedDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, uvIndirect);
			o_gi.indirect.diffuse += DecodeDirectionalSpecularLightmap (bakedColor, bakedDirTex, normalWorld, false, 0, o_gi.light2);
		#endif
	#endif
	
	#ifdef DYNAMICLIGHTMAP_ON
		// Dynamic lightmaps
		fixed4 realtimeColorTex = UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, data.ambientOrLightmapUV.zw);
		half3 realtimeColor = DecodeRealtimeLightmap (realtimeColorTex) * unity_LightmapIndScale.rgb;

		#ifdef DIRLIGHTMAP_OFF
			o_gi.indirect.diffuse += realtimeColor;

		#elif DIRLIGHTMAP_COMBINED
			half4 realtimeDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_DynamicDirectionality, unity_DynamicLightmap, data.ambientOrLightmapUV.zw);
			o_gi.indirect.diffuse += DecodeDirectionalLightmap (realtimeColor, realtimeDirTex, normalWorld);

		#elif DIRLIGHTMAP_SEPARATE
			half4 realtimeDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_DynamicDirectionality, unity_DynamicLightmap, data.ambientOrLightmapUV.zw);
			half4 realtimeNormalTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_DynamicNormal, unity_DynamicLightmap, data.ambientOrLightmapUV.zw);
			o_gi.indirect.diffuse += DecodeDirectionalSpecularLightmap (realtimeColor, realtimeDirTex, normalWorld, true, realtimeNormalTex, o_gi.light3);
		#endif
	#endif
//	o_gi.indirect.diffuse *= occlusion;

	#ifdef _GLOSSYENV
		half3 worldNormal = reflect(-data.worldViewDir, normalWorld);

		#if UNITY_SPECCUBE_BOX_PROJECTION		
			half3 worldNormal0 = BoxProjectedCubemapDirection (worldNormal, data.worldPos, data.probePosition[0], data.boxMin[0], data.boxMax[0]);
		#else
			half3 worldNormal0 = worldNormal;
		#endif

		half3 env0 = Unity_GlossyEnvironment (UNITY_PASS_TEXCUBE(unity_SpecCube), data.probeHDR[0], worldNormal0, 1-oneMinusRoughness);
		#if UNITY_SPECCUBE_BLENDING
			const float kBlendFactor = 0.99999;
			float blendLerp = data.boxMin[0].w;
			UNITY_BRANCH
			if (blendLerp < kBlendFactor)
			{
				#if UNITY_SPECCUBE_BOX_PROJECTION
					half3 worldNormal1 = BoxProjectedCubemapDirection (worldNormal, data.worldPos, data.probePosition[1], data.boxMin[1], data.boxMax[1]);
				#else
					half3 worldNormal1 = worldNormal;
				#endif

				half3 env1 = Unity_GlossyEnvironment (UNITY_PASS_TEXCUBE(unity_SpecCube1), data.probeHDR[1], worldNormal1, 1-oneMinusRoughness);
				o_gi.indirect.specular = lerp(env1, env0, blendLerp);
			}
			else
			{
				o_gi.indirect.specular = env0;
			}
		#else
			o_gi.indirect.specular = env0;
		#endif
	#endif

//	o_gi.indirect.specular *= occlusion;

	return o_gi;
}

//-------------------------------------------------------------------------------------

// Surface shader output structure to be used with skin shading model
struct SurfaceOutputStandard
{
	fixed3 Albedo;		// diffuse color
	fixed3 Specular;	// specular color
	fixed3 Normal;		// tangent space normal, if written
	half3 Emission;
	half2 Smoothness2;	// 0=rough, 1=smooth
	half Occlusion;
	fixed Alpha;
	// custom inputs
	fixed4 AnisoDir;
    fixed SpecShift;
    fixed SpecNoise;
    fixed3 Specular2;	// 2nd specular color
    fixed AO;
    #if defined(LUX_ATTEN)
    fixed Attenuation;
    #endif
};

inline float3 KajiyaKay (float3 N, float3 T, float3 H, float specNoise) 
{
	float3 B = normalize(T + N * specNoise);
	float dotBH = dot(B,H);
	return sqrt(1-dotBH*dotBH);
}

inline half4 LightingStandard (SurfaceOutputStandard s, half3 viewDir, UnityGI gi)
{

	#define Pi 3.14159265358979323846
	#define OneOnLN2_x6 8.656170

	s.Normal = normalize(s.Normal);
	// energy conservation
	half oneMinusReflectivity = 1 - SpecularStrength(s.Specular);
	half oneMinusRoughness = s.Smoothness2.x;
	s.Albedo = s.Albedo * oneMinusReflectivity;


	half dotNV = max(0, dot(s.Normal, viewDir) ); 			// UNITY BRDF does not normalize(viewDir) ) );
	half3 halfDir = normalize (gi.light.dir + viewDir);
	half dotNH = max (0, dot (s.Normal, halfDir));
	half dotLH = max(0, dot(gi.light.dir, halfDir));	

//  Roughness(es) to Specular Power
    // from https://s3.amazonaws.com/docs.knaldtech.com/knald/1.0.0/lys_power_drops.html
	half2 specPower = 10.0 / log2((s.Smoothness2) * 0.968 + 0.03);
	specPower *= specPower; // * UNITY_PI;

	


//half2 m = roughness * roughness * roughness + 1e-6f;	// follow the same curve as unity_SpecCube
//specPower = (2.0 / m) - 2.0;							// http://jbit.net/%7Esparky/academic/mm_brdf.pdf
//specPower = max(specPower, 1e-5f);	



// lux
// specPower = exp2(10 * s.Smoothness2 + 1); // - 1.75;



// Aniso dir is in tangent space
// normal is in worlspace....

float3 anisoDirWorld = normalize(mul(_Object2World, float4(_AnisoDir.xyz, 0.0)).xyz);


//	1st specular Highlight / Do not add specNoise here 
    half3 spec1 = pow( KajiyaKay(s.Normal, anisoDirWorld * s.SpecShift, halfDir, _PrimaryShift), specPower.x) * specPower.x;
//	2nd specular Highlight
	half3 spec2 = pow( KajiyaKay(s.Normal, anisoDirWorld * s.SpecShift, halfDir, _SecondaryShift ), specPower.y) * s.SpecNoise * specPower.y; 

//	Fresnel: Schlick / fast fresnel approximation
	fixed fresnel = exp2(-OneOnLN2_x6 * dotNH ); // dotNH );
    spec1 *= s.Specular + ( 1.0 - s.Specular ) * fresnel;
    spec2 *= s.Specular2 + ( 1.0 - s.Specular2 ) * fresnel;   
 
    spec1 += spec2;       

   	spec1 *= gi.light.ndotl * 0.25;
    half normTerm = (spec1 + 1.0) / (2.0 * UNITY_PI);
    spec1 *= normTerm;

//	Lazarov 2013, "Getting More Physical in Call of Duty: Black Ops II", changed by EPIC
	const half4 c0 = { -1, -0.0275, -0.572, 0.022 };
	const half4 c1 = { 1, 0.0425, 1.04, -0.04 };
	half4 r = (1-oneMinusRoughness) * c0 + c1;
	half a004 = min( r.x * r.x, exp2( -9.28 * dotNV ) ) * r.x + r.y;
	half2 AB = half2( -1.04, 1.04 ) * a004 + r.zw;
	half3 F_L = (s.Specular  * AB.x + AB.y);



// /////////////

	half4 c = 0;
//	gi.light.ndotl is already clamped, so we have to claculate dotNL again

//	half diff = dot(s.Normal, gi.light.dir) * 0.5 + 0.5;	// Wrapped around diffuse might produce shadow artifacts...
	half diff = dot(s.Normal, gi.light.dir); //half diff = dot(s.Normal, gi.light.dir);
	half dotNL = max(0, diff);





	// Rim
    half Rim = 1.0 - dotNV;
	Rim = _RimStrength * Rim * Rim * Rim;


	// Diffuse Lighting: Lerp shifts the shadow boundrary for a softer look
    float3 diffuse = saturate (lerp (0.25, 1.0, gi.light.ndotl));

    #if !defined (LUX_ATTEN)
	c.rgb =	s.Albedo * (gi.indirect.diffuse * s.AO + (Rim + diffuse) * gi.light.color)
			+ spec1 * gi.light.color
			+ gi.indirect.specular * s.AO * F_L;

	//c.rgb = half3(1,0,0); //spec1;


	#else
	c.rgb =	s.Albedo * (gi.indirect.diffuse * s.AO + (Rim + diffuse) * gi.light.color * s.Attenuation)
			+ spec1 * gi.light.color * s.Attenuation  * (1 - s.Alpha)
			+ gi.indirect.specular * s.AO * F_L;

	//c.rgb = spec1;

		// Do we have to compensate Blending in the additive pass?
		//#if defined (SPOT) || defined (POINT)
		// No, always!
	//		c.rgb = lerp(c.rgb * 0.5, c.rgb, s.Alpha);
		//#endif
	#endif

c.a = 0; //oneMinusRoughness;
//c.rgb = spec1;

	return c;
}



inline void LightingStandard_GI (
	SurfaceOutputStandard s,
	UnityGIInput data,
	inout UnityGI gi)
{
	gi = UnityStandardGlobalIllumination (data, s.Occlusion, s.Smoothness2.x, s.Normal);
}


#endif // UNITY_PBS_LIGHTING_INCLUDED
