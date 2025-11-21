using UnityEngine;
using Basis;

[Cilboxable]
public class ResetRT : MonoBehaviour
{
	public ExampleButtonInteractable btn;
	public CustomRenderTexture rt;

	public void ClickDelegate()
	{
		rt.Initialize();
	}

    private void Start()
    {
		//base.Start();
		//btn.ButtonDown += ClickDelegate;
		btn.ButtonDown = () => ClickDelegate();
    }
}

