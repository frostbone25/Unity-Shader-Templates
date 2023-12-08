using System;
using System.Collections;
using System.Collections.Generic;
using System.Net.NetworkInformation;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;

namespace PostProcessCompute
{
    [Serializable]
    [PostProcess(typeof(PostProcessComputeRenderer), PostProcessEvent.BeforeTransparent, "Custom/PostProcessCompute")]
    public sealed class PostProcessCompute : PostProcessEffectSettings
    {
        [Header("Setup")]
        public ComputeShaderParameter computeShader = new ComputeShaderParameter() { value = null };

        [Header("Rendering")]
        [Range(1, 32)] public IntParameter downsample = new IntParameter() { value = 1 };

        [Header("Raw Buffers")]
        public BoolParameter showRawDepthTexture = new BoolParameter() { value = false };
        public BoolParameter showRawDepthNormalsTexture = new BoolParameter() { value = false };
        public BoolParameter showRawMotionVectorsTexture = new BoolParameter() { value = false };

        [Header("Calculated Buffers")]
        public BoolParameter showLinearEyeDepth = new BoolParameter() { value = false };
        public BoolParameter showLinear01Depth = new BoolParameter() { value = false };
        public BoolParameter showViewNormals = new BoolParameter() { value = false };
        public BoolParameter showWorldNormals = new BoolParameter() { value = false };
        public BoolParameter showViewPosition = new BoolParameter() { value = false };
        public BoolParameter showWorldPosition = new BoolParameter() { value = false };
    }
}