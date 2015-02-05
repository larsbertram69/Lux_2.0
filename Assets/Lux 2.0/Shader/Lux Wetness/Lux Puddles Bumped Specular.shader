Shader "Lux/Wetness/Puddles" {
	Properties {
		[LM_MasterTilingOffset] [LM_Albedo] _MainTex ("Base (RGB)", 2D) = "white" {}
		[LM_NormalMap] _BumpMap ("Normalmap", 2D) = "bump" {}
		[LM_Specular] [LM_Glossiness] _SpecTex ("Specular Color (RGB) Smoothness (A)", 2D) = "black" {}

		// Special Properties needed by Heightmap based wetness shaders
		_HeightWetness("Heightmap(A) Puddle Noise(R)", 2D) = "white" {}
    	_Parallax ("Parallax Extrusion", Range (0.005, 0.08)) = 0.02

    	// Special Properties needed by wetness shaders using tex2Dlod
    	_TextureSize ("Texture Size", Float) = 1024
		_MipBias ("Mip Bias", Float) = 0.75

		// Special Properties needed by all wetness shaders
		_WetnessWorldNormalDamp ("Wetness WorldNormal Damp", Range(0,1)) = 0.5
		_WetnessHeightMapInfluence  ("Wetness HeightMap Influence", Range(0,1)) = 1

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
		#define WetnessMaskInputVertexColors // PuddleMask is stored in vertex.color.g / comment this if you want to use a texture instead
    
    	#ifdef WetnessMaskInputVertexColors
        	#define PuddleMask IN.color.g
        	#define WetMask IN.color.b
    	#else
        	// If You do not want to use vertex colors to define wet vs. dry or puddles you could use a texture instead:
        	// Do not forget that you have to declare the texture using sampler2D and sample it in the surface function
        	// In this example we take both values from the _HeightWetness texture
        	#define PuddleMask _HeightWetness.g
        	#define WetMask _HeightWetness.b
    	#endif

    	//	Use this define to enable water ripples (needed by LuxWetness.cginc )
    	#define Lux_WaterRipples
//	///////////////////////////////////////	

		// Include wetness specific functions and properties
		#include "Includes/LuxWetness.cginc"

		sampler2D _MainTex;
		sampler2D _BumpMap;
		sampler2D _SpecTex;

		float _Parallax;
		float _TextureSize;
		float _MipBias;
		// Wetness specific Properties are defined in the include file

		struct Input {
			float2 uv_MainTex;
			#ifdef WetnessMaskInputVertexColors
            	fixed4 color : COLOR;
        	#endif
        	float3 worldNormal;		// Needed by Wetness
        	float3 viewDir;			// needed by Parallax
        	float3 worldPos;		// Needed by Wetness
        	INTERNAL_DATA
		};

		void surf (Input IN, inout SurfaceOutputStandardSpecular o) {

		//	Sample combined Height and Wetness Map first as we need both to calculate Wetness: A = height / R = Puddle Noise
        	fixed4 HeightWetness = tex2D(_HeightWetness, IN.uv_MainTex);

        //	Calculate miplevel (needed by tex2Dlod)
			// Calculate componentwise max derivatives
			float2 dx1 = ddx( IN.uv_MainTex * _TextureSize * _MipBias );
			float2 dy1 = ddy( IN.uv_MainTex * _TextureSize * _MipBias );
			float d = max( dot( dx1, dx1 ), dot( dy1, dy1 ) );
			float2 lambda = 0.5 * log2(d);

		//	//////////////////
		//	Wetness specific

			float3 rippleNormal = float3(0,0,1);
			float2 wetFactor = float2(0,0);

			if (_Lux_WaterFloodlevel.x + _Lux_WaterFloodlevel.y > 0 && WetMask > 0 ) {
		        // Calculate worldNormal of Face
		        float3 worldNormalFace = WorldNormalVector(IN, float3(0,0,1));
		        // Claculate Wetness / wetFactor.x = overall Wetness Factor / wetFactor.y = special Wetness Factor for Raindrops
		    	wetFactor = ComputeWaterAccumulation(PuddleMask, HeightWetness.ar, worldNormalFace.y ) * WetMask;
		    	// Add Water Ripples
		    	// Calc Ripple Distance
	    		float fadeOutWaterBumps = saturate( ( _Lux_WaterBumpDistance - distance(_WorldSpaceCameraPos, IN.worldPos)) / 5);
	    		// Limit Ripples to Distance
	    		if (fadeOutWaterBumps > 0 && _Lux_RainIntensity > 0) {
		    		rippleNormal = AddWaterRipples(wetFactor, IN.worldPos, lambda, fadeOutWaterBumps);
		    	}
		    } 

		    //	Now we can apply the Parallax Extrusion
    		float2 offset = ParallaxOffset (HeightWetness.a, _Parallax, IN.viewDir);
    		//	Add Height and Refraction
    		float2 main_uv = IN.uv_MainTex + offset + rippleNormal.xy;


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
			if (_Lux_WaterFloodlevel.x + _Lux_WaterFloodlevel.y > 0 && WetMask > 0 ) {
				// Calling "o.Smoothness = WaterBRDF()" will tweak o.Albedo, o.Smoothness and o.Specular according to the overall wetness (wetFactor.x)
				o.Smoothness = WaterBRDF(o.Albedo, o.Smoothness, o.Specular, wetFactor.x);
				// Finally tweak o.Normal based on the overall Wetness Factor
				o.Normal = lerp(o.Normal, rippleNormal, wetFactor.y);
			}
		//	//////////////////
		}
		ENDCG
	} 
	FallBack "Bumped Diffuse"
}
