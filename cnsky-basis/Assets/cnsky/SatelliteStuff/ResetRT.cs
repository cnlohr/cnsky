using UnityEngine;
using Basis;

[Cilboxable]
public class ResetRT : MonoBehaviour
{
	public BasisInteractableShim btn;
	public CustomRenderTexture rt;

	public void ClickDelegate()
	{
		rt.Initialize();
	}

    private void Start()
    {
		btn = Basis.SafeUtil.MakeInteractable(this);
		btn.ButtonDown = () => ClickDelegate();
    }
}

