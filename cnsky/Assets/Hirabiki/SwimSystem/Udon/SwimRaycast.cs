namespace Hirabiki.Udon.Works
{
    using UdonSharp;
    using UnityEngine;
    using VRC.SDKBase;
    using VRC.Udon;

    public class SwimRaycast : UdonSharpBehaviour
    {
        /// <summary>
        /// Water body detection and external physics (depth detection)
        /// </summary>
        [Tooltip("Script updates every this many frames")]
        [SerializeField] private int updateInterval = 3;
        private int updateDelay = 2;

        [Tooltip("Enable or disable swimming?")]
        public bool swimmingEnabled = true;

        //[Header("Settings")]
        //[Tooltip("[DEPRECATED: Always enable]\nShould avatar automatically tread water when not facing down?")]
        [System.NonSerialized] public bool autoTreadWater = true;

        [Header("Raycast collision layer settings")]
        [Tooltip("Layer for the SwimSystem's water")]
        [SerializeField] private int waterLayer = 5;
        [Header("Trigger-based water volume list")]
        [Tooltip("Specify colliders that are meant to represent bodies of water (Cannot overlap)")]
        [SerializeField] private Collider[] waterTriggerList;

        [Header("Underwater Post Processing")]
        [Tooltip(@"Post Processing when underwater (optional)
Leave blank for non-global Post Process Volume or if you have your own solution to underwater Post Process")]
        public GameObject postProcessTarget;
		
		public GameObject Floor;

        //private VRCPlayerApi you;
        [System.NonSerialized] public Vector3 surfacePos = new Vector3(0f, -65536f, 0f);

        void OnDisable()
        {
            surfacePos.y = -65536f;
        }

        void Update()
        {
            VRCPlayerApi you = Networking.LocalPlayer;
			Floor.SetActive( !swimmingEnabled );
            if(you == null) return;
            // Every tick
            if(--updateDelay > 0) return;
            // Every nth ticks
            updateDelay = updateInterval;
            surfacePos.y = -65536f;


            if(!swimmingEnabled) return;

            // push the check a bit above the floor - player is 0.005 below collider
            Vector3 playerPos = you.GetPosition() + Vector3.up * 0.01f;

            // ---- RAYCAST BASED CHECK ---- //
            // If water surface layer hit, that's where the surface of water is (it is the top of water volume)
            // If water bottom  layer hit, discard it and move on (it is the bottom of water volume)
            RaycastHit nearestHit = new RaycastHit();
            bool isRayHitTrigger = false;

            RaycastHit[] rayHits = Physics.RaycastAll(playerPos, Vector3.up, 65536f, 1 << waterLayer, QueryTriggerInteraction.Collide);
            float minDist = 65536f;
            for(int i = 0; i < rayHits.Length; i++)
            {
                // the hits don't have set order - find the nearest one

                Transform t = rayHits[i].transform;
                // Guard against null out of VRChat system objects (Player, PlayerLocal, reserved2)
                if(t != null && t.name.StartsWith("HRBK_SSWATER_RC"))
                {
                    //Debug.Log("[RAYCAST] Hit distance = " + rayHits[i].distance);
                    if(rayHits[i].distance < minDist)
                    {
                        minDist = rayHits[i].distance;
                        nearestHit = rayHits[i];
                        isRayHitTrigger = false;
                    }
                }
            }


            // ---- COLLIDER BASED CHECK ---- //
            Ray triggerRay = new Ray(playerPos + 4096f * Vector3.up, Vector3.down); // Start from sky, point downward
            RaycastHit trigHit = new RaycastHit();

            for(int i = 0; i < waterTriggerList.Length; i++)
            {
                Collider trig = waterTriggerList[i];
                // Do bounding box check first!
                if(trig != null && trig.bounds.Contains(playerPos))
                {
                    if(trig.Raycast(triggerRay, out trigHit, 4096f))
                    {
                        float dist = trigHit.point.y - playerPos.y;

                        if(dist < minDist)
                        {
                            minDist = dist;
                            nearestHit = trigHit;
                            isRayHitTrigger = true;
                        }
                    }
                }
            }

            if(isRayHitTrigger || (nearestHit.transform != null && nearestHit.transform.name.StartsWith("HRBK_SSWATER_RC_TOP")))
            {
                surfacePos = nearestHit.point;
            }

            if(postProcessTarget != null)
            {
                bool test = you.GetTrackingData(VRCPlayerApi.TrackingDataType.Head).position.y < surfacePos.y;
                if(test != postProcessTarget.activeSelf)
                {
                    postProcessTarget.SetActive(test);
                }
            }
        }

        public int GetVaultingLayerMask()
        {
            // UI, Player, PlayerLocal, UIMenu, [reserved2/3/4], [WaterLayer]
            int exclude = (1 << 5) | (1 << 9) | (1 << 10) | (1 << 12) | (7 << 19) | (1 << waterLayer);
            return -1 ^ exclude;
        }

        public float GetRatioOffWater()
        {
            VRCPlayerApi you = Networking.LocalPlayer;
            if(you == null) return 0f;

            bool isGeneric = you.GetBonePosition(HumanBodyBones.Spine).Equals(Vector3.zero);

            Vector3 rearPos = isGeneric
                ? Vector3.Lerp(you.GetTrackingData(VRCPlayerApi.TrackingDataType.Head).position, you.GetPosition(), 0.3f)
                : Vector3.Lerp(you.GetBonePosition(HumanBodyBones.LeftUpperLeg), you.GetBonePosition(HumanBodyBones.RightUpperLeg), 0.5f);
            float headTop = GetTopOfHeadPos().y;
            float row = Mathf.Clamp01(Mathf.InverseLerp(headTop, rearPos.y, surfacePos.y));
            return row * row;
        }

        // FIXME: Refactor this duplicated calculation
        public Vector3 GetNosePos()
        {
            VRCPlayerApi you = Networking.LocalPlayer;
            if(you == null) return Vector3.zero;

            bool isGenericRig = you.GetBonePosition(HumanBodyBones.Spine).Equals(Vector3.zero);
            bool isNoEyeBones = you.GetBonePosition(HumanBodyBones.LeftEye).Equals(Vector3.zero);

            VRCPlayerApi.TrackingData eyeTransform = you.GetTrackingData(VRCPlayerApi.TrackingDataType.Head);
            Vector3 headBonePos = isGenericRig ? Vector3.Lerp(you.GetPosition(), eyeTransform.position, 0.820f) : you.GetBonePosition(HumanBodyBones.Head);
            Vector3 eyeBonesPos = isNoEyeBones ? eyeTransform.position : Vector3.Lerp(you.GetBonePosition(HumanBodyBones.LeftEye), you.GetBonePosition(HumanBodyBones.RightEye), 0.5f);

            Vector3 eyePos = (headBonePos - eyeBonesPos).magnitude < 0.001f ? eyeTransform.position : eyeBonesPos;
            // An attempt to estimate the position of the mouth/nose
            float headBoneToEyeLength = (eyePos - headBonePos).magnitude;


            Vector3 nosePos = Vector3.Lerp(eyePos, headBonePos, 0.333333333f) +
                (eyeTransform.rotation * Vector3.forward * headBoneToEyeLength * 0.666666666f);

            return nosePos;
        }
        public Vector3 GetTopOfHeadPos()
        {
            VRCPlayerApi you = Networking.LocalPlayer;
            if(you == null) return Vector3.zero;

            bool isGenericRig = you.GetBonePosition(HumanBodyBones.Spine).Equals(Vector3.zero);
            bool isNoEyeBones = you.GetBonePosition(HumanBodyBones.LeftEye).Equals(Vector3.zero);

            VRCPlayerApi.TrackingData eyeTransform = you.GetTrackingData(VRCPlayerApi.TrackingDataType.Head);
            Vector3 headBonePos = isGenericRig ? Vector3.Lerp(you.GetPosition(), eyeTransform.position, 0.820f) : you.GetBonePosition(HumanBodyBones.Head);
            Vector3 eyeBonesPos = isNoEyeBones ? eyeTransform.position : Vector3.Lerp(you.GetBonePosition(HumanBodyBones.LeftEye), you.GetBonePosition(HumanBodyBones.RightEye), 0.5f);

            Vector3 eyePos = (headBonePos - eyeBonesPos).magnitude < 0.001f ? eyeTransform.position : eyeBonesPos;
            // An attempt to estimate the position of the mouth/nose
            float headBoneToEyeLength = (eyePos - headBonePos).magnitude;


            // An attempt to estimate the top of the head
            Vector3 aboveEyePos = eyePos + Vector3.up * headBoneToEyeLength * 2f;

            // Artificial lowering for automatic floating
            const float FACEDOWN_LOWERING = 2.2f; // How much the body drops down when facing down
            const float HEAD_HEIGHT = 1.55f; // How much the head is above water
            aboveEyePos.y -= Mathf.Min((eyeTransform.rotation * Vector3.forward * headBoneToEyeLength * FACEDOWN_LOWERING).y, 0f) + headBoneToEyeLength * HEAD_HEIGHT;

            return aboveEyePos;
        }
    }
}