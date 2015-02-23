using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif
using System.Collections;

[ExecuteInEditMode]
[AddComponentMenu("Lux/Setup Lux 2.0")]
public class SetupLux_2_0 : MonoBehaviour {

	// WIND
	public Vector3 Lux_WindDirection;
	[Range(0.0f,1.0f)]
	public float Lux_WindStrength = 0.5f;

	// SUN
	public GameObject LuxSun;

	// WETNESS
	public Vector4 Lux_WaterFloodlevel = new Vector4(0.0f, 0.0f, 0.0f, 0.0f);
	[Range(0.0f,1.0f)]
	public float Lux_RainIntensity = 0.0f;
	public Texture2D Lux_RainRipples;
	public Vector2 Lux_RippleWindSpeed = new Vector2(0.5f, 0.25f);
	public float Lux_RippleTiling = 4.0f;
	public float Lux_RippleAnimSpeed = 1.0f;
	public float Lux_WaterBumpDistance = 20.0f;

	// SNOW
	public Texture2D Lux_SnowAlbedoSmoothnessTex;
	public Texture2D Lux_SnowNormalTex;
	public GameObject Lux_SnowGIMasterGameobject;
	private Renderer Lux_SnowGIMasterRenderer;
	[Range(-100.0f,8000.0f)]
	public float Lux_SnowStartHeight = -100.0f;
	[Range(0.0f,1.0f)]
	public float Lux_SnowHeightBlending = 0.01f;
	[Range(0.0f,1.0f)]
	public float Lux_SnowAmount = 0.0f;
	private float Lux_adjustedSnowAmount;
	[Range(0.0f,1.0f)]
	public float Lux_SnowMicroErosion = 0.0f;
	[Range(0.0f,1.0f)]
	public float Lux_SnowWindErosion = 0.0f;
	[Range(0.0f,0.99f)]
	public float Lux_SnowMelt = 0.0f;
	[Range(0.0f,1.0f)]
	public float Lux_SnowIcyness = 0.5f;
	public Color Lux_SnowSubColor;

	void Awake () {
		checkDeferred();
	}
	
	void Update () {
		#if UNITY_EDITOR
			checkDeferred();
		#endif
		UpdateLuxWindSettings();
		UpdateLuxRainSettings();
		UpdateLuxSnowSettings();
		UpdateLuxSunSettings();
	}


//	//////////////////////////////////////

	void checkDeferred() {
		if (Camera.main.renderingPath == RenderingPath.DeferredShading) {
				Shader.EnableKeyword("_LUX_DEFERRED");
		}
		else {
			Shader.DisableKeyword("_LUX_DEFERRED");	
		}	
	}

	void UpdateLuxWindSettings () {
		Lux_WindDirection = transform.up;
		Shader.SetGlobalVector("_Lux_Wind", new Vector4(Lux_WindDirection.x, Lux_WindDirection.y, Lux_WindDirection.z , Lux_WindStrength));
	}

	void UpdateLuxRainSettings () {
		Shader.SetGlobalVector("_Lux_WaterFloodlevel", Lux_WaterFloodlevel);
		Shader.SetGlobalFloat("_Lux_RainIntensity", Lux_RainIntensity);
		if(Lux_RainRipples) {
			Shader.SetGlobalTexture("_Lux_RainRipples", Lux_RainRipples);
		}
		Shader.SetGlobalVector("_Lux_RippleWindSpeed", new Vector4(Lux_WindDirection.x * Lux_RippleWindSpeed.x, Lux_WindDirection.z * Lux_RippleWindSpeed.x, Lux_WindDirection.x * Lux_RippleWindSpeed.y, Lux_WindDirection.z * Lux_RippleWindSpeed.y));
		Shader.SetGlobalFloat("_Lux_RippleTiling", Lux_RippleTiling);
		Shader.SetGlobalFloat("_Lux_RippleAnimSpeed", Lux_RippleAnimSpeed);	
		Shader.SetGlobalFloat("_Lux_WaterBumpDistance", Lux_WaterBumpDistance);	
	}

