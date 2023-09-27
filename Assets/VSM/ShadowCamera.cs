using System;
using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace VSM
{
    public class ShadowCamera : MonoBehaviour
    {
        public Light MainLight;
        public int rtResolution = 1024;
        
        private GameObject shadowCamObj;
        private Camera shadowCam;
        private Camera mainCam;
        
        private RenderTexture shadowRT;
        
        private void Start()
        {
            mainCam = Camera.main;
            
            shadowRT = new RenderTexture(rtResolution, rtResolution, 32, RenderTextureFormat.RGFloat)
            {
                name = "Variance Shadow Map",
                useMipMap = true,
                autoGenerateMips = true,
                filterMode = FilterMode.Trilinear
            };
            
            shadowCamObj = new GameObject("Variance Shadow Camera");
            shadowCam = shadowCamObj.AddComponent<Camera>();
            // shadowCam.enabled = false;
            shadowCam.depth = -100;
            shadowCam.orthographic = true;
            shadowCam.clearFlags = CameraClearFlags.SolidColor;
            shadowCam.backgroundColor = Color.white;
            shadowCam.targetTexture = shadowRT;
            var cameraData = shadowCamObj.AddComponent<UniversalAdditionalCameraData>();
            cameraData.requiresDepthTexture = false;
            cameraData.requiresColorTexture = false;
            cameraData.renderShadows = false;
            cameraData.SetRenderer(1);
        }

        private void Update()
        {
            MoveShadowCamera();
        }

        private void OnDestroy()
        {
            shadowRT.Release();
        }

        private void MoveShadowCamera()
        {
            Vector3[] corners = new Vector3[8];
            Vector3[] farCorners = new Vector3[4];
            Vector3[] nearCorners = new Vector3[4];
            mainCam.CalculateFrustumCorners(new Rect(0, 0, 1, 1), mainCam.farClipPlane, Camera.MonoOrStereoscopicEye.Mono, farCorners);
            mainCam.CalculateFrustumCorners(new Rect(0, 0, 1, 1), mainCam.nearClipPlane, Camera.MonoOrStereoscopicEye.Mono, nearCorners);
            Matrix4x4 mainCamLocalToWorld = mainCam.transform.localToWorldMatrix;
            for (int i = 0; i < 4; i++)
            {
                corners[i] = mainCamLocalToWorld.MultiplyPoint3x4(farCorners[i]);
            }
            for (int i = 0; i < 4; i++)
            {
                corners[i + 4] = mainCamLocalToWorld.MultiplyPoint3x4(nearCorners[i]);
            }

            Matrix4x4 worldToLightMatrix = MainLight.transform.worldToLocalMatrix;
            Vector3[] ps = new Vector3[8];
            for (int i = 0; i < 8; i++)
            {
                ps[i] = worldToLightMatrix.MultiplyPoint3x4(corners[i]);
            }
            
            float[] xs = new float[8];
            float[] ys = new float[8];
            float[] zs = new float[8];
            for (int i = 0; i < 8; i++)
            {
                xs[i] = ps[i].x;
                ys[i] = ps[i].y;
                zs[i] = ps[i].z;
            }
            Vector3 minPt = new Vector3(Mathf.Min(xs), Mathf.Min(ys), Mathf.Min(zs));
            Vector3 maxPt = new Vector3(Mathf.Max(xs), Mathf.Max(ys), Mathf.Max(zs));
            float aspect = (maxPt.x - minPt.x) / (maxPt.y - minPt.y);
            
            //相机的位置在近屏面的中心
            shadowCam.transform.rotation = MainLight.transform.rotation;
            shadowCam.transform.position = MainLight.transform.TransformPoint(new Vector3((minPt.x + maxPt.x) * 0.5f, (minPt.y + maxPt.y) * 0.5f, minPt.z));
            shadowCam.nearClipPlane = 0;// minPt.z;
            shadowCam.farClipPlane = maxPt.z - minPt.z;
            shadowCam.orthographicSize = (maxPt.y - minPt.y) * 0.5f;
            shadowCam.aspect = aspect;
        }
    }
}