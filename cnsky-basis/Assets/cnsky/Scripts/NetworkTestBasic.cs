using UnityEngine;
using Basis;
using Cilbox;
using Basis.Scripts.Networking.NetworkedAvatar;
using Basis.Network.Core;

[Cilboxable]
public class NetworkTestBasic : MonoBehaviour
{
	public UnityEngine.UI.Text status;
	public UnityEngine.UI.Button button;

	private BasisInteractableShim btn;
	private BasisNetworkShim net;

	public int ticker;

	public int MyInt {set; get;}

    void Start()
    {
		net = Basis.SafeUtil.MakeNetworkable(this);

		net.NetworkReady             = () => NetworkReady();
		net.ServerOwnershipDestroyedE= () => ServerOwnershipDestroyed();
		net.OwnershipTransfer        = (BasisNetworkPlayer NewOwner) => OwnershipTransfer( NewOwner );
		net.NetworkMessageReceived   = (ushort PlayerID, byte[] buffer, DeliveryMethod DeliveryMethod) => { NetworkMessageReceived( PlayerID, buffer, DeliveryMethod ); };
		net.PlayerLeft               = (BasisNetworkPlayer p) => { PlayerLeft( p ); };
		net.PlayerJoined             = (BasisNetworkPlayer p) => { PlayerJoined( p ); };

		btn = Basis.SafeUtil.MakeInteractable(this);
		btn.ButtonDown = () => ClickSelfDelegate();

		button.onClick.AddListener( () => ClickDelegate() );

		ticker = 1;
    }

	void ClickSelfDelegate()
	{
		Debug.Log( "ClickSelfDelegate()" );

		byte[] buf = new byte[5];
		net.SendCustomNetworkEvent(buf, DeliveryMethod.Unreliable, null);
	}

	void ClickDelegate()
	{
		Debug.Log( "ClickDelegate()" );

		byte[] buf = new byte[5];
		net.SendCustomNetworkEvent(buf, DeliveryMethod.Unreliable, null);
	}

	void NetworkReady()
	{
		Debug.Log( $"NT: NetworkReady" );
	}

	void ServerOwnershipDestroyed()
	{
		Debug.Log( $"NT: ServerOwnershipDestroyed" );
	}

	void OwnershipTransfer(BasisNetworkPlayer NewOwner)
	{
		Debug.Log( $"NT: OwnershipTransfer ({NewOwner})" );
	}

	void NetworkMessageReceived(ushort PlayerID, byte[] buffer, DeliveryMethod DeliveryMethod)
	{
		ticker++;
		Debug.Log( $"NT: NetworkMessageReceived ({PlayerID},{buffer.Length},{DeliveryMethod})" ); 
	}

	void PlayerLeft( BasisNetworkPlayer p )
	{
		Debug.Log( $"NT: PlayerLeft({p})" );
	}

	void PlayerJoined( BasisNetworkPlayer p )
	{
		Debug.Log( $"NT: PlayerJoined({p})" );
	}

    void Update()
    {
       status.text = $"{CilboxPublicUtils.GetProxyBuildTimeGuid( this ).ToString()}\n{CilboxPublicUtils.GetProxyInitialPath( this ).ToString()}\n{ticker.ToString()}";
    }
}


