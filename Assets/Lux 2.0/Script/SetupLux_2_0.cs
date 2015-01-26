using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif
using System.Collections;

[ExecuteInEditMode]
[AddComponentMenu("Lux/Setup Lux 2.0")]
public class SetupLux_2_0 : MonoBehaviour {

	// WETNESS
	public Vector4 Lux_WaterFloodlevel = new Vector4(0.0f, 0.0f, 0.0f, 0.0f);
	[Range(0.0f,1.0f)]
	public float Lux_RainIntensity = 0.0f;
	public Texture2D Lux_RainRipples;
	public Vector4 Lux_RippleWindSpeed = new Vector4(0.1f, 0.08f, 0.12f, 0.1f);
	public float Lux_RippleTiling = 4.0f;
	public float Lux_RippleAnimSpeed = 1.0f;
	public float Lux_WaterBumpDistance = 20.0f;

	void Awake () {
		checkDeferred();
	}
	
	void Update () {
		#if UNITY_EDITOR
			checkDeferred();
		#endif

		UpdateLuxRainSettings();
	}

	void checkDeferred() {
		if (Camera.main.renderingPath == RenderingPath.DeferredShading) {
				Shader.EnableKeyword("_LUX_DEFERRED");
		}
		else {
			Shader.DisableKeyword("_LUX_DEFERRED");	
		}	
	}

	void UpdateLuxRainSettings () {
		Shader.SetGlobalVector("_Lux_WaterFloodlevel", Lux_WaterFloodlevel);
		Shader.SetGlobalFloat("_Lux_RainIntensity", Lux_RainIntensity);
		if(Lux_RainRipples) {
			Shader.SetGlobalTexture("_Lux_RainRipples", Lux_RainRipples);
		}

		Shader.SetGlobalVector("_Lux_RippleWindSpeed", Lux_RippleWindSpeed);
		Shader.SetGlobalFloat("_Lux_RippleTiling", Lux_RippleTiling);
		Shader.SetGlobalFloat("_Lux_RippleAnimSpeed", Lux_RippleAnimSpeed);	
		Shader.SetGlobalFloat("_Lux_WaterBumpDistance", Lux_WaterBumpDistance);	

	}
}