	void UpdateLuxSnowSettings () {

		// Dynamic Snow Accumulation will influence the Albedo of the effected surfaces thus it should also update GI
		if (Lux_SnowGIMasterRenderer != null && Lux_SnowGIMasterGameobject != null) {
			DynamicGI.UpdateMaterials(Lux_SnowGIMasterRenderer);	
		}
		else if (Lux_SnowGIMasterGameobject != null) {
			Lux_SnowGIMasterRenderer = Lux_SnowGIMasterGameobject.GetComponent<Renderer>();
			if (Lux_SnowGIMasterRenderer != null) {
				DynamicGI.UpdateMaterials(Lux_SnowGIMasterRenderer);
			}
		}
		else {
			Lux_SnowGIMasterRenderer = null;	
		}
		Shader.SetGlobalTexture("_Lux_SnowAlbedo", Lux_SnowAlbedoSmoothnessTex);
		Shader.SetGlobalTexture("_Lux_SnowNormal", Lux_SnowNormalTex);
		Shader.SetGlobalVector("_Lux_SnowHeightParams", new Vector4(Lux_SnowStartHeight, Lux_SnowHeightBlending * 1000.0f, 0.0f, 0.0f));
		Shader.SetGlobalVector("_Lux_SnowWindErosion", new Vector4(Lux_SnowWindErosion, Lux_SnowMicroErosion, 0.0f, 0.0f));
		// WIP: We have to tweak Lux_SnowAmount according to Lux_SnowWindErosion
		Lux_adjustedSnowAmount = Mathf.Lerp(Lux_SnowAmount, Mathf.Clamp(Lux_SnowAmount * 1.1f, 0, 1), Lux_SnowWindErosion);
		Lux_adjustedSnowAmount = Mathf.Lerp(Lux_adjustedSnowAmount, Lux_adjustedSnowAmount * 0.9f, Lux_SnowMicroErosion);
		// TODO: Melting * Winderosion should effect SnowAmount 
		Lux_adjustedSnowAmount -= Lux_adjustedSnowAmount * Lux_SnowMelt;
		Shader.SetGlobalFloat("_Lux_SnowAmount", Lux_adjustedSnowAmount);
		Shader.SetGlobalVector("_Lux_SnowMelt", new Vector4 (
			Lux_SnowMelt * Lux_SnowAmount,										// final Lux_SnowMelt
			1.0f - Mathf.Pow(2.0f, -10.0f * Lux_SnowMelt * Lux_SnowAmount ),	// final Lux_SnowMelt = 2^(-10 * (Lux_SnowMelt))
			0,
			0));
		Shader.SetGlobalFloat("_Lux_SnowIcyness", Lux_SnowIcyness);
		Shader.SetGlobalVector("_Lux_SnowSubColor", Lux_SnowSubColor);
	}

	void UpdateLuxSunSettings () {
		if (LuxSun != null ) {
			Shader.SetGlobalVector("_Lux_SunDir", -LuxSun.transform.forward);
			Light lt = LuxSun.GetComponent<Light>();
			Vector3 lightcol = new Vector3 (lt.color.r, lt.color.g, lt.color.b) * lt.intensity;
	        Shader.SetGlobalVector("_Lux_SunColor", lightcol);
		}
	}

//	////////////////////////////////

	#if UNITY_EDITOR
	void OnDrawGizmosSelected()
    {
    //	Draw Wind Direction Handle
    	float hsize = HandleUtility.GetHandleSize(transform.position);
    	Handles.color = Color.green;
    	Quaternion rotation = Quaternion.LookRotation(transform.up * (-1.0f));
    	Handles.ArrowCap(0, transform.position, rotation, hsize * 1.5f);
    }
    #endif
}
