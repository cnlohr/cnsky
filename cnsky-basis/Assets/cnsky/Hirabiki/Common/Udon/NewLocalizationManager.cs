namespace Hirabiki.Udon.Works
{
    using UdonSharp;
    using UnityEngine;
    using UnityEngine.UI;

    public class NewLocalizationManager : UdonSharpBehaviour
    {
        [Tooltip("List of localization languages")]
        [SerializeField] private TextAsset[] langList;
        [Tooltip("Default language index\n0 = 1st\n1 = 2nd\n...")]
        [SerializeField] private int selectedLangIndex = 0;
        [SerializeField] private Text[] textList;
        private TextAsset activeLang;

        void Start()
        {
            UpdateAllText();
        }

        public void ChangeLangTo0()
        {
            UpdateAllText(0);
        }
        public void ChangeLangTo1()
        {
            UpdateAllText(1);
        }
        public void ChangeLangTo2()
        {
            UpdateAllText(2);
        }
        public void ChangeLangTo3()
        {
            UpdateAllText(3);
        }
        public void ChangeLangToSelected()
        {
            UpdateAllText();
        }

        private void UpdateAllText()
        {
            UpdateAllText(selectedLangIndex);
        }
        private void UpdateAllText(int langIndex)
        {
            selectedLangIndex = Mathf.Clamp(langIndex, 0, langList.Length - 1);

            TextAsset langInput = langList[langIndex];
            if(langInput == null || langInput == activeLang) return;
            activeLang = langInput;

            string[] langParsed = langInput.text.Split('\n');

            for(int i = 0; i < textList.Length; i++)
            {
                if(textList[i] == null) continue;

                string[] langToken = langParsed[i].Split('\t');
                if(!textList[i].name.EndsWith(langToken[0], System.StringComparison.OrdinalIgnoreCase))
                {
                    // If it don't align with name at index, search the whole localization text lines for it
                    foreach(string langLine in langParsed)
                    {
                        langToken = langLine.Split('\t');
                        if(textList[i].name.EndsWith(langToken[0], System.StringComparison.OrdinalIgnoreCase))
                        {
                            break; // Found it! now stop searching
                        }
                    }
                }

                if(langToken.Length > 1 && langToken[1].Contains("\\n"))
                {
                    textList[i].text = langToken[1].Replace("\\n", "\n");
                } else
                {
                    textList[i].text = langToken[1];
                }

            }
        }
    }
}