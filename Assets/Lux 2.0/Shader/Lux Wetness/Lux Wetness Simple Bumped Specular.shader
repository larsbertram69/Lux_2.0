Shader "Lux/Wetness/Simple Bumped Specular" {
	Properties {
		[LM_MasterTilingOffset] [LM_Albedo] _MainTex ("Base (RGB)", 2D) = "white" {}
		[LM_NormalMap] _BumpMap ("Normalmap", 2D) = "bump" {}
		[LM_Specular] [LM_Glossiness] _SpecTex ("Specular Color (RGB) Smoothness (A)", 2D) = "black" {}

		// Special Properties needed by all wetness shaders
		_WetnessWorldNormalDamp ("Wetness WorldNormal Damp", Range(0,1)) = 0.5

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
		#pragma surface surf StandardSpecular fullforwardshadows
		#pragma target 3.0
		#include "UnityPBSLighting.cginc"

//	///////////////////////////////////////
//	Config Wetness
		#define WetnessMaskInputVertexColors // WetnessMask is stored in vertex.color.g / comment this if you want to use a texture instead
    
    	#ifdef WetnessMaskInputVertexColors
        	// #define PuddleMask IN.color.g // Puddles are not supported by this shader
        	#define WetMask IN.color.b
    	#else
        	// If You do not want to use vertex colors to define wet vs. dry or puddles you could use a texture instead:
        	// Do not forget that you have to declare the texture using sampler2D and sample it in the surface function
        	// In this example we take both values from the _unnamed texture
        	// #define PuddleMask _unnamed.g // Puddles are not supported in this shader
        	#define WetMask _unnamed.b
    	#endif

//	///////////////////////////////////////	

		// Include wetness specific functions and properties
		#include "Includes/LuxWetness.cginc"

		sampler2D _MainTex;
		sampler2D _BumpMap;
		sampler2D _SpecTex;
		// Wetness specific Properties are defined in the include file

		struct Input {
			float2 uv_MainTex;
			#ifdef WetnessMaskInputVertexColors
            	fixed4 color : COLOR;
        	#endif
        	float3 worldNormal;		// Needed by Wetness
        	INTERNAL_DATA
		};

		void surf (Input IN, inout SurfaceOutputStandardSpecular o) {

		//	//////////////////
		//	Wetness specific

    		float2 main_uv = IN.uv_MainTex;

    		fixed4 HeightWetness = 1;


    	//	//////////////////
    	//	Standard functions
    		// Sample the Base Textures
			half4 diff_albedo = tex2D(_MainTex, main_uv);
    		half4 spec_albedo = tex2D(_SpecTex, main_uv);
    		// Specular Color
			o.Specular = spec_albedo.rgb;
			// Roughness
			o.Smoothness = spec_albedo.a;
			// Albedo
			o.Albedo = diff_albedo.rgb;
			// Normal
			o.Normal = UnpackNormal(tex2D(_BumpMap, main_uv));
			// Alpha
			o.Alpha = diff_albedo.a;

		//	//////////////////
		//	Wetness specific
			if (_Lux_WaterFloodlevel.x > 0 && WetMask > 0 ) {
				// Calculate worldNormal of Pixel
				float3 worldNormalFace = WorldNormalVector(IN, o.Normal);
				// Damp overall WaterAccumulation according to the worldNormal.y Component
    			float worldNormalDamp = saturate( saturate(worldNormalFace.y) + _WetnessWorldNormalDamp); 
	        	// Claculate Wetness / wetFactor.x = overall Wetness Factor / wetFactor.y = special Wetness Factor for Raindrops
	    		float wetFactor = _Lux_WaterFloodlevel.x * worldNormalDamp.xx * WetMask;
				
				// Calling "o.Smoothness = WaterBRDF()" will tweak o.Albedo, o.Smoothness and o.Specular according to the overall wetness (wetFactor.x)
				o.Smoothness = WaterBRDF(o.Albedo, o.Smoothness, o.Specular, wetFactor.x);
				// Finally tweak o.Normal based on the overall Wetness Factor
				o.Normal = lerp(o.Normal, fixed3(0,0,1), wetFactor.x );
			}
		//	//////////////////

		}
		ENDCG
	} 
	FallBack "Bumped Diffuse"
}
