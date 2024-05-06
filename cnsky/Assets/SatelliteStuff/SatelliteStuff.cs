﻿using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using VRC.SDK3.Image;
using VRC.SDK3.StringLoading;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

[UdonBehaviourSyncMode(BehaviourSyncMode.None)]
public class SatelliteStuff : UdonSharpBehaviour
{
	public VRCUrl stringUrl;	
	private VRCImageDownloader _imageDownloader;
	private IUdonEventReceiver _udonEventReceiver;

	public Texture defaultTexture;
	private new Renderer renderer;
	public CustomRenderTexture crt;
	
	void Start()
	{
		// It's important to store the VRCImageDownloader as a variable, to stop it from being garbage collected!
		_imageDownloader = new VRCImageDownloader();

		Material m = crt.material;
		m.SetTexture( "_ImportTexture", defaultTexture );
		crt.Update();
		
		
		// To receive Image and String loading events, 'this' is casted to the type needed
		_udonEventReceiver = (IUdonEventReceiver)this;
		

		var rgbInfo = new TextureInfo();
		rgbInfo.GenerateMipMaps = false;
		_imageDownloader.DownloadImage( stringUrl, crt.material, _udonEventReceiver, rgbInfo);
		Debug.Log($"Trying download.");
	}
	
	public override void OnImageLoadSuccess(IVRCImageDownload result)
	{
		Debug.Log($"Image loaded: {result.SizeInMemoryBytes} bytes.");
		//Renderer renderer = crt.GetComponent<Renderer>();
		Material m = crt.material;
		m.SetTexture( "_ImportTexture", result.Result );
		crt.Update();
	}
	
	public override void Interact()
	{
		var rgbInfo = new TextureInfo();
		rgbInfo.GenerateMipMaps = false;
		_imageDownloader.DownloadImage( stringUrl, crt.material, _udonEventReceiver, rgbInfo);
		Debug.Log($"Trying download.");
	}

	private void OnDestroy()
	{
		_imageDownloader.Dispose();
		Material m = crt.material;
		m.SetTexture( "_ImportTexture", defaultTexture );
	 }
	
	
	void Awake()
	{
		//Material m = crt.material;
		//m.SetTexture( "_ImportTexture", defaultTexture );
	}
	
}
