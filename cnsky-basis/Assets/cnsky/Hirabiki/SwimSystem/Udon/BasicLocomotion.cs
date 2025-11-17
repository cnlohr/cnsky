namespace Hirabiki.Udon.Works
{
    using UdonSharp;
    using UnityEngine;
    using VRC.SDKBase;
    using VRC.Udon;
    using VRC.Udon.Common;

    public class BasicLocomotion : UdonSharpBehaviour
    {
        // --- This is now deprecated since it's way too niche ---
        //[Tooltip("Disable if player is in a Station or systems that override default locomotion")]
        [HideInInspector] public bool useVRCLocomotion = true;

        private Vector3 inputMoveVector;

        private bool immobile = false;
        private bool isGrounded = true;
        private bool isGroundAlreadyChecked = false;

        private float originalWalkSpeed, originalRunSpeed, originalStrafeSpeed = -0.123456789f;
        private float originalJumpImpulse, originalGravityStrength = 1;
        private float swimWalkSpeed;

        void Update()
        {
            isGroundAlreadyChecked = false;
        }

        void OnEnable()
        {
            if(!Utilities.IsValid(Networking.LocalPlayer)) return;
        }
        void OnDisable()
        {
            if(!Utilities.IsValid(Networking.LocalPlayer)) return;
            if(originalStrafeSpeed == -0.123456789f)
            {
                SaveOriginalSpeed();
            } else
            {
                Immobilize(false);
                RestoreOriginalSpeed();
            }
        }

        // ---- Udon Input events to solve binding issues ---- //
        public override void InputMoveVertical(float value, UdonInputEventArgs args)
        {
            inputMoveVector.z = value;
        }
        public override void InputMoveHorizontal(float value, UdonInputEventArgs args)
        {
            inputMoveVector.x = value;
        }

        [System.Obsolete("This method was a leftover from the original, custom implementation")]
        public void EnableVRCLocomotion()
        {
            useVRCLocomotion = true;
        }

        [System.Obsolete("This method was a leftover from the original, custom implementation")]
        public void DisableVRCLocomotion()
        {
            useVRCLocomotion = false;
        }

        public Vector3 GetMoveVector()
        {
            return Vector3.ClampMagnitude(inputMoveVector, 1f);
        }

        public void SetSwimWalkSpeed(float v)
        {
            swimWalkSpeed = v;
        }
        public float GetOriginalGravity()
        {
            return originalGravityStrength;
        }

        public void SaveOriginalSpeed()
        {
            originalWalkSpeed = Networking.LocalPlayer.GetWalkSpeed();
            originalRunSpeed = Networking.LocalPlayer.GetRunSpeed();
            originalStrafeSpeed = Networking.LocalPlayer.GetStrafeSpeed();
            originalJumpImpulse = Networking.LocalPlayer.GetJumpImpulse();
            originalGravityStrength = Networking.LocalPlayer.GetGravityStrength();
            //Debug.Log($"SWIMSYSTEM -- [save] WS/RS/SS, JI/GRAV = {originalWalkSpeed}/{originalRunSpeed}/{originalStrafeSpeed}, {originalJumpImpulse}/{originalGravity}");
        }
        public void RestoreOriginalSpeed()
        {
            Networking.LocalPlayer.SetWalkSpeed(originalWalkSpeed);
            Networking.LocalPlayer.SetRunSpeed(originalRunSpeed);
            Networking.LocalPlayer.SetStrafeSpeed(originalStrafeSpeed);
            Networking.LocalPlayer.SetJumpImpulse(originalJumpImpulse);
            Networking.LocalPlayer.SetGravityStrength(originalGravityStrength);
            //Debug.Log($"SWIMSYSTEM -- [load] WS/RS/SS, JI/GRAV = {originalWalkSpeed}/{originalRunSpeed}/{originalStrafeSpeed}, {originalJumpImpulse}/{originalGravity}");
        }
        public void BlendSwimWalkSpeed(float lerp)
        {
            Networking.LocalPlayer.SetWalkSpeed(Mathf.Lerp(swimWalkSpeed, originalWalkSpeed, lerp));
            Networking.LocalPlayer.SetRunSpeed(Mathf.Lerp(swimWalkSpeed, originalRunSpeed, lerp));
            Networking.LocalPlayer.SetStrafeSpeed(Mathf.Lerp(swimWalkSpeed, originalStrafeSpeed, lerp));
        }

        public Vector3 GetVelocity()
        {
            return Networking.LocalPlayer.GetVelocity();
        }
        public void SetVelocity(Vector3 v)
        {
            Networking.LocalPlayer.SetVelocity(v);
        }
        public void SetGravityStrength(float f)
        {
            Networking.LocalPlayer.SetGravityStrength(f);
        }
        public void Immobilize(bool b)
        {
            // Strafe speed is now controllable, so just reduce the speed to near-halt instead
            immobile = b;
            if(b)
            {
                Networking.LocalPlayer.SetWalkSpeed(0.001f);
                Networking.LocalPlayer.SetRunSpeed(0.001f);
                Networking.LocalPlayer.SetStrafeSpeed(0.001f);
            } else
            {
                Networking.LocalPlayer.SetWalkSpeed(swimWalkSpeed);
                Networking.LocalPlayer.SetRunSpeed(swimWalkSpeed);
                Networking.LocalPlayer.SetStrafeSpeed(swimWalkSpeed);
                Networking.LocalPlayer.SetJumpImpulse(originalJumpImpulse * 0.666666666f);
            }
        }

        // Replaces Udon's LocalPlayer.IsPlayerGrounded()
        public bool IsOnGround()
        {
            return IsOnFloor(false);
        }

        public bool IsOnFloor(bool checkFloor)
        {
            if(Networking.LocalPlayer.IsPlayerGrounded()) return true; // Nice catch! VRChat

            if(!isGroundAlreadyChecked || checkFloor)
            {
                float lift = checkFloor ? 0.05f : 0.185f;
                float size = checkFloor ? 0.10f : 0.20f;

                int layerMask = 3934687; // PlayerLocal's collision layers (up to layer 21)
                Vector3 p = Networking.LocalPlayer.GetPosition() + lift * Vector3.up;
                isGrounded = Physics.CheckSphere(p, size, layerMask, QueryTriggerInteraction.Ignore); // Don't detect triggers

                isGroundAlreadyChecked = !checkFloor;
            }
            return isGrounded;
        }

        [System.Obsolete("Custom locomotion is too niche - no longer supported")]
        public bool IsUsingVRCLocomotion()
        {
            return true;
        }
    }
}