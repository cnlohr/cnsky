namespace Hirabiki.Udon.Works
{
    using UdonSharp;
    using UnityEngine;
    using UnityEngine.UI;
    using VRC.SDKBase;
    using VRC.Udon;

    public class PlayerLocalEffect : UdonSharpBehaviour
    {
        /// <summary>
        /// Local audiovisual effects - do not use synced effects here
        /// </summary>
        [Tooltip("Script updates every this many frames")]
        [SerializeField] private int updateInterval = 2;
        private int updateDelay = 2;

        [Header("References")]
        public SwimSystem swimSystem;
        public Animator airBarAnimator;
        public RectTransform airBarFill;
        public Renderer vignetteEffect;

        [Header("Oxygen HUD settings")]
        [Tooltip("Always show HUD when underwater?")]
        public bool alwaysShowHud = false;

        [Tooltip("Show HUD when surfacing from water when air drops to this %")]
        public float showHudThreshold = 80f;

        [Tooltip("Show HUD and alert the player when air drops to this %")]
        public float alertHudThreshold = 20f;

        [Header("Sound settings")]
        [Tooltip("Sounds to low pass when underwater\nThis is optional")]
        public AudioLowPassFilter[] sourcesToLowPass;

        [Tooltip("Music AudioSource to fade when underwater\nThis is optional")]
        public AudioSource worldMusic;

        [Tooltip("Heatbeat AudioSource when low on air")]
        public AudioSource dokiSound;

        [Tooltip("AudioSource for sound effects")]
        public AudioSource oneShotSounds;

        [Tooltip("Sound to play on death")]
        public AudioClip deathSoundClip;

        [Tooltip("Alert sound when low on air\nPlays every 2 seconds")]
        public AudioClip lowAirAlertClip;

        private bool willShowAirBar;
        private bool alertLowAir;
        private bool playDoki;
        private float alertLowAirDelay;
        private Vector3 originalUnityGravity;
        private float originalMusicVolume;

        void Start()
        {
            originalUnityGravity = Physics.gravity;
            if(worldMusic != null)
            {
                originalMusicVolume = worldMusic.volume;
            }
        }

        void OnEnable()
        {
            if(playDoki)
            {
                dokiSound.Play();
            } else
            {
                dokiSound.Stop();
            }
        }

        void Update()
        {
            if(--updateDelay > 0) return;
            updateDelay = updateInterval;

            bool nowDefeated = swimSystem.CombatHPRatio() == 0.0f;

            alertLowAir = swimSystem.IkiRatio() < alertHudThreshold / 100f;
            if(swimSystem.IkiRatio() < showHudThreshold / 100f)
            {
                willShowAirBar = true;
            } else if(swimSystem.IkiRatio() == 1f)
            {
                willShowAirBar = false;
            }
            airBarAnimator.SetBool("DoAppear", (!swimSystem.IsUnderwater() && willShowAirBar)
                || alertLowAir || (swimSystem.IsUnderwater() && alwaysShowHud));

            airBarFill.sizeDelta = new Vector2(swimSystem.IkiRatio() * 100f, 0f);

            foreach(AudioLowPassFilter lpf in sourcesToLowPass)
            {
                if(lpf != null) lpf.enabled = swimSystem.IsUnderwater();
            }

            if(alertLowAir && Time.time > alertLowAirDelay)
            {
                oneShotSounds.PlayOneShot(lowAirAlertClip);
                alertLowAirDelay = Time.time + 2f;
            }

            if(worldMusic != null)
            {
                worldMusic.volume = originalMusicVolume * Mathf.Lerp(0f, 1f, swimSystem.IkiRatio());
            }

            if(swimSystem.IkiRatio() < 0.5f)
            {
                if(!playDoki)
                {
                    playDoki = true;
                    dokiSound.Play();
                }
                dokiSound.volume = Mathf.Sqrt(swimSystem.CombatHPRatio()) * Mathf.Pow(Mathf.Clamp01(1f - swimSystem.IkiRatio() * 2f), 2f);
                dokiSound.pitch = Mathf.Lerp(0.3f, Mathf.Lerp(1.5f, 1.0f, swimSystem.IkiRatio()), swimSystem.CombatHPRatio());
            } else
            {
                if(playDoki)
                {
                    playDoki = false;
                    dokiSound.Stop();
                }
            }

            float vigSize = swimSystem.CombatHPRatio() == 0.0f ? 1.0f
                : Mathf.Lerp(Mathf.Lerp(Mathf.Lerp(0.1f, 0.7f, swimSystem.CombatHPRatio()), 1.0f, swimSystem.KuukiRatio()), 5.0f, swimSystem.IkiRatio());
            vignetteEffect.sharedMaterial.SetFloat("_Size", vigSize);
            vignetteEffect.enabled = swimSystem.IkiRatio() < 1.0f;
        }
    }
}