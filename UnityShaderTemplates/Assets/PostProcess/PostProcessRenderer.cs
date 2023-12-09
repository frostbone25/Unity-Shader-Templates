using System;
using System.Collections;
using System.Collections.Generic;
using System.Drawing;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.PostProcessing;
using UnityEngine.UIElements;

namespace PostProcess
{
    public sealed class PostProcessRenderer : PostProcessEffectRenderer<PostProcess>
    {
        private Shader postShader;
        private RenderTexture computeWrite = null;

        public override DepthTextureMode GetCameraFlags()
        {
            return DepthTextureMode.Depth | DepthTextureMode.DepthNormals | DepthTextureMode.MotionVectors;
        }

        public override void Release()
        {
            base.Release();

            if (computeWrite != null) 
                computeWrite.Release();
        }

        public override void Render(PostProcessRenderContext context)
        {
            if (postShader == null)
            {
                postShader = Shader.Find("Hidden/PostProcess");
                return;
            }

            PropertySheet sheet = context.propertySheets.Get(postShader);

            context.command.BeginSample("Post Process");

            Camera.StereoscopicEye activeEye = Camera.StereoscopicEye.Left;

            switch(context.camera.stereoActiveEye)
            {
                case Camera.MonoOrStereoscopicEye.Mono:
                    activeEye = Camera.StereoscopicEye.Left;
                    break;
                case Camera.MonoOrStereoscopicEye.Left:
                    activeEye = Camera.StereoscopicEye.Left;
                    break;
                case Camera.MonoOrStereoscopicEye.Right:
                    activeEye = Camera.StereoscopicEye.Right;
                    break;
            }

            //Matrix4x4 viewProjMat = GL.GetGPUProjectionMatrix(context.camera.GetStereoProjectionMatrix(activeEye), false) * context.camera.worldToCameraMatrix;
            Matrix4x4 viewProjMat = GL.GetGPUProjectionMatrix(context.camera.projectionMatrix, false) * context.camera.worldToCameraMatrix;
            sheet.properties.SetMatrix("_ViewProjInv", viewProjMat.inverse);
            sheet.properties.SetMatrix("unity_CameraToWorld", context.camera.cameraToWorldMatrix);
            sheet.properties.SetMatrix("unity_CameraInvProjection", context.camera.projectionMatrix.inverse);

            sheet.properties.SetInt("_ShowRawDepthTexture", settings.showRawDepthTexture ? 1 : 0);
            sheet.properties.SetInt("_ShowRawDepthNormalsTexture", settings.showRawDepthNormalsTexture ? 1 : 0);
            sheet.properties.SetInt("_ShowRawMotionVectorsTexture", settings.showRawMotionVectorsTexture ? 1 : 0);
            sheet.properties.SetInt("_ShowLinearEyeDepth", settings.showLinearEyeDepth ? 1 : 0);
            sheet.properties.SetInt("_ShowLinear01Depth", settings.showLinear01Depth ? 1 : 0);
            sheet.properties.SetInt("_ShowViewNormals", settings.showViewNormals ? 1 : 0);
            sheet.properties.SetInt("_ShowWorldNormals", settings.showWorldNormals ? 1 : 0);
            sheet.properties.SetInt("_ShowViewPosition", settings.showViewPosition ? 1 : 0);
            sheet.properties.SetInt("_ShowWorldPosition", settings.showWorldPosition ? 1 : 0);

            context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);

            context.command.EndSample("Post Process");
        }
    }
}
