namespace Hirabiki.Udon.Works
{
    using UdonSharp;
    using UnityEngine;
    using VRC.SDKBase;
    using VRC.Udon;

    public class PlayerGlobalEffect : UdonSharpBehaviour
    {
        //[Header("Must be first in inspector for ObjectPoolController")]
        //[UdonSynced(UdonSyncMode.None)]
        [System.NonSerialized]
        public int sync_playerID = -1; //-1 == uninitialized | 0 = empty slot

        //[UdonSynced(UdonSyncMode.None)]
        [System.NonSerialized]
        public int sync_debug_playerFps = 0;

        [System.NonSerialized]
        public int debug_objectIndex;

        public TransformToMouth mouth;
        public ParticleSystem bubbles;
        public AudioSource globalAudio;
        public AudioClip[] smallBubbleClips;

        private float fpsCheckTime;
        private bool isExhale;
        /*
        public override void OnOwnershipTransferred()
        {
            debugText.text = string.Format("P:{0} [Transfer] ID:->{1} A:{2}\n", debug_objectIndex,
                Networking.GetOwner(gameObject).playerId, sync_playerID) + debugText.text;
        }
        */
        void Start()
        {
            if(!Utilities.IsValid(Networking.LocalPlayer))
            {
                gameObject.SetActive(false);
            }
        }

        void OnEnable()
        {
            if(isExhale)
            {
                globalAudio.Play();
            } else
            {
                globalAudio.Stop();
            }
        }

        // This is only called by LocalPlayer in SwimSystem, so it SHOULD be safe to use LocalPlayer
        public void SyncMouthTransform()
        {
            // debugText.text = string.Format("P:{0} ID:{1} Mouth follower sync {2}\n", debug_objectIndex, sync_playerID, sync_playerID != -1) + debugText.text;
            // HACK: Sometime somehow the assignment is zero
            if(sync_playerID == 0)
            {
                sync_playerID = Networking.LocalPlayer.playerId;
            }
            mouth.SetPlayerToFollow(Networking.LocalPlayer);
            mouth.gameObject.SetActive(true);
        }

        // All functions below are called with SendCustomNetworkEvent to all - it's global
        // Called by Master in ObjectPoolManager
        public void DisableMouthTransform()
        {
            mouth.SetPlayerToFollow(null);

            SetExhaleFalse(); // Reset
        }

        public void BurstSmall()
        {
            bubbles.Emit(Random.Range(2, 5));
            globalAudio.PlayOneShot(smallBubbleClips[Random.Range(0, smallBubbleClips.Length)]);
        }
        public void BurstLarge()
        {

        }
        public void SetExhaleTrue()
        {
            ParticleSystem.EmissionModule em = bubbles.emission;
            em.enabled = true;
            globalAudio.Play();
            isExhale = true;
        }
        public void SetExhaleFalse()
        {
            ParticleSystem.EmissionModule em = bubbles.emission;
            em.enabled = false;
            globalAudio.Stop();
            isExhale = false;
        }
        public void MuteAllSounds()
        {
            globalAudio.mute = true;
        }
        public void UnmuteAllSounds()
        {
            globalAudio.mute = false;
        }
    }
}