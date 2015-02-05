Shader "Lux/Snow" {
	Properties {
		[LM_MasterTilingOffset] [LM_Albedo] _MainTex ("Base (RGB)", 2D) = "white" {}
		[LM_NormalMap] _BumpMap ("Normalmap", 2D) = "bump" {}
		// Reserve R for Metalness?
		_CombinedMap ("AO (G), Smoothness (B), Height (A)", 2D) = "black" {}
		_Parallax ("Parallax Extrusion", Range (0.005, 0.08)) = 0.02
		_AOMapInfluence("AO Map Influence", Range (0.0, 1.0)) = 1.0
		_HeightMapInfluence("Height Map Influence", Range (0.0, 1.0)) = 1.0
		_SnowSize ("Snow Size", Float) = 1.0
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
		#pragma surface surf StandardSpecular vertex:snow
		#pragma target 3.0
		#include "UnityPBSLighting.cginc"

//		Inputs per material
		sampler2D _MainTex;
		sampler2D _BumpMap;
		sampler2D _CombinedMap;

		float _BumpBias;
		float _AOMapInfluence;
		float _HeightMapInfluence;
		float _Parallax;
		float _SnowSize;

//		Inputs from script
		sampler2D _Lux_SnowAlbedo;
		sampler2D _Lux_SnowNormal;
		float2 _Lux_SnowHeightParams; // x: start height / y: blend zone
		float _Lux_SnowAmount;
		float2 _Lux_SnowWindErosion;
		float4 _Lux_SnowMelt;	// x: SnowMelt / y: SnowMelt 2^(-10 * (x)) 
		float4 _Lux_Wind;
		float _Lux_SnowIcyness;
		//half3 _Lux_SnowSubColor;
		//float3 _Lux_SunDir;
		//half3 _Lux_SunColor;

		struct Input {
			float2 uv_MainTex;
			float3 viewDir;
			float snowHeightFadeState;
			//float3 worldFaceNormal;
			float3 worldNormal;
			float3 worldPos;
			INTERNAL_DATA
		};

		void snow (inout appdata_full v, out Input o) {	
			UNITY_INITIALIZE_OUTPUT(Input,o);
			//o.worldFaceNormal = UnityObjectToWorldNormal(v.normal); //.y;
			o.worldPos = mul (_Object2World, v.vertex).xyz;
			o.snowHeightFadeState = saturate((o.worldPos.y - _Lux_SnowHeightParams.x) / _Lux_SnowHeightParams.y);
			o.snowHeightFadeState = sqrt(o.snowHeightFadeState);
			//	easing exponential out
			//	o.snowHeightFadeState = 1.0 - pow(2.0, -10 * o.snowHeightFadeState );
		}

		void surf (Input IN, inout SurfaceOutputStandardSpecular o) {
			half height = tex2D (_CombinedMap, IN.uv_MainTex).a;
			//	Calc Parallax Extrusion
    		float2 offset = ParallaxOffset (height, _Parallax, IN.viewDir);
    		//	Apply the Parallax Extrusion
    		float2 main_uv = IN.uv_MainTex + offset;

			half4 c = tex2D (_MainTex, main_uv);
			o.Albedo = c.rgb;
			o.Alpha = c.a;
			o.Normal = UnpackNormal(tex2D (_BumpMap, main_uv));

			half4 snowAlbedoSmoothness = tex2D(_Lux_SnowAlbedo, main_uv * _SnowSize);
			half3 snowNormal = UnpackNormal(tex2D(_Lux_SnowNormal, main_uv * _SnowSize));


			half4 distributionmap = tex2D (_CombinedMap, main_uv); //.rga; // g = ao
			distributionmap.r = distributionmap.r * _AOMapInfluence; //lerp(1.0, distributionmap.r, _AOMapInfluence);

		//	Snow functions
			float3 worldNormal = WorldNormalVector (IN, o.Normal);

		//	Snow Accumulation
			#define AOSample distributionmap.r
			#define invAOSample 1-distributionmap.r
			#define HeightSample distributionmap.a*_HeightMapInfluence
			#define SnowFlakeMask snowAlbedoSmoothness.a

			float snowAmount;
			float wetnessMask;
			float snowNormalAmount;

			if (IN.snowHeightFadeState > 0.0 && _Lux_SnowAmount > 0.0 ) {
				_Lux_SnowAmount *= IN.snowHeightFadeState;
			//	Wind erosion	
				float winderosion = lerp( invAOSample, (HeightSample + AOSample) * 0.5, _Lux_SnowWindErosion.x);
			//	Micro erosion: lerp between winderosion + flakes and winderosion only
				float snowdistribution = lerp( (winderosion + SnowFlakeMask ) * 0.5, winderosion, _Lux_SnowWindErosion.y );
			//	Melting: lerp towards invAO only 
				snowdistribution = lerp ( snowdistribution, winderosion, _Lux_SnowMelt.y )  ;

				float snowMask = saturate( (_Lux_SnowAmount - snowdistribution) * 8 );
				snowMask *= snowMask * snowMask * snowMask;
				snowAmount = snowMask * saturate (dot(worldNormal, _Lux_Wind.xyz));
				wetnessMask = saturate(  (_Lux_SnowMelt.x * (4.0 + _Lux_SnowAmount) - (HeightSample + SnowFlakeMask) * 0.5) );
				// Accumulate Water in crackles according to heightmap
				wetnessMask = saturate(  (_Lux_SnowMelt.y - (HeightSample + SnowFlakeMask) * 0.25  ) );
				snowNormalAmount = snowAmount * snowAmount;
			}
		//	End Snow Accumulation

		//	////////////////
			o.Smoothness = distributionmap.b;
			o.Specular = 0.04;

			if (IN.snowHeightFadeState > 0.0 && _Lux_SnowAmount > 0.0 ) {
				// Lerp all outputs towards water
				if (_Lux_SnowMelt.x > 0) {
					float porosity = saturate((( (1 - o.Smoothness) - 0.5)) / 0.4 );
					// Materials (like metal) which are not porose should not be darkened, so we have to find the metal parts:
					// As metals have high specular color values (>0.33) we can use SpecularColor to identify those
					float metalness = saturate((dot(o.Specular, 0.33) * 1000 - 500) );
					float factor = lerp(1, 0.2, (1 - metalness) * porosity);
				
					// Lerp all outputs towards wetness
					o.Albedo *= lerp(1.0, factor, wetnessMask);
					o.Normal = lerp(o.Normal, float3(0,0,1), wetnessMask);
					o.Smoothness = lerp(distributionmap.b, 0.8, wetnessMask);
					// spec color of ice is pretty low
					o.Specular = lerp(o.Specular, 0.02, wetnessMask);			
				}

				// Lerp all outputs towards snow
				o.Albedo = lerp(o.Albedo, snowAlbedoSmoothness.rgb, snowAmount);
				o.Normal = lerp(o.Normal, snowNormal, snowNormalAmount);
				o.Smoothness = lerp(o.Smoothness, (1.0 - SnowFlakeMask) * 0.75 * _Lux_SnowIcyness, snowAmount);

				float crystals = saturate(0.65 - SnowFlakeMask);
				o.Smoothness = lerp(o.Smoothness, crystals * _Lux_SnowIcyness , snowAmount);
				o.Specular = lerp(o.Specular, snowAlbedoSmoothness.a * 0.15, snowAmount);
			}
		}
		ENDCG
	} 
	FallBack "Diffuse"
}
