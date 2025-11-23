using UnityEngine;
using Cilbox;
using Basis;

[Cilboxable]
public class CilboxedToggle : MonoBehaviour
{
	public GameObject objToToggle;
	public GameObject[] objsToToggleOff;
	public Renderer[] renderersToToggle;
	public Renderer[] renderersToToggleOff;
	public bool isActive;

	private BasisInteractableShim btn;

	public void ClickDelegate()
	{
		isActive = !isActive;
		foreach( var o in objsToToggleOff )
			o.SetActive( false );
		if( objToToggle != null ) objToToggle.SetActive( isActive );

		foreach( var r in renderersToToggleOff )
			r.enabled = false;
		foreach( var r in renderersToToggle )
			r.enabled = isActive;
	}

    void Start()
    {
		btn = Basis.SafeUtil.MakeInteractable(this);

		btn.ButtonDown = () => ClickDelegate();

		// If not active, then, assume we aren't in control.
		if( isActive )
		{
			foreach( var o in objsToToggleOff )
				o.SetActive( false );
			if( objToToggle != null ) objToToggle.SetActive( isActive );

			foreach( var r in renderersToToggleOff )
				r.enabled = false;
			foreach( var r in renderersToToggle )
				r.enabled = isActive;
		}
    }
}

