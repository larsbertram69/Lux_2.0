// Based on:
// http://amd-dev.wpengine.netdna-cdn.com/wordpress/media/2012/10/Scheuermann_HairRendering.pdf
// http://blog.leocov.com/2010/08/lchairshadercgfx-maya-realtime-hair.html

Shader "Lux/Human/Hair AlphaTesting" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_Cutoff ("Alpha cutoff", Range(0,1)) = 0.5
		_BumpMap ("Normal (Normal)", 2D) = "bump" {}
		_SpecularTex ("Specular Shift (R) Roughness (G) Noise (B)", 2D) = "white" {}

        _AnisoDir ("Anisotropic Direction (XYZ)" , Vector) = (0.0,1.0,0.0,0.0)

        _SpecularColor1 ("Primary Specular Color", Color) = (0.03,0.03,0.03,1)
        _PrimaryShift ("Primary Spec Shift", Range(0,2)) = 1
        _Smoothness1 ("Primary Smoothness", Range(0,1)) = 0.5

        _SpecularColor2 ("Secondary Specular Color", Color) = (0.04,0.04,0.04,1)
        _SecondaryShift ("Secondary Spec Shift", Range(0,2)) = 1
        _Smoothness2 ("Secondary Smoothness", Range(0,1)) = 0.5

        _RimStrength("Rim Light Strength", Range(0,1)) = 0.5

	}

	CGINCLUDE
		//@TODO: should this be pulled into a shader_feature, to be able to turn it off?
		#define _GLOSSYENV 1
		#define UNITY_SETUP_BRDF_INPUT SpecularSetup
	ENDCG

	SubShader {
		Tags {
			"Queue"="AlphaTest"
			"IgnoreProjector"="True"
			"RenderType"="TransparentCutout"
		}
		LOD 300

		CGPROGRAM
		// addshadow needed to make alpha cut off work withg shadows? addshadow
		#pragma surface surf Standard addshadow fullforwardshadows alphatest:_Cutoff exclude_path:prepass nolightmap nodirlightmap
		#include "Includes/LuxHairLighting.cginc"
		#pragma target 3.0
		#pragma shader_feature _LUX_DEFERRED

		//	Prevent shader from rendering fog (needed when used with deferred rendering and global fog)
		#ifdef _LUX_DEFERRED
			#undef UNITY_APPLY_FOG
			#define UNITY_APPLY_FOG(coord,col) /**/
		#endif

		sampler2D _MainTex;
		sampler2D _SpecularTex;
        sampler2D _BumpMap;

        float _Smoothness1;
        float _Smoothness2;

		struct Input {
			float2 uv_MainTex;
			float4 color : COLOR; // R stores Ambient Occlusion
		};

		void surf (Input IN, inout SurfaceOutputStandard o) {
			half4 c = tex2D (_MainTex, IN.uv_MainTex);
			o.Albedo = c.rgb;
			o.Alpha = c.a;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex));

			// r: spec shift / g: smoothness / b: noise
            fixed3 spec = tex2D(_SpecularTex, IN.uv_MainTex).rgb;

            // store per pixel Spec Shift
            o.SpecShift = spec.r * 2 -1;
            // store Smoothnesses for direct lighting
            o.Smoothness2 = half2(spec.g * _Smoothness1, spec.g * _Smoothness2);
            // store per pixel Spec Noise
            o.SpecNoise = spec.b;

            o.Specular = _SpecularColor1.rgb;
            o.Specular2 = _SpecularColor2.rgb;

            o.Occlusion = 1;
            o.AO = IN.color.g;

		}
		ENDCG
	}
}
