namespace Hirabiki.Udon.Works
{
    using UdonSharp;
    using UnityEngine;
    using UnityEngine.UI;
    using VRC.SDKBase;
    using VRC.Udon;

    public class TransformToMouth : UdonSharpBehaviour
    {
        public Transform rootTransform;
        private VRCPlayerApi assigned;
        private int assignedID;
        private int yourPlayerID;
        private float ownerCheckDelay;

        [SerializeField] private bool localOnly;

        void Start()
        {
            //Editor check
            yourPlayerID = Utilities.IsValid(Networking.LocalPlayer) ? Networking.LocalPlayer.playerId : -1;
            gameObject.SetActive(false); // Only enable when using SetPlayerToFollow
        }

        void Update()
        {
            // Only executes when SetPlayerToFollow gets called for the first time
            // Which is normally when player goes underwater
            if(assigned != null && (localOnly || assignedID == yourPlayerID))
            {

                if(!localOnly && Time.time > ownerCheckDelay)
                {
                    // If somehow ownership is lost even with properly assigned player, try to regain it
                    // Lost ownership affects position syncing only
                    if(!Networking.IsOwner(gameObject))
                    {
                        Networking.SetOwner(Networking.LocalPlayer, gameObject);
                    }
                    ownerCheckDelay = Time.time + 0.5f;
                }

                VRCPlayerApi.TrackingData eyeTransform = assigned.GetTrackingData(VRCPlayerApi.TrackingDataType.Head);
                bool isGenericRig = assigned.GetBonePosition(HumanBodyBones.Spine).Equals(Vector3.zero);

                Vector3 headPos = isGenericRig
                    ? Vector3.Lerp(assigned.GetPosition(), eyeTransform.position, 0.9f)
                    : assigned.GetBonePosition(HumanBodyBones.Head);

                float headBoneToEyeLength = (eyeTransform.position - headPos).magnitude;
                Vector3 eyeBonesPos = Vector3.Lerp(assigned.GetBonePosition(HumanBodyBones.LeftEye), assigned.GetBonePosition(HumanBodyBones.RightEye), 0.5f);
                Vector3 eyePos = eyeBonesPos == Vector3.zero || (headPos - eyeBonesPos).magnitude < 0.001f ? eyeTransform.position : eyeBonesPos;

                Vector3 mouthPos;
                if((headPos - eyePos).magnitude < 0.001f) // Head is scaled down
                {
                    mouthPos = Vector3.Lerp(eyeTransform.position, headPos, 0.5f) +
                        (eyeTransform.rotation * Vector3.forward * headBoneToEyeLength * 0.5f);
                } else
                {
                    mouthPos = Vector3.Lerp(eyePos, headPos, 0.5f);
                }

                rootTransform.SetPositionAndRotation(mouthPos, assigned.GetBoneRotation(HumanBodyBones.Head));
            } else
            {
                // Stop having all other scripts in object pool loop in Update()
                // HACK: Udon does not support disabling/enabling its scripts
                gameObject.SetActive(false);
            }
        }

        //This gets called by local from PlayerGlobalEffect with LocalPlayer as param, and master with null as param
        public void SetPlayerToFollow(VRCPlayerApi player)
        {
            assigned = player;

            assignedID = player != null ? player.playerId : 0;
            gameObject.SetActive(player != null);
        }
    }
}