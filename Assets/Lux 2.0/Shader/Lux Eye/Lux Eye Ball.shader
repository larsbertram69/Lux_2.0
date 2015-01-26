Shader "Lux/Human/Eye Ball" {
	Properties {
		[LM_MasterTilingOffset] [LM_Albedo] _MainTex ("Base (RGB) Height(A)", 2D) = "white" {}
		[LM_Specular] [LM_Glossiness] _SpecTex ("Specular Color (RGB) Roughness (A)", 2D) = "black" {}
		[LM_NormalMap] _BumpMap ("Normalmap", 2D) = "bump" {}

		_PupilSize ("PupilSize", Range (0.01, 1)) = 0.5
		_Parallax ("Height", Range (0.005, 0.08)) = 0.08
	}

	CGINCLUDE
		//@TODO: should this be pulled into a shader_feature, to be able to turn it off?
		#define _GLOSSYENV 1
		#define UNITY_SETUP_BRDF_INPUT SpecularSetup
	ENDCG

	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		CGPROGRAM
		#pragma surface surf StandardSpecular fullforwardshadows
		#pragma target 3.0
		#include "UnityPBSLighting.cginc"

		sampler2D _MainTex;
		sampler2D _BumpMap;
		sampler2D _SpecTex;
		// shader specific inputs
		float _PupilSize;
		float _Parallax;

		struct Input {
			float2 uv_MainTex;
			float3 viewDir;
		};

		void surf (Input IN, inout SurfaceOutputStandardSpecular o) {
		//	Calculate Parallax
			half h = tex2D (_MainTex, IN.uv_MainTex).a;
			float2 offset = ParallaxOffset (h, _Parallax, IN.viewDir);

		//	Apply Pupil Size
			float2 UVs = IN.uv_MainTex;
			float2 delta = float2(0.5, 0.5) - UVs;
			// Calculate pow(distance,2) to center (pythagoras...)
			float factor = (delta.x*delta.x + delta.y*delta.y); 
			// Clamp it in order to mask our pixels, then bring it back into 0 - 1 range
			// Max distance = 0.15 --> pow(max,2) = 0.0225
			factor = saturate(0.0225 - factor) * 44.444;
			UVs += delta * factor * _PupilSize;

		//	Now sample albedo and spec maps according to the pupil’s size and parallax
			o.Albedo = tex2D(_MainTex, UVs + offset).rgb;
			o.Alpha = 1;
			fixed4 spec_albedo = tex2D(_SpecTex, UVs + offset);
		//	Normal map
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex)); // - offset));
		//	Specular Color
			o.Specular = spec_albedo.rgb;
		//	Smoothness
			o.Smoothness = spec_albedo.a;

		}
		ENDCG
	} 
	FallBack "Diffuse"
}
