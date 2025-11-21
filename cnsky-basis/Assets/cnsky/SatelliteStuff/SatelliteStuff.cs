using UnityEngine;
using UnityEngine.UI;
using Basis;
using System;

[Cilboxable]
public class SatelliteStuff : MonoBehaviour
{
	public BasisUrl stringUrl;	
	private BasisImageDownloader _imageDownloader;

	public ExampleButtonInteractable btn;

	public Texture defaultTexture;
	private new Renderer renderer;
	public CustomRenderTexture crt;
	
	public bool doInitial;

	void Start()
	{
		//base.Start();
		btn.ButtonDown = () => ClickDelegate();

		// It's important to store the VRCImageDownloader as a variable, to stop it from being garbage collected!
		_imageDownloader = new BasisImageDownloader();

		//var rgbInfo = new TextureInfo();
		//rgbInfo.GenerateMipMaps = false;
		
		// Only one should be initial.
		if( doInitial )
		{
			Material m = crt.material;
			m.SetTexture( "_ImportTexture", defaultTexture );
			crt.Update();
			_imageDownloader.DownloadImage( stringUrl, ImageLoadSuccessDelegate);
			Debug.Log($"Trying download.");
		}
	}
	
	public void ImageLoadSuccessDelegate(IBasisImageDownload result)
	{
		Debug.Log($"Image loaded: {result.SizeInMemoryBytes} bytes.");
		//Renderer renderer = crt.GetComponent<Renderer>();
		Material m = crt.material;
		m.SetTexture( "_ImportTexture", result.Result );
		crt.Update();
	}
	
	public void ClickDelegate()
	{
		_imageDownloader.DownloadImage( stringUrl, ImageLoadSuccessDelegate );
		Debug.Log($"Trying download.");
	}

	void OnDestroy()
	{
		if( _imageDownloader != null )
			_imageDownloader.Dispose();

		Material m = crt.material;
		m.SetTexture( "_ImportTexture", defaultTexture );
		//base.OnDestroy();
	 }
	
	
	void Awake()
	{
		//Material m = crt.material;
		//m.SetTexture( "_ImportTexture", defaultTexture );
	}
	
}
