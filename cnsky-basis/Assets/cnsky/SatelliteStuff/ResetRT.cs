using UnityEngine;
using Basis;

[Cilboxable]
public class ResetRT : BasisNetworkBehaviour
{
	public ExampleButtonInteractable btn;
	public CustomRenderTexture rt;

	public void ClickDelegate()
	{
		rt.Initialize();
	}

    public override void Start()
    {
		base.Start();
		btn.ButtonDown += ClickDelegate;
    }
}

