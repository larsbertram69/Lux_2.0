Shader "Lux/Human/Eye AO" {
	Properties {
		_Color ("Diffuse Color", Color) = (1,1,1,1)
		_MainTex ("Base (RGB) Alpha (A)", 2D) = "white" {}	
	}

	SubShader {
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
		LOD 200
		Offset -1,-1
		
		CGPROGRAM
		#pragma surface surf Lambert noambient alpha decal:blend
		#pragma shader_feature _LUX_DEFERRED

	//	Prevent shader from rendering fog (needed when used with deferred rendering and global fog)
		#ifdef _LUX_DEFERRED
			#undef UNITY_APPLY_FOG
			#define UNITY_APPLY_FOG(coord,col) /**/
		#endif

		fixed4 _Color;
		sampler2D _MainTex;

		struct Input {
			float2 uv_MainTex;
		};

		void surf (Input IN, inout SurfaceOutput o) {
			fixed4 c = tex2D(_MainTex, IN.uv_MainTex);
			c *= _Color;
			o.Albedo = c.rgb;
			o.Alpha = c.a;

		}
		ENDCG
	} 
	Fallback "Transparent/VertexLit"
}
