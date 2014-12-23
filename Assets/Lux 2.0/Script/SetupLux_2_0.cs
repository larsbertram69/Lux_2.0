using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif
using System.Collections;

[ExecuteInEditMode]
[AddComponentMenu("Lux/Setup Lux 2.0")]
public class SetupLux_2_0 : MonoBehaviour {

	void Awake () {
		checkDeferred();
	}
	
	void Update () {
		#if UNITY_EDITOR
			checkDeferred();
		#endif
	}

	void checkDeferred() {
		if (Camera.main.renderingPath == RenderingPath.DeferredShading) {
				Shader.EnableKeyword("_LUX_DEFERRED");
		}
		else {
			Shader.DisableKeyword("_LUX_DEFERRED");	
		}	
	}
}
