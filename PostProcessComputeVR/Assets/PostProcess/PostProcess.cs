using System;
using System.Collections;
using System.Collections.Generic;
using System.Net.NetworkInformation;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;

namespace PostProcess
{
    [Serializable]
    [PostProcess(typeof(PostProcessRenderer), PostProcessEvent.BeforeTransparent, "Custom/PostProcess")]
    public sealed class PostProcess : PostProcessEffectSettings
    {
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