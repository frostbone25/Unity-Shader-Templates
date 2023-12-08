using System;
using System.Collections;
using System.Collections.Generic;
using System.Drawing;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.PostProcessing;
using UnityEngine.UIElements;

namespace PostProcessCompute
{
    public sealed class PostProcessComputeRenderer : PostProcessEffectRenderer<PostProcessCompute>
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
                postShader = Shader.Find("Hidden/PostProcessCompute");
                return;
            }

            PropertySheet sheet = context.propertySheets.Get(postShader);
            ComputeShader computeShader = settings.computeShader.value;
            Texture cameraDepthTexture = Shader.GetGlobalTexture("_CameraDepthTexture");
            Texture cameraDepthNormalsTexture = Shader.GetGlobalTexture("_CameraDepthNormalsTexture");
            Texture cameraMotionVectorsTexture = Shader.GetGlobalTexture("_CameraMotionVectorsTexture");

            if (computeShader == null || cameraDepthTexture == null || cameraDepthNormalsTexture == null || cameraMotionVectorsTexture == null)
                return;

            context.command.BeginSample("Post Process Compute");

            int depthBits = 16; //16, 24, 32
            int resolutionX = context.width / settings.downsample.value;
            int resolutionY = context.height / settings.downsample.value;

            //|||||||||||||||||||||||||| COMPUTE SHADER ||||||||||||||||||||||||||
            //|||||||||||||||||||||||||| COMPUTE SHADER ||||||||||||||||||||||||||
            //|||||||||||||||||||||||||| COMPUTE SHADER ||||||||||||||||||||||||||
            if (computeWrite != null)
            {
                if (computeWrite.IsCreated())
                    computeWrite.Release();
            }

            computeWrite = new RenderTexture(resolutionX, resolutionY, depthBits, context.sourceFormat, 0);
            computeWrite.filterMode = FilterMode.Bilinear;
            computeWrite.enableRandomWrite = true;
            computeWrite.Create();

            int computeKernel = computeShader.FindKernel("ComputeShaderMain");

            computeShader.SetTexture(computeKernel, "_CameraDepthTexture", cameraDepthTexture);
            computeShader.SetTexture(computeKernel, "_CameraDepthNormalsTexture", cameraDepthNormalsTexture);
            computeShader.SetTexture(computeKernel, "_CameraMotionVectorsTexture", cameraMotionVectorsTexture);

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
            computeShader.SetMatrix("_ViewProjInv", viewProjMat.inverse);
            computeShader.SetMatrix("unity_CameraToWorld", context.camera.cameraToWorldMatrix);

            computeShader.SetBool("_ShowRawDepthTexture", settings.showRawDepthTexture);
            computeShader.SetBool("_ShowRawDepthNormalsTexture", settings.showRawDepthNormalsTexture);
            computeShader.SetBool("_ShowRawMotionVectorsTexture", settings.showRawMotionVectorsTexture);
            computeShader.SetBool("_ShowLinearEyeDepth", settings.showLinearEyeDepth);
            computeShader.SetBool("_ShowLinear01Depth", settings.showLinear01Depth);
            computeShader.SetBool("_ShowViewNormals", settings.showViewNormals);
            computeShader.SetBool("_ShowWorldNormals", settings.showWorldNormals);
            computeShader.SetBool("_ShowViewPosition", settings.showViewPosition);
            computeShader.SetBool("_ShowWorldPosition", settings.showWorldPosition);

            context.command.SetComputeTextureParam(computeShader, computeKernel, "_ComputeShaderRenderTexture", computeWrite);
            context.command.SetComputeVectorParam(computeShader, "_ComputeShaderRenderTextureResolution", new Vector2(computeWrite.width, computeWrite.height));

            context.command.DispatchCompute(computeShader, computeKernel, Mathf.CeilToInt(resolutionX / 8f), Mathf.CeilToInt(resolutionY / 8f), 1);

            //|||||||||||||||||||||||||| POST PROCESS SHADER ||||||||||||||||||||||||||
            //|||||||||||||||||||||||||| POST PROCESS SHADER ||||||||||||||||||||||||||
            //|||||||||||||||||||||||||| POST PROCESS SHADER ||||||||||||||||||||||||||

            sheet.properties.SetTexture("_ComputeShaderResult", computeWrite);

            context.command.BlitFullscreenTriangle(computeWrite, context.destination, sheet, 0);

            context.command.EndSample("Post Process Compute");
        }
    }
}
