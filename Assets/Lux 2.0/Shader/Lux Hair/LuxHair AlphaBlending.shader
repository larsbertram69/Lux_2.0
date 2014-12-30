Shader "Lux/Human/Hair AlphaBlending" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_Cutoff ("Alpha cutoff", Range(0,1)) = 0.5
		_AlphaFactor ("Alpha Factor", Range(1,4)) = 1.0
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
			"Queue"="AlphaTest-1" 
			"IgnoreProjector"="True" 
			"RenderType"="TransparentCutout"
		}
		LOD 200

		CGPROGRAM
		#pragma surface surf Standard vertex:vert alpha exclude_path:prepass nolightmap nodirlightmap
		// fullforwardshadows 
		
		#define LUX_ATTEN
		#include "Includes/LuxHairLighting.cginc"

		#pragma target 3.0
		#include "UnityCG.cginc"
		#include "Lighting.cginc"
		#include "AutoLight.cginc"

		sampler2D _MainTex;
		sampler2D _SpecularTex;
        sampler2D _BumpMap;

        float _Smoothness1;
        float _Smoothness2;

        float _Cutoff;
        float _AlphaFactor;

	//	As we use alpha _ShadowMapTexture is not defined. So we have to do it our own.
		#if defined (POINT)
			uniform samplerCUBE_float _ShadowMapTexture;
		#else
			UNITY_DECLARE_SHADOWMAP(_ShadowMapTexture);
			float4 _ShadowMapTexture_TexelSize;
		#endif
		

		struct Input {
			float4 color : COLOR; 	// R stores Ambient Occlusion
			float2 uv_MainTex;
			float4 screenPos;
			float4 myworldPos;		// We can’t use built in worldPos here!? as we need float4
		};


		void vert (inout appdata_full v, out Input o)
		{
			UNITY_INITIALIZE_OUTPUT(Input,o);
			o.myworldPos = mul(_Object2World, v.vertex);
		}


		void surf (Input IN, inout SurfaceOutputStandard o) {

			half4 c = tex2D (_MainTex, IN.uv_MainTex);
			clip( _Cutoff - c.a);

			c.a = saturate(c.a * _AlphaFactor);
			o.Albedo = c.rgb;

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


        //	//////////////////////////////////////////////
        //	Manually sample the shadows
			
			half3 myshadow = half3(1.0,1.0,1.0);

		//	Directional shadows
			#if defined (DIRECTIONAL)
				// always use 4 taps to soften shadows
				float2 finaluv = IN.screenPos.xy / IN.screenPos.w;
				half4 shadows;
				shadows.x = tex2D (_ShadowMapTexture, finaluv);
				shadows.y = tex2D (_ShadowMapTexture, finaluv + _ShadowMapTexture_TexelSize.xy * float2(1, 0));
				shadows.z = tex2D (_ShadowMapTexture, finaluv + _ShadowMapTexture_TexelSize.xy * float2(0, 1));
				shadows.w = tex2D (_ShadowMapTexture, finaluv + _ShadowMapTexture_TexelSize.xy);
				shadows = _LightShadowData.rrrr + shadows * (1-_LightShadowData.rrrr);
				myshadow = dot (shadows, 0.25);
			#endif

		//	Spot light shadows
			#if defined (SPOT)
				float4 mycoord = float4 ( mul (unity_World2Shadow[0], IN.myworldPos));
				float3 finalcoord = mycoord.xyz / mycoord.w;
				myshadow = UNITY_SAMPLE_SHADOW(_ShadowMapTexture, finalcoord );
			#endif

		//	Point light shadows
			#if defined (POINT)
				float3 mycoord = IN.myworldPos.xyz - _LightPositionRange.xyz;
				float dist = UnityDecodeCubeShadowDepth (texCUBE (_ShadowMapTexture, mycoord));
				float mydist = length(mycoord) * _LightPositionRange.w;
				mydist *= 0.97; // bias
				myshadow = dist < mydist ? _LightShadowData.r : 1.0;
			#endif

		//	Calc shadow fade
			float sphereDist = distance(IN.myworldPos.xyz, unity_ShadowFadeCenterAndType.xyz);
			half shadowFade = saturate(sphereDist * _LightShadowData.z + _LightShadowData.w);

			o.Attenuation = myshadow + shadowFade;
			o.Alpha = c.a;
			o.AO = IN.color.r;

		}
		ENDCG
	} 
}
