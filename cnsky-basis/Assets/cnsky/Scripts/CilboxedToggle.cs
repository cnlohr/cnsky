using UnityEngine;
using Cilbox;
using Basis;

[Cilboxable]
public class CilboxedToggle : MonoBehaviour
{
	public ExampleButtonInteractable btn;
	public GameObject objToToggle;
	public GameObject[] objsToToggleOff;
	public Renderer[] renderersToToggle;
	public Renderer[] renderersToToggleOff;
	public bool isActive;

	public void ClickDelegate()
	{
		isActive = !isActive;
		if( objToToggle ) objToToggle.SetActive( isActive );
		foreach( var o in objsToToggleOff )
			o.SetActive( false );

		foreach( var r in renderersToToggle )
			r.enabled = isActive;
		foreach( var r in renderersToToggleOff )
			r.enabled = false;
	}

    void Start()
    {
		btn.ButtonDown = () => ClickDelegate();

		foreach( var o in objsToToggleOff )
			o.SetActive( false );
		if( objToToggle ) objToToggle.SetActive( isActive );

		foreach( var r in renderersToToggleOff )
			r.enabled = false;
		foreach( var r in renderersToToggle )
			r.enabled = isActive;
    }
}

