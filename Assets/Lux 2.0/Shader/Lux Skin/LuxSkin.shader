// //////////////////////////
// Preintegrated Sub Surface Scattering Shader based on Eric Penner
// Original code by James O'Hare: http://www.farfarer.com/blog/2013/02/11/pre-integrated-skin-shader-unity-3d/


Shader "Lux/Human/Skin" {
	Properties {
		_MainTex ("Base (RGB) Alpha (A)", 2D) = "white" {}
		// _SpecularReflectivity("Specular Reflectivity", Color) = (0.028,0.028,0.028)
		_SpecTex ("Specular (R) Smoothness (G) SSS Mask (B), AO (A)", 2D) = "gray" {}
		_BumpMap ("Normalmap", 2D) = "bump" {}

		// BRDF Lookup texture, light direction on x and curvature on y.
		_BRDFTex ("BRDF Lookup (RGB)", 2D) = "gray" {}
		// Curvature scale. Multiplier for the curvature - best to keep this very low - between 0.02 and 0.002.
		_CurvatureScale ("Curvature Scale", Float) = 0.02
		// Which mip-map to use when calculating curvature. Best to keep this between 1 and 2.
		_BumpBias ("Normal Map Blur Bias", Float) = 1.5

		_Power ("Subsurface Power (1.0 - 5.0)", Float) = 2.0
		_Distortion ("Subsurface Distortion (0.0 - 0.5)", Float) = 0.1
		_Scale ("Subsurface Scale (1.0 - )", Float) = 2.0
		_SubColor ("Subsurface Color", Color) = (1, .4, .25, 1)

	}

	CGINCLUDE
		//@TODO: should this be pulled into a shader_feature, to be able to turn it off?
		#define _GLOSSYENV 1
		#define UNITY_SETUP_BRDF_INPUT SpecularSetup
	ENDCG


	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 300
		
		CGPROGRAM
		#pragma surface surf Standard fullforwardshadows exclude_path:prepass nolightmap nodirlightmap
	//	#include "UnityPBSLighting.cginc"
		#include "Includes/LuxSkinLighting.cginc"
		#pragma target 3.0
		#pragma shader_feature _LUX_DEFERRED

	//	Prevent shader from rendering fog (needed when used with deferred rendering and global fog)
		#ifdef _LUX_DEFERRED
			#undef UNITY_APPLY_FOG
			#define UNITY_APPLY_FOG(coord,col) /**/
		#endif

		sampler2D _MainTex;
		sampler2D _BumpMap;
		sampler2D _SpecTex;
		//sampler2D _BRDFTex; // moved to lighting function like all other inputs needed there

		float _BumpBias;
		float _CurvatureScale;

		struct Input {
			float2 uv_MainTex;
			float3 worldPos;
			float3 worldNormal;
			INTERNAL_DATA
		};

		void surf (Input IN, inout SurfaceOutputStandard o) {
			half4 c = tex2D (_MainTex, IN.uv_MainTex);
			o.Albedo = c.rgb;
			o.Alpha = c.a;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex));

		//	sample combined spec / roughness / sss / ao map
			fixed4 combinedMap = tex2D(_SpecTex, IN.uv_MainTex);

		//	now setup the missing base inputs
			o.Specular = combinedMap.r;
			o.Smoothness = combinedMap.g;
			o.SSS = combinedMap.b;

		//	Ambient Occlusion
			o.Occlusion = combinedMap.a;

		//	//////////////////////////////////////////////////////////
		// 	Skin shader specific functions

		//	Calculate the curvature of the model dynamically
			fixed3 blurredWorldNormal = UnpackNormal( tex2Dlod ( _BumpMap, float4 ( IN.uv_MainTex, 0.0, _BumpBias ) ) );
		//	Transform it into a world normal so we can get good derivatives from it.
			blurredWorldNormal = WorldNormalVector( IN, blurredWorldNormal );
			o.NormalBlur = blurredWorldNormal;
		//	Get the scale of the derivatives of the blurred world normal and the world position.
			#if (SHADER_TARGET > 40) //SHADER_API_D3D11
            // In DX11, ddx_fine should give nicer results.
            	float deltaWorldNormal = length( abs(ddx_fine(blurredWorldNormal)) + abs(ddy_fine(blurredWorldNormal)) );
            	float deltaWorldPosition = length( abs(ddx_fine(IN.worldPos)) + abs(ddy_fine(IN.worldPos)) );
            #else
				//float deltaWorldNormal = length( fwidth( blurredWorldNormal ) );
				float deltaWorldNormal = length( fwidth( blurredWorldNormal ) );
				float deltaWorldPosition = length( fwidth ( IN.worldPos ) );
			#endif		
			o.Curvature = (deltaWorldNormal / deltaWorldPosition) * _CurvatureScale; // * combinedMap.b;

		}
		ENDCG
		
	}
	FallBack "Diffuse"
}
