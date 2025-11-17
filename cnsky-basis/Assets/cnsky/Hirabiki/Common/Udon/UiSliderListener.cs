namespace Hirabiki.Udon.Works
{
    using UdonSharp;
    using UnityEngine;
    using UnityEngine.UI;
    using VRC.SDKBase;
    using VRC.Udon;

    public class UiSliderListener : UdonSharpBehaviour
    {
        private Slider slider;
        private Text valueText;
        public string stringFormat = "";
        public UdonBehaviour target;
        public string variableName;

        private bool hasInit;

        void Start()
        {
            InitReferences();

            if(target != null)
            {
                float readValue = (float)target.GetProgramVariable(variableName);

                slider.minValue = readValue < slider.minValue ? readValue : slider.minValue;
                slider.maxValue = readValue > slider.maxValue ? readValue : slider.maxValue;

                slider.value = readValue;
            }
            UpdateValue();
        }

        private void InitReferences()
        {
            if(hasInit) return;
            slider = transform.GetComponent<Slider>();
            Transform tryFind = transform.Find("[ValueText]");
            if(tryFind != null)
            {
                valueText = tryFind.GetComponent<Text>();
            }
            hasInit = true;
        }

        // This can get called before Start() with gameobject initially disabled
        public void UpdateValue()
        {
            InitReferences();

            if(valueText != null)
            {
                valueText.text = slider.value.ToString(stringFormat);
            }
            if(target != null)
            {
                target.SetProgramVariable(variableName, slider.value);
            }
        }
    }
}