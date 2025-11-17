
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class ResetRT : UdonSharpBehaviour
{
	public CustomRenderTexture rt;
	public override void Interact()
	{
		rt.Initialize();
	}
    void Start()
    {
        
    }
}
