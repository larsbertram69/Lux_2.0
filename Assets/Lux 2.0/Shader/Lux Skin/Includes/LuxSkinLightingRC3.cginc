#include "UnityLightingCommon.cginc"
#include "UnityGlobalIllumination.cginc"

//-------------------------------------------------------------------------------------

sampler2D _BRDFTex;
float _Power;
float _Scale;
float _Distortion;
fixed3 _SubColor;

//-------------------------------------------------------------------------------------


struct SurfaceOutputSkin {
	fixed3 Albedo;
	fixed3 Normal;
	fixed3 Emission;
	half Smoothness;
	half Occlusion;
	fixed Alpha;
	half3 Specular;

	fixed SSS;
	fixed3 NormalBlur;
	float Curvature;
};

inline fixed4 CookTorrenceLight (SurfaceOutputSkin s, half3 viewDir, UnityGI gi)
{
//	///////////////////////////

	s.Normal = normalize(s.Normal);

	half oneMinusReflectivity;
	s.Albedo = EnergyConservationBetweenDiffuseAndSpecular (s.Albedo, s.Specular, /*out*/ oneMinusReflectivity);

	// shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
	// this is necessary to handle transparency in physically correct way - only diffuse component gets affected by alpha
	half outputAlpha;
	s.Albedo = PreMultiplyAlpha (s.Albedo, s.Alpha, oneMinusReflectivity, /*out*/ outputAlpha);

	#define oneMinusRoughness s.Smoothness
	
	half diff = dot(s.NormalBlur, gi.light.dir);
	half dotNL = max(0, diff);

	#define Pi 3.14159265358979323846
	#define OneOnLN2_x6 8.656170

	half dotNV = max(0, dot(s.Normal, viewDir) ); 			// UNITY BRDF does not normalize(viewDir) ) );
	half3 halfDir = normalize (gi.light.dir + viewDir);
	half dotNH = max (0, dot (s.Normal, halfDir));

	half dotLH = max(0, dot(gi.light.dir, halfDir));

	//	We must NOT max dotNLBlur due to Half-Lambert lighting
	float dotNLBlur = dot( s.NormalBlur, gi.light.dir);


//	////////////////////////////////////////////////////////////
//	Cook Torrrance
//	from The Order 1886 // http://blog.selfshadow.com/publications/s2013-shading-course/rad/s2013_pbs_rad_notes.pdf
	half alpha = 1 - s.Smoothness; // alpha is roughness
	alpha *= alpha;
	half alpha2 = alpha * alpha;

//	Specular Normal Distribution Function: GGX Trowbridge Reitz
	half denominator = (dotNH * dotNH) * (alpha2 - 1.f) + 1.f;
	half D = alpha2 / (Pi * denominator * denominator);
//	Geometric Shadowing: Smith
	// B. Karis, http://graphicrants.blogspot.se/2013/08/specular-brdf-reference.html
	half G_L = dotNL + sqrt( (dotNL - dotNL * alpha) * dotNL + alpha );
	half G_V = dotNV + sqrt( (dotNV - dotNV * alpha) * dotNV + alpha );
	half G = 1.0 / (G_V * G_L);
//	Fresnel: Schlick / fast fresnel approximation
	half F = 1 - oneMinusReflectivity + ( oneMinusReflectivity) * exp2(-OneOnLN2_x6 * dotNH );
	
	// half3 FresnelSchlickWithRoughness = s.Specular + ( max(s.Specular, oneMinusRoughness) - s.Specular) * exp2(-OneOnLN2_x6 * dotNV );

//	Lazarov 2013, "Getting More Physical in Call of Duty: Black Ops II", changed by EPIC
	const half4 c0 = { -1, -0.0275, -0.572, 0.022 };
	const half4 c1 = { 1, 0.0425, 1.04, -0.04 };
	half4 r = (1-oneMinusRoughness) * c0 + c1;
	half a004 = min( r.x * r.x, exp2( -9.28 * dotNV ) ) * r.x + r.y;
	half2 AB = half2( -1.04, 1.04 ) * a004 + r.zw;
	half3 F_L = s.Specular * AB.x + AB.y;

//	Skin Lighting
	float2 brdfUV;
	// Half-Lambert lighting value based on blurred normals.
	brdfUV.x = dotNLBlur * 0.5 + 0.5;
	// Curvature amount. Multiplied by light's luminosity so brighter light = more scattering.
	// Pleae note: gi.light.color already contains light attenuation
	brdfUV.y = s.Curvature * dot(gi.light.color, fixed3(0.22, 0.707, 0.071));
	half3 brdf = tex2D( _BRDFTex, brdfUV ).rgb;

//	Translucency
//	#if defined (DIRECTIONAL) && defined (LUX_DIRECTIONAL_SSS) || defined (DIRECTIONAL_COOKIE) && defined (LUX_DIRECTIONAL_SSS) || defined (POINT) && defined (LUX_POINT_SSS) || defined (POINT_COOKIE) && defined (LUX_POINT_SSS) || defined (SPOT) && defined (LUX_SPOT_SSS)
		half3 transLightDir = gi.light.dir + s.Normal * _Distortion;
		float transDot = pow ( saturate(dot ( viewDir, -transLightDir ) ) * s.SSS * s.SSS, _Power ) * _Scale;
		half3 lightScattering = transDot * _SubColor * gi.light.color;

//	#endif
//	Final composition
	half4 c = 0;
	c.rgb = s.Albedo * gi.light.color * lerp(dotNL.xxx, brdf, s.SSS)	// diffuse
		//	#if defined (DIRECTIONAL) && defined (LUX_DIRECTIONAL_SSS) || defined (DIRECTIONAL_COOKIE) && defined (LUX_DIRECTIONAL_SSS) || defined (POINT) && defined (LUX_POINT_SSS) || defined (POINT_COOKIE) && defined (LUX_POINT_SSS) || defined (SPOT) && defined (LUX_SPOT_SSS)
				+ lightScattering
		//	#endif																				// translucency
			+ D * G * F * gi.light.color * dotNL 												// direct specular
			+ gi.indirect.specular * F_L; // * FresnelSchlickWithRoughness;						// indirect specular

	return c;
}

inline fixed4 LightingSkin (SurfaceOutputSkin s, half3 viewDir, UnityGI gi)
{
	fixed4 c;
	c = CookTorrenceLight (s, viewDir, gi);

	#if defined(DIRLIGHTMAP_SEPARATE)
		#ifdef LIGHTMAP_ON
			c += UnityBlinnPhongLight (s, viewDir, gi.light2);
		#endif
		#ifdef DYNAMICLIGHTMAP_ON
			c += UnityBlinnPhongLight (s, viewDir, gi.light3);
		#endif
	#endif

	#ifdef UNITY_LIGHT_FUNCTION_APPLY_INDIRECT
		c.rgb += s.Albedo * gi.indirect.diffuse;
	#endif

//	c.rgb = gi.indirect.specular;

	return c;
}

inline void LightingSkin_GI (
	SurfaceOutputSkin s,
	UnityGIInput data,
	inout UnityGI gi)
{
	gi = UnityGlobalIllumination (data, s.Occlusion, s.Smoothness, s.Normal, true); // reflections = true
}

