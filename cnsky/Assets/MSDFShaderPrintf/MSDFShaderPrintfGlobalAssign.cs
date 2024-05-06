using UnityEngine;
using UdonSharp;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;
using VRC.Udon;
using static VRC.SDKBase.VRCShader;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class MSDFShaderPrintfGlobalAssign : UdonSharpBehaviour
{
#if UDONSHARP
	public Texture MSDFAssignTexture;

	void Start()
	{
		int id = VRCShader.PropertyToID("_UdonMSDFPrintf"); 
		VRCShader.SetGlobalTexture( id, MSDFAssignTexture );
	}
#endif
}
