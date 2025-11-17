namespace Hirabiki.Udon.Works
{
    using UdonSharp;
    using UnityEngine;
    using UnityEngine.UI;
    using VRC.SDKBase;
    using VRC.Udon;

    public class UiToggleListener : UdonSharpBehaviour
    {
        [SerializeField] private Toggle toggle;
        public UdonBehaviour target;
        public string variableName;
        public string onDisableEventName;
        public string onEnableEventName;

        void Start()
        {
            if(toggle == null)
            {
                toggle = transform.GetComponent<Toggle>();
            }
        }

        public void UpdateValue()
        {
            if(Networking.LocalPlayer == null || target == null) return;
            target.SetProgramVariable(variableName, toggle.isOn);
        }
        public void UpdateState()
        {
            if(Networking.LocalPlayer == null || target == null) return;
            target.SendCustomEvent(toggle.isOn ? onEnableEventName : onDisableEventName);
        }
    }
}