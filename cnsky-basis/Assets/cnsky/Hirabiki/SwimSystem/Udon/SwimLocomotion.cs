namespace Hirabiki.Udon.Works
{
    using UdonSharp;
    using UnityEngine;
    using UnityEngine.UI;
    using VRC.SDKBase;
    using VRC.Udon;
    using VRC.Udon.Common;

    /// <summary>
    /// This UdonSharpBehaviour is intended to separate out the locomotion and the abstract aspects of swim
    /// </summary>
    public class SwimLocomotion : UdonSharpBehaviour
    {
        [Header("Important configuration")]
        [Tooltip(@"Script to send event to when player exters/exits water
Assign this to Udon_BreathSystem inside BreathSystem prefab
List of Custom Events:
OnWaterEnter
OnWaterExit
OnUnderwaterEnter
OnUnderwaterExit")]
        // [HideInInspector] // Uncomment this line for SwimSystem + BreathSystem package
        [SerializeField] private UdonBehaviour breathSystemEvent;
        

        [Header("Script references")]
        [Tooltip("Script that detect position of water surface")]
        [SerializeField] private SwimRaycast swimPhysics;  // For determining surface of water

        [Tooltip("Script for updating player movement and position")]
        [SerializeField] private BasicLocomotion locomotion; // For interfacing with traditional VRC locomotion
        // HACK: UdonSharp does not support interface yet so it require changing class name
        
        [Header("Sound settings")]
        [Tooltip("AudioSource for underwater sound (loop)")]
        [SerializeField] private AudioSource underwaterSound;

        [Tooltip("AudioSource for sound effects")]
        [SerializeField] private AudioSource localOneShotSounds;

        [Tooltip("Sound effect when player jumps into water")]
        [SerializeField] private AudioClip bodySplashClip;

        [Tooltip("Sound effect when player hands splash into water (VR only)")]
        [SerializeField] private AudioClip handSplashClip;

        [Header("Locomotion settings")]

        [Tooltip(@"Should simplified hand swimming controls be used?
Disabled: Ability to swim backwards and sideways
Enabled: Trigger can be kept held when swimming")]
        public bool useSimpleHandSwim;

        [Tooltip(@"Set WASD/Thumbstick movement direction
Disabled: Head direction
Enabled: Hands direction (VR only)
Desktop always uses head direction")]
        public bool useHandsForDirection;

        [Tooltip(@"::Call DisableFootSwim to disable and
EnableSimpleFootSwim to enable from script::

Players with FBT setup can use their legs to swim.
if RealisticFullBodySwim is disabled, player can swim by simply swinging their legs.
Swimming locomotion for regular VR player with FBT swim enabled will not work correctly.
It is not possible to tell regular VR and FBT players apart so put a warning in your world.")]
        public bool useFullBodySwim;

        [Tooltip(@"::Call EnableRealFootSwim to enable from script::

UseFullBodySwim must be enabled to use this setting.
The locomotion of full-body leg swimming will be mostly realistic to real life.
This mode is for the most dedicated players with full-body setup")]
        public bool realisticFullBodySwim;

        [Header("Speed settings")]
        [Tooltip("Swimming speed with WASD keys or Thumbstick")]
        public float moveSwimSpeed = 1.5f;

        [Tooltip("Swimming speed with arms (VR only)")]
        public float handSwimSpeed = 1.5f;

        [Tooltip("Swimming speed with legs (VR only)")]
        public float fullBodyLegSwimSpeed = 1.0f;

        [Header("Physics settings")]
        [Tooltip("Movement friction in water")]
        public float waterDrag = 1.2f;

        [Tooltip("Negative buoyancy at depth")]
        public float sinkingGravity = 0.04f;

        [Tooltip("Positive buoyancy at water surface")]
        public float buoyancyGravity = 0.09f;

        [Tooltip("Rate of buoyancy falloff based on depth")]
        public float buoyancyFalloff = 0.25f;

        [Header("Advanced settings")]

        // Set by SwimSystem
        [System.NonSerialized] public float swimEnergy = 1.0f;
        [System.NonSerialized] public float buoyancyRatio = 1.0f;
        // Set for SwimSystem
        [System.NonSerialized] public Vector3 swimVectorEcho;
        [Header("UGUI text debug output")]
        [SerializeField] private Text debugText;

        private VRCPlayerApi you;

        // Last positions on previous update
        private Vector3 prevHandLPos;
        private Vector3 prevHandRPos;
        private float prevFootLAngVel;
        private float prevFootRAngVel;
        // Calculated velocities
        private Vector3 handLVector;
        private Vector3 handRVector;
        private float footLVelocity;
        private float footRVelocity;

        private Vector3 prevPlayerVector;

        private bool isSwimming;
        private bool isUnderwater;

        private float diveTime;
        private float uwStartTime;
        private float uwEndTime;
        private float touchdownTime;
        private float jumpTime;
        // private int updateDelay;
        private int emulatedSwimLockDelay;
        private int realSwimLockDelay;

        void Start()
        {
            you = Networking.LocalPlayer;
            if(Networking.LocalPlayer == null)
            {
                gameObject.SetActive(false);
            }
        }

        void OnEnable()
        {
            if(isUnderwater)
            {
                if(underwaterSound != null) underwaterSound.Play();
            } else
            {
                if(underwaterSound != null) underwaterSound.Stop();
            }
        }

        void Update()
        {
            if(Networking.LocalPlayer == null) return;
            if(you == null) // Trying to ward off nasty edge-case bugs found with very small probability
            {
                you = Networking.LocalPlayer;
                return;
            }
            if(locomotion.IsOnGround() && Time.time - jumpTime > 0.2f)
            {
                touchdownTime = Time.time;
            }
            // if(--updateDelay > 0) return;
            // updateDelay = updateInterval;

            bool isGenericRig = you.GetBonePosition(HumanBodyBones.Spine).Equals(Vector3.zero);
            bool isNoEyeBones = you.GetBonePosition(HumanBodyBones.LeftEye).Equals(Vector3.zero);

            VRCPlayerApi.TrackingData eyeTransform = you.GetTrackingData(VRCPlayerApi.TrackingDataType.Head);
            Vector3 headBonePos = isGenericRig ? Vector3.Lerp(you.GetPosition(), eyeTransform.position, 0.820f) : you.GetBonePosition(HumanBodyBones.Head);
            Vector3 eyeBonesPos = isNoEyeBones ? eyeTransform.position : Vector3.Lerp(you.GetBonePosition(HumanBodyBones.LeftEye), you.GetBonePosition(HumanBodyBones.RightEye), 0.5f);

            Vector3 eyePos = (headBonePos - eyeBonesPos).magnitude < 0.001f ? eyeTransform.position : eyeBonesPos;
            // An attempt to estimate the position of the mouth/nose
            float headBoneToEyeLength = (eyePos - headBonePos).magnitude;


            Vector3 hipsPos = isGenericRig
                ? Vector3.Lerp(you.GetPosition(), eyeTransform.position, 0.4f)
                : you.GetBonePosition(HumanBodyBones.Hips) + Vector3.down * headBoneToEyeLength * 0.5f;
            Vector3 nosePos = Vector3.Lerp(eyePos, headBonePos, 0.333333333f) +
                (eyeTransform.rotation * Vector3.forward * headBoneToEyeLength * 0.666666666f);

            bool nowSwimming = IsInWater(hipsPos);
            bool nowUnderwater = IsInWater(nosePos);
            if(nowSwimming != isSwimming && Time.time - diveTime > 0.1f)
            {
                if(nowSwimming)
                {
                    if(breathSystemEvent != null) breathSystemEvent.SendCustomEvent("OnSwimEnter");
                    locomotion.SaveOriginalSpeed();
                    locomotion.Immobilize(true);

                    Vector3 pVel = locomotion.GetVelocity();
                    PlayWaterSplash(bodySplashClip, Vector3.Scale(pVel, new Vector3(0.5f, 1.0f, 0.5f)), 1.0f);
                    locomotion.SetVelocity(pVel * 0.75f);

                    diveTime = Time.time;
                } else
                {
                    if(breathSystemEvent != null) breathSystemEvent.SendCustomEvent("OnSwimExit");
                    locomotion.Immobilize(false);
                    locomotion.RestoreOriginalSpeed();
                }
                isSwimming = nowSwimming;
            }
            if(nowUnderwater != isUnderwater && Time.time - uwStartTime > 0.1f)
            {
                if(nowUnderwater)
                {
                    if(breathSystemEvent != null) breathSystemEvent.SendCustomEvent("OnUnderwaterEnter");
                    if(underwaterSound != null) underwaterSound.Play();
                    uwStartTime = Time.time;
                } else
                {
                    if(breathSystemEvent != null) breathSystemEvent.SendCustomEvent("OnUnderwaterExit");
                    if(underwaterSound != null) underwaterSound.Stop();

                    locomotion.SetVelocity(Vector3.Scale(locomotion.GetVelocity(), new Vector3(1f, 0.5f, 1f)));
                }
                isUnderwater = nowUnderwater;
            }
            if(isUnderwater) uwEndTime = Time.time;

            if(debugText != null)
            {
                Vector3 sv = GetSwimVector();
                debugText.text = $@"-- Swim Locomotion --
Buoyancy: {buoyancyGravity} ({GetBuoyancyVector().y})
Swim Energy: {swimEnergy}
Swim Input: {sv.ToString("F2")} = {sv.magnitude}
Dive Time: {uwEndTime - uwStartTime} / Depth: {GetDepth()}
P-GS: {you.GetGravityStrength()}
P-WS: {you.GetWalkSpeed()}
P-RS: {you.GetRunSpeed()}
P-SS: {you.GetStrafeSpeed()}
P-JS: {you.GetJumpImpulse()}
Surface Y pos: {swimPhysics.surfacePos.y}
isSwimming: {isSwimming} / isUnderwater: {isUnderwater}
Can Vault: {CanVaultFromWater()}
IsPlayerGrounded: {you.IsPlayerGrounded()}
Touchdown/Jump Time: {touchdownTime} / {jumpTime}
CheckSphere: {locomotion.IsOnGround()}, {locomotion.IsOnFloor(true)} / RatioOffWater: {swimPhysics.GetRatioOffWater()}";

            }

            if(!isSwimming) return;
            // ---- If not swimming, THIS IS THE END OF THE LINE ---- //


            float deltaTimeStep = Time.deltaTime;// * updateInterval;

            // Fetch hand positions
            VRCPlayerApi.TrackingData handLTransform = you.GetTrackingData(VRCPlayerApi.TrackingDataType.LeftHand);
            VRCPlayerApi.TrackingData handRTransform = you.GetTrackingData(VRCPlayerApi.TrackingDataType.RightHand);

            // Manual velocity calculation
            Vector3 newHandLPos = handLTransform.position - you.GetPosition();
            Vector3 newHandRPos = handRTransform.position - you.GetPosition();

            Vector3 newLegLDir = (you.GetBonePosition(HumanBodyBones.LeftUpperLeg) - you.GetBonePosition(HumanBodyBones.LeftLowerLeg)).normalized;
            Vector3 newLegRDir = (you.GetBonePosition(HumanBodyBones.RightUpperLeg) - you.GetBonePosition(HumanBodyBones.RightLowerLeg)).normalized;
            Vector3 newFootLDir = (you.GetBonePosition(HumanBodyBones.LeftLowerLeg) - you.GetBonePosition(HumanBodyBones.LeftFoot)).normalized;
            Vector3 newFootRDir = (you.GetBonePosition(HumanBodyBones.RightLowerLeg) - you.GetBonePosition(HumanBodyBones.RightFoot)).normalized;
            float newFootLAngVel = isGenericRig ? 0f : Mathf.Deg2Rad * Vector3.Angle(newLegLDir, newFootRDir);
            float newFootRAngVel = isGenericRig ? 0f : Mathf.Deg2Rad * Vector3.Angle(newLegRDir, newFootRDir);

            // Update velocities -- these are essential in GetSwimVector()
            handLVector = (newHandLPos - prevHandLPos) / deltaTimeStep;
            handRVector = (newHandRPos - prevHandRPos) / deltaTimeStep;

            footLVelocity = Mathf.Abs(prevFootLAngVel - newFootLAngVel) / deltaTimeStep;
            footRVelocity = Mathf.Abs(prevFootRAngVel - newFootRAngVel) / deltaTimeStep;

            if(you.IsUserInVR() && Time.time - diveTime > 0.1f)
            {
                if(!IsInWater(you.GetPosition() + prevHandLPos) && IsInWater(handLTransform.position))
                {
                    PlayWaterSplash(handSplashClip, Vector3.ClampMagnitude(handLVector, 3f), 0.5f);
                }
                if(!IsInWater(you.GetPosition() + prevHandRPos) && IsInWater(handRTransform.position))
                {
                    PlayWaterSplash(handSplashClip, Vector3.ClampMagnitude(handRVector, 3f), 0.5f);
                }
            }

            // Update old positions
            prevHandLPos = newHandLPos;
            prevHandRPos = newHandRPos;
            prevFootLAngVel = newFootLAngVel;
            prevFootRAngVel = newFootRAngVel;

            Vector3 swimVector = GetSwimVector() * swimEnergy + GetBuoyancyVector();

            float finalGravity = Mathf.Lerp(0.000001f, locomotion.GetOriginalGravity(), swimPhysics.GetRatioOffWater() * Mathf.Clamp01((Time.time - touchdownTime) * 2f));
            locomotion.SetGravityStrength(finalGravity);

            if(locomotion.IsOnGround())
            {
                locomotion.SetSwimWalkSpeed(moveSwimSpeed * 0.75f);
                locomotion.Immobilize(false);
                locomotion.BlendSwimWalkSpeed(Mathf.Clamp01(swimPhysics.GetRatioOffWater() * 1.5f - 0.5f));
                if(you.IsUserInVR())
                {
                    locomotion.SetGravityStrength(0.000001f);
                }
            } else
            {
                locomotion.Immobilize(true);
            }

            float initVel = 0.0012f / deltaTimeStep; // 2.1.2 Fix getting stuck at high frame rates >90 fps, made it tied to fps (original value: 0.1)
            // Unstick the sticky VRC ground
            if(locomotion.IsOnGround())
            {
                // If stuck, and attempting to move by either hand swim, or via movement stick by checking if not landed on the ground
                if((GetHandSwimInput().sqrMagnitude > 0.001f) || (locomotion.GetMoveVector().sqrMagnitude > 0.001f && isUnderwater)) {

                    you.TeleportTo(you.GetPosition() + Vector3.up * 0.004f, you.GetRotation(), VRC_SceneDescriptor.SpawnOrientation.Default, true);
                    locomotion.SetVelocity(Vector3.Scale(locomotion.GetVelocity(), new Vector3(1f, 0f, 1f)));
                }
            }

            // Unstick initial horizontal movement
            Vector3 newVelocity;
            if(!locomotion.IsOnGround()
                && Vector3.Scale(locomotion.GetVelocity(), new Vector3(1f, 0f, 1f)).magnitude < initVel * 0.5f
                && Vector3.Scale(swimVector, new Vector3(1f, 0f, 1f)).magnitude > initVel)
            {
                newVelocity = locomotion.GetVelocity() + Vector3.Scale(Vector3.Scale(swimVector, new Vector3(1f, 0.2f, 1f)).normalized, new Vector3(initVel, 0f, initVel)) + swimVector.y * Vector3.up * deltaTimeStep;
            } else
            {
                newVelocity = locomotion.GetVelocity() + swimVector * deltaTimeStep;
            }


            // Set new velocity, with drag
            float diveDragAdd = 0f;
            if(isUnderwater)
            {
                diveDragAdd = Mathf.Clamp01(diveTime - Time.time + 1f);
                diveDragAdd = diveDragAdd * diveDragAdd * 4f;
            }

            //locomotion.SetVelocity(newVelocity * Mathf.Pow(Mathf.Clamp01(waterDrag) * diveDecay, deltaTimeStep) + Vector3.up * jumpForce);
            if(Time.time - jumpTime > 0.1f)
            {
                float hydroDynamic = Mathf.Cos(Vector3.Angle(newVelocity, eyeBonesPos - hipsPos) * Mathf.Deg2Rad);
                float finalWaterDrag = Mathf.Lerp(waterDrag, waterDrag * 0.5f, Mathf.Abs(hydroDynamic));
                locomotion.SetVelocity(newVelocity * (1f - deltaTimeStep * (finalWaterDrag + diveDragAdd)));
            }

            // Update locking timers
            emulatedSwimLockDelay -= 1;
            realSwimLockDelay -= 1;

            prevPlayerVector = locomotion.GetVelocity();
        }

        public override void InputJump(bool value, UdonInputEventArgs args)
        {
            if(isSwimming && value) // If jump button down
            {
                if(isSwimming && Time.time - touchdownTime < 0.1f)
                {
                    jumpTime = Time.time;
                }
                //Vaulting mechanics
                if(CanVaultFromWater())
                {
                    Vector3 newVelocity = locomotion.GetVelocity();

                    Vector3 eyeBonesPos = you.GetBonePosition(HumanBodyBones.LeftEye).Equals(Vector3.zero) // Eye bones exist?
                        ? you.GetTrackingData(VRCPlayerApi.TrackingDataType.Head).position // No, use head tracking position
                        : Vector3.Lerp(you.GetBonePosition(HumanBodyBones.LeftEye), you.GetBonePosition(HumanBodyBones.RightEye), 0.5f); // Yes

                    float vaultImpulse = Mathf.Sqrt(locomotion.GetOriginalGravity()) * 2.25f;

                    newVelocity.y = Mathf.Abs(eyeBonesPos.y - you.GetPosition().y) * vaultImpulse + vaultImpulse;
                    locomotion.SetVelocity(newVelocity);
                }
            }
        }

        // Public methods for SendCustomEvent
        public void DisableFootSwim()
        {
            useFullBodySwim = false;
            realisticFullBodySwim = false;
        }
        public void EnableSimpleFootSwim()
        {
            useFullBodySwim = true;
            realisticFullBodySwim = false;
        }
        public void EnableRealFootSwim()
        {
            useFullBodySwim = true;
            realisticFullBodySwim = true;
        }
        public void MuteAllSwimSounds()
        {
            if(underwaterSound != null) underwaterSound.mute = true;
            if(localOneShotSounds != null) localOneShotSounds.mute = true;
            if(breathSystemEvent != null) breathSystemEvent.SendCustomEvent("MuteAllSounds");
        }
        public void UnmuteAllSwimSounds()
        {
            if(underwaterSound != null) underwaterSound.mute = false;
            if(localOneShotSounds != null) localOneShotSounds.mute = false;
            if(breathSystemEvent != null) breathSystemEvent.SendCustomEvent("UnmuteAllSounds");
        }

        public bool IsSwimming()
        {
            return isSwimming;
        }

        // Input vector
        private Vector3 GetHandSwimInput()
        {
            float inputLT = Input.GetAxisRaw("Oculus_CrossPlatform_PrimaryIndexTrigger");
            float inputRT = Input.GetAxisRaw("Oculus_CrossPlatform_SecondaryIndexTrigger");
            float aboveWaterLMult = Mathf.Lerp(1f, 0f, (you.GetTrackingData(VRCPlayerApi.TrackingDataType.LeftHand).position - swimPhysics.surfacePos).y * 5f);
            float aboveWaterRMult = Mathf.Lerp(1f, 0f, (you.GetTrackingData(VRCPlayerApi.TrackingDataType.RightHand).position - swimPhysics.surfacePos).y * 5f);
            float singleHandPenalty = isUnderwater ? Mathf.Lerp(0.75f, 1.0f, Mathf.Min(inputLT, inputRT)) : 1.0f;
            Vector3 inputHandLVector = handLVector * -inputLT * aboveWaterLMult * singleHandPenalty;
            Vector3 inputHandRVector = handRVector * -inputRT * aboveWaterRMult * singleHandPenalty;

            // Simplified swimming (can swim with trigger always held - bad new is: can't swim backwards)
            if(useSimpleHandSwim)
            {
                inputHandLVector *= Quaternion.Angle(Quaternion.LookRotation(inputHandLVector.normalized, Vector3.up),
                    you.GetTrackingData(VRCPlayerApi.TrackingDataType.Head).rotation) < 105f ? 1.1f : 0f;
                inputHandRVector *= Quaternion.Angle(Quaternion.LookRotation(inputHandRVector.normalized, Vector3.up),
                    you.GetTrackingData(VRCPlayerApi.TrackingDataType.Head).rotation) < 105f ? 1.1f : 0f;
            }
            // Separate left and right hand velocity
            Vector3 directSwimVector = inputHandLVector + inputHandRVector;


            // Combined left and right hand velocity's magnitude
            float combinedSwimMagnitude = inputHandLVector.magnitude + inputHandRVector.magnitude;
            return Vector3.Lerp(directSwimVector, directSwimVector.normalized * combinedSwimMagnitude, 0.5f) * handSwimSpeed;
        }
        // Final vector
        public Vector3 GetSwimVector()
        {
            // Init
            Vector3 handSwim = Vector3.zero;
            Vector3 legSwim = Vector3.zero;

            // VR hand swim locomotion
            if(you.IsUserInVR())
            {
                handSwim = GetHandSwimInput();

                // FBT leg swim locomotion
                float legLength = Vector3.Distance(you.GetBonePosition(HumanBodyBones.LeftUpperLeg), you.GetBonePosition(HumanBodyBones.LeftLowerLeg))
                    + Vector3.Distance(you.GetBonePosition(HumanBodyBones.LeftLowerLeg), you.GetBonePosition(HumanBodyBones.LeftFoot));
                Vector3 legSwimVector = useFullBodySwim ? FullBodySwimDirection() * Vector3.forward * legLength * (footLVelocity + footRVelocity) : Vector3.zero;
                legSwim = 0.200f * fullBodyLegSwimSpeed * legSwimVector;
            }

            // Emulated swim locomotion
            Quaternion moveRot = you.IsUserInVR() && useHandsForDirection ? VRSwimDirection() : you.GetTrackingData(VRCPlayerApi.TrackingDataType.Head).rotation;
            Vector3 emulatedSwim = moveRot * locomotion.GetMoveVector() * 2f
                + (Input.GetButton("Jump") ? Vector3.up : Vector3.zero)
                + (Input.GetKey(KeyCode.LeftControl) ? Vector3.down : Vector3.zero);

            // Prevent using multiple swim methods at the same time
            if(handSwim.sqrMagnitude + legSwim.sqrMagnitude > 0f)
            {
                // Disable emulated swim when hands or leg move
                // Essentially locks out emulated swim input with leg swim enabled
                emulatedSwimLockDelay = 4;
            }

            // Even though emulatedSwim is suppressed, the avatar itself still changes animation
            if(emulatedSwim.sqrMagnitude > 0f)
            {
                // Reject full-body leg swim when there's an attempted emulated swim input
                // Emulated movement messes with feet positions due to animation change
                realSwimLockDelay = 4;
            }

            emulatedSwim *= emulatedSwimLockDelay <= 0 ? 1f : 0f;
            legSwim *= realSwimLockDelay <= 0 ? 1f : 0f;
            emulatedSwim = emulatedSwim.normalized * Mathf.Min(emulatedSwim.magnitude, 1f) * moveSwimSpeed;

            // Swimming speed cap
            Vector3 pVel = locomotion.GetVelocity();
            float emulatedSwimCap = Mathf.Sin(Mathf.Clamp(Vector3.Angle(pVel, emulatedSwim), 0f, 90f) * Mathf.Deg2Rad); // == 0 if exactly aligned
            float handSwimCap     = Mathf.Sin(Mathf.Clamp(Vector3.Angle(pVel,     handSwim), 0f, 90f) * Mathf.Deg2Rad); // == 0 if exactly aligned
            float legSwimCap      = Mathf.Sin(Mathf.Clamp(Vector3.Angle(pVel,      legSwim), 0f, 90f) * Mathf.Deg2Rad); // == 0 if exactly aligned

            // approaches speed cap as velocity -> max swim speed
            emulatedSwim *= Mathf.Lerp(1f, emulatedSwimCap, Mathf.Clamp01(pVel.magnitude /        moveSwimSpeed - 0.5f));
            handSwim     *= Mathf.Lerp(1f,     handSwimCap, Mathf.Clamp01(pVel.magnitude /        handSwimSpeed - 0.5f));
            legSwim      *= Mathf.Lerp(1f,      legSwimCap, Mathf.Clamp01(pVel.magnitude / fullBodyLegSwimSpeed - 0.5f));

            Vector3 swimVector = emulatedSwim + handSwim + legSwim;

            // Artificial clamping of upward velocity when already on surface
            swimVector.y *= swimVector.y < 0 ? 1f : Mathf.Lerp(1f, 0f, swimPhysics.GetRatioOffWater() * 4f);

            // For use in BreathSystem
            swimVectorEcho = swimVector;
            return swimVector;
        }

        // A mechanic to make it possible to jump out of water while facing a ledge that can be climbed up or so
        private bool CanVaultFromWater()
        {
            if(!isSwimming || isUnderwater || locomotion.IsOnGround()) return false;
            bool isGenericRig = you.GetBonePosition(HumanBodyBones.Spine).Equals(Vector3.zero);

            Vector3 facing = you.GetTrackingData(VRCPlayerApi.TrackingDataType.Head).rotation * Vector3.forward;

            Vector3 headPos = you.GetTrackingData(VRCPlayerApi.TrackingDataType.Head).position;
            headPos.y += Vector3.Distance(you.GetPosition(), headPos) * 0.15f; // Upward lift as to hopefully not need to look up to vault

            Vector3 hipPos = Vector3.Lerp(you.GetPosition(), headPos, 0.333333333f); // Use the rough estimation first
            if(!isGenericRig) hipPos.y = Mathf.Lerp(you.GetPosition().y, you.GetBonePosition(HumanBodyBones.Hips).y, 0.666666666f);

            headPos.y += facing.y * Mathf.Abs(headPos.y - hipPos.y) * 0.05f;

            bool wallNearHip = false, wallNearHead = false;

            int layerMask = swimPhysics.GetVaultingLayerMask();
            RaycastHit hit; // VRC Player capsule have 0.2 radius
            if(Physics.Raycast(hipPos, facing, out hit, 0.5f, layerMask))
            {
                wallNearHip = true;
            }
            if(Physics.Raycast(headPos, facing, out hit, 0.5f, layerMask))
            {
                wallNearHead = true;
            }
            return wallNearHip && !wallNearHead;
        }

        public Vector3 GetBuoyancyVector()
        {
            return -Physics.gravity * locomotion.GetOriginalGravity() * (buoyancyRatio * buoyancyGravity / (GetDepth() * Mathf.Max(0f, buoyancyFalloff) + 1f) - sinkingGravity);
        }

        private float GetDepth()
        {
            return Mathf.Max(0f, (swimPhysics.surfacePos - swimPhysics.GetTopOfHeadPos()).y);
        }

        private bool IsInWater(Vector3 point)
        {
            // Attempt to work around race condition when GameObject is deactivated
            return swimPhysics.surfacePos.y > point.y && gameObject.activeInHierarchy && enabled;
        }

        private void PlayWaterSplash(AudioClip clip, Vector3 vector, float threshold)
        {
            if(localOneShotSounds != null && vector.magnitude > threshold)
            {
                Vector3 scaled = Vector3.Scale(vector, new Vector3(0.5f, 1f, 0.5f));
                localOneShotSounds.PlayOneShot(clip, scaled.magnitude * 0.125f);
            }
        }

        private Quaternion VRSwimDirection()
        {
            Quaternion eyeRot = you.GetTrackingData(VRCPlayerApi.TrackingDataType.Head).rotation;
            // Strip off the roll of hand rotation too
            Quaternion handLRot = Quaternion.LookRotation(you.GetTrackingData(VRCPlayerApi.TrackingDataType.LeftHand).rotation * Vector3.forward, Vector3.up);
            Quaternion handRRot = Quaternion.LookRotation(you.GetTrackingData(VRCPlayerApi.TrackingDataType.RightHand).rotation * Vector3.forward, Vector3.up);
            // If both hands angle difference is high, use more of eye rotation instead starting from 90 deg
            float angleDiff = Quaternion.Angle(handLRot, handRRot); // degrees
            float eyeDirLerp = Mathf.Clamp01(angleDiff / 90f - 1f);

            return Quaternion.Slerp(Quaternion.Slerp(handLRot, handRRot, 0.5f), eyeRot, eyeDirLerp);
        }

        private Quaternion FullBodySwimDirection()
        {
            if(!realisticFullBodySwim)
            {
                return useHandsForDirection ? VRSwimDirection() : you.GetTrackingData(VRCPlayerApi.TrackingDataType.Head).rotation;
            }
            Vector3 avgLegPos = Vector3.Lerp(you.GetBonePosition(HumanBodyBones.LeftFoot), you.GetBonePosition(HumanBodyBones.RightFoot), 0.5f);
            Vector3 headBonePos = you.GetBonePosition(HumanBodyBones.Head);

            return Quaternion.LookRotation((headBonePos - avgLegPos).normalized, Vector3.up);
        }
    }
}