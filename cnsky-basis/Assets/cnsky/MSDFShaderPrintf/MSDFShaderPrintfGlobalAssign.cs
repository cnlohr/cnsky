using UnityEngine;
using Cilbox;

[Cilboxable]
public class MSDFShaderPrintfGlobalAssign : MonoBehaviour
{
	public Texture MSDFAssignTexture;

	void Start()
	{
		int id = Shader.PropertyToID("_UdonMSDFPrintf"); 
		Shader.SetGlobalTexture( id, MSDFAssignTexture );
	}
}


