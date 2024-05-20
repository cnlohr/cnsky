namespace Hirabiki.Udon.Works
{
    using UdonSharp;
    using UnityEngine;
    using UnityEngine.UI;

    public class LocalizationManager : UdonSharpBehaviour
    {
        [Tooltip("English localization")]
        [SerializeField] private TextAsset langEN;
        [Tooltip("Japanese localization")]
        [SerializeField] private TextAsset langJP;
        [Tooltip("Thai localization")]
        [SerializeField] private TextAsset langTH;
        [Tooltip("Korean localization")]
        [SerializeField] private TextAsset langKR;
        [Tooltip("Default language\n0 = English\n1 = Japanese\n2 = Thai\n3 = Korean")]
        [SerializeField] private int selectedLangIndex = 1;
        [SerializeField] private Text[] textList;
        [Tooltip(@"Custom Thai font for better rendering
Font file is not included to respect licensing
Intended font to use: EkkamaiStandard-Light

Download Link: https://www.f0nt.com/release/ekkamai-standard/")]
        [SerializeField] private Font thaiFont;
        private Font defaultFont;

        void Start()
        {
            defaultFont = textList[0].font;
            switch(selectedLangIndex)
            {
                case 0: UpdateAllText(langEN); break;
                case 1: UpdateAllText(langJP); break;
                case 2: UpdateAllText(langTH); break;
                case 3: UpdateAllText(langKR); break;
            }
        }

        public void ChangeLangEN()
        {
            if(selectedLangIndex != 0)
            {
                selectedLangIndex = 0;
                UpdateAllText(langEN);
            }
        }
        public void ChangeLangJP()
        {
            if(selectedLangIndex != 1)
            {
                selectedLangIndex = 1;
                UpdateAllText(langJP);
            }
        }
        public void ChangeLangTH()
        {
            if(selectedLangIndex != 2)
            {
                selectedLangIndex = 2;
                UpdateAllText(langTH);
            }
        }
        public void ChangeLangKR()
        {
            if(selectedLangIndex != 3)
            {
                selectedLangIndex = 3;
                UpdateAllText(langKR);
            }
        }

        private void UpdateAllText(TextAsset langInput)
        {
            string[] textParsed = langInput.text.Split('\n');

            for(int i = 0; i < textList.Length; i++)
            {
                if(textList[i] == null) continue;

                // Thai character rendering is bad with default font
                if(selectedLangIndex == 2 && thaiFont != null)
                {
                    textList[i].font = thaiFont;
                } else if(textList[i].font != defaultFont)
                {
                    textList[i].font = defaultFont;
                }

                if(textParsed[i].Contains("\\n"))
                {
                    textList[i].text = textParsed[i].Replace("\\n", "\n");
                } else if(textParsed[i] != "")
                {
                    textList[i].text = textParsed[i];
                }
            }
        }
    }
}