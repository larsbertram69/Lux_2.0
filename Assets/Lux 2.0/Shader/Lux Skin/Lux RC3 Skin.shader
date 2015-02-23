Shader "Lux/Human/Skin RC3" {
	Properties {
		_Color ("Main Color", Color) = (1,1,1,1)
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_BumpMap ("Normalmap", 2D) = "bump" {}

		_SpecTex ("Specular (R) Smoothness (G) SSS Mask (B), AO (A)", 2D) = "gray" {}

		_Smoothness ("Smotthness", Range (0.00, 1)) = 0.5

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
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		CGPROGRAM
		#pragma surface surf Skin addshadow
		#include "Includes/LuxSkinLightingRC3.cginc"
		#pragma target 3.0

		sampler2D _MainTex;
		sampler2D _BumpMap;
		sampler2D _SpecTex;
		fixed4 _Color;
		float _Smoothness;

		float _BumpBias;
		float _CurvatureScale;

		struct Input {
			float2 uv_MainTex;
			float3 worldPos;
			float3 worldNormal;
			INTERNAL_DATA
		};

		void surf (Input IN, inout SurfaceOutputSkin o) {
			half4 c = tex2D (_MainTex, IN.uv_MainTex);
			o.Albedo = c.rgb * _Color;
			o.Alpha = c.a;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex));

			//o.Specular = half3(0.5,0.5,0.5);
			//o.Smoothness = _Smoothness;

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
				float deltaWorldNormal = length( fwidth( blurredWorldNormal ) );
				float deltaWorldPosition = length( fwidth ( IN.worldPos ) );
			#endif		
			o.Curvature = (deltaWorldNormal / deltaWorldPosition) * _CurvatureScale; // * combinedMap.b;


		}
		ENDCG
	} 
}