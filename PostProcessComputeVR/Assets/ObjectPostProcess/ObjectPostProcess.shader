/*
* Sources
* - https://gist.github.com/bgolus/a07ed65602c009d5e2f753826e8078a0
*/

Shader "Unlit/ObjectPostProcess"
{
    Properties
    {
        [KeywordEnum(None, RawDepth, RawDepthNormals, RawMotionVectors, LinearEyeDepth, Linear01Depth, ViewNormals, WorldNormals, ViewPosition, WorldPosition)] _ShowBuffer("Show Buffer", Float) = 0
        [KeywordEnum(FromCameraDepth, FromCameraDepthNormals)] _DepthType("Depth Type", Float) = 0
        [KeywordEnum(CameraDepthNormals, 3 Tap, 4 Tap, Improved, Accurate)] _NormalType("Normal Reconstruction Type", Float) = 0
    }
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque" 
            "Queue" = "Transparent+2000"
        }

        Cull Off
        ZWrite Off
        ZTest Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vertex_base
            #pragma fragment fragment_base

            #pragma multi_compile_instancing

            #pragma multi_compile _SHOWBUFFER_NONE _SHOWBUFFER_RAWDEPTH _SHOWBUFFER_RAWDEPTHNORMALS _SHOWBUFFER_RAWMOTIONVECTORS _SHOWBUFFER_LINEAREYEDEPTH _SHOWBUFFER_LINEAR01DEPTH _SHOWBUFFER_VIEWNORMALS _SHOWBUFFER_WORLDNORMALS _SHOWBUFFER_VIEWPOSITION _SHOWBUFFER_WORLDPOSITION
            #pragma multi_compile _DEPTHTYPE_FROMCAMERADEPTH _DEPTHTYPE_FROMCAMERADEPTHNORMALS
            #pragma multi_compile _NORMALTYPE_CAMERADEPTHNORMALS _NORMALTYPE_3_TAP _NORMALTYPE_4_TAP _NORMALTYPE_IMPROVED _NORMALTYPE_ACCURATE

            #include "UnityCG.cginc"

            UNITY_DECLARE_SCREENSPACE_TEXTURE(_CameraDepthTexture);
            float4 _CameraDepthTexture_TexelSize;

            UNITY_DECLARE_SCREENSPACE_TEXTURE(_CameraDepthNormalsTexture);
            float4 _CameraDepthNormalsTexture_TexelSize;

            UNITY_DECLARE_SCREENSPACE_TEXTURE(_CameraMotionVectorsTexture);
            float4 _CameraMotionVectorsTexture_TexelSize;

            struct meshData
            {
                float4 vertex : POSITION;

                //Single Pass Instanced Support
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct vertexToFragment
            {
                float4 vertex : SV_POSITION;
                float4 screenPos : TEXCOORD0;
                float3 camRelativeWorldPos : TEXCOORD1;

                //Single Pass Instanced Support
                UNITY_VERTEX_OUTPUT_STEREO
            };

            vertexToFragment vertex_base(meshData v)
            {
                vertexToFragment o;

                //Single Pass Instanced Support
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(vertexToFragment, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.screenPos = UnityStereoTransformScreenSpaceTex(ComputeScreenPos(o.vertex));
                o.camRelativeWorldPos = mul(unity_ObjectToWorld, fixed4(v.vertex.xyz, 1.0)).xyz - _WorldSpaceCameraPos;

                return o;
            }

            float SampleDepth(float2 uv)
            {
                #if defined (_DEPTHTYPE_FROMCAMERADEPTH)
                    float4 rawCameraDepthTexture = tex2D(_CameraDepthTexture, uv);
                    return rawCameraDepthTexture.r;
                #elif defined (_DEPTHTYPE_FROMCAMERADEPTHNORMALS)
                    float4 rawCameraDepthNormalsTexture = tex2D(_CameraDepthNormalsTexture, uv);

                    //rawCameraDepthNormalsTexture = 1 - rawCameraDepthNormalsTexture;
                    float decodedFloat = DecodeFloatRG(rawCameraDepthNormalsTexture.zw);
                    //decodedFloat = decodedFloat * _ProjectionParams.w;
                    //decodedFloat = decodedFloat * _ZBufferParams.w;
                    //decodedFloat = decodedFloat * _ZBufferParams.z;
                    //decodedFloat = decodedFloat + _ProjectionParams.y;
                    //decodedFloat = UNITY_Z_0_FAR_FROM_CLIPSPACE(decodedFloat);
                    decodedFloat = Linear01Depth(decodedFloat);

                    //Linear01Depth(float z)
                    //LinearEyeDepth(float z)

                    return decodedFloat;
                #endif
            }

            // inspired by keijiro's depth inverse projection
            // https://github.com/keijiro/DepthInverseProjection
            // constructs view space ray at the far clip plane from the screen uv
            // then multiplies that ray by the linear 01 depth
            float3 viewSpacePosAtScreenUV(float2 uv)
            {
                float3 viewSpaceRay = mul(unity_CameraInvProjection, float4(uv * 2.0 - 1.0, 1.0, 1.0) * _ProjectionParams.z);
                float rawDepth = SampleDepth(uv);
                return viewSpaceRay * Linear01Depth(rawDepth);
            }

            float3 viewSpacePosAtPixelPosition(float2 vpos)
            {
                //float2 uv = vpos * _CameraDepthTexture_TexelSize.xy;
                //return viewSpacePosAtScreenUV(uv);
                return viewSpacePosAtScreenUV(vpos);
            }

            float3 SampleViewNormals(float2 uv)
            {
                #if defined (_NORMALTYPE_CAMERADEPTHNORMALS)
                    float4 rawCameraDepthNormalsTexture = tex2D(_CameraDepthNormalsTexture, uv);
                    float3 computedViewNormals = DecodeViewNormalStereo(rawCameraDepthNormalsTexture);

                    return computedViewNormals;
                #elif defined (_NORMALTYPE_3_TAP)
                    // get current pixel's view space position
                    half3 viewSpacePos_c = viewSpacePosAtPixelPosition(uv + float2(0.0, 0.0) * _CameraDepthTexture_TexelSize.xy);

                    // get view space position at 1 pixel offsets in each major direction
                    half3 viewSpacePos_r = viewSpacePosAtPixelPosition(uv + float2(1.0, 0.0) * _CameraDepthTexture_TexelSize.xy);
                    half3 viewSpacePos_u = viewSpacePosAtPixelPosition(uv + float2(0.0, 1.0) * _CameraDepthTexture_TexelSize.xy);

                    // get the difference between the current and each offset position
                    half3 hDeriv = viewSpacePos_r - viewSpacePos_c;
                    half3 vDeriv = viewSpacePos_u - viewSpacePos_c;

                    // get view space normal from the cross product of the diffs
                    half3 viewNormal = normalize(cross(hDeriv, vDeriv));

                    return viewNormal;
                #elif defined (_NORMALTYPE_4_TAP)
                    // get view space position at 1 pixel offsets in each major direction
                    half3 viewSpacePos_l = viewSpacePosAtPixelPosition(uv + float2(-1.0, 0.0) * _CameraDepthTexture_TexelSize.xy);
                    half3 viewSpacePos_r = viewSpacePosAtPixelPosition(uv + float2(1.0, 0.0) * _CameraDepthTexture_TexelSize.xy);
                    half3 viewSpacePos_d = viewSpacePosAtPixelPosition(uv + float2(0.0, -1.0) * _CameraDepthTexture_TexelSize.xy);
                    half3 viewSpacePos_u = viewSpacePosAtPixelPosition(uv + float2(0.0, 1.0) * _CameraDepthTexture_TexelSize.xy);

                    // get the difference between the current and each offset position
                    half3 hDeriv = viewSpacePos_r - viewSpacePos_l;
                    half3 vDeriv = viewSpacePos_u - viewSpacePos_d;

                    // get view space normal from the cross product of the diffs
                    half3 viewNormal = normalize(cross(hDeriv, vDeriv));

                    return viewNormal;
                #elif defined (_NORMALTYPE_IMPROVED)
                    // get current pixel's view space position
                    half3 viewSpacePos_c = viewSpacePosAtPixelPosition(uv + float2(0.0, 0.0) * _CameraDepthTexture_TexelSize.xy);

                    // get view space position at 1 pixel offsets in each major direction
                    half3 viewSpacePos_l = viewSpacePosAtPixelPosition(uv + float2(-1.0, 0.0) * _CameraDepthTexture_TexelSize.xy);
                    half3 viewSpacePos_r = viewSpacePosAtPixelPosition(uv + float2(1.0, 0.0) * _CameraDepthTexture_TexelSize.xy);
                    half3 viewSpacePos_d = viewSpacePosAtPixelPosition(uv + float2(0.0, -1.0) * _CameraDepthTexture_TexelSize.xy);
                    half3 viewSpacePos_u = viewSpacePosAtPixelPosition(uv + float2(0.0, 1.0) * _CameraDepthTexture_TexelSize.xy);

                    // get the difference between the current and each offset position
                    half3 l = viewSpacePos_c - viewSpacePos_l;
                    half3 r = viewSpacePos_r - viewSpacePos_c;
                    half3 d = viewSpacePos_c - viewSpacePos_d;
                    half3 u = viewSpacePos_u - viewSpacePos_c;

                    // pick horizontal and vertical diff with the smallest z difference
                    half3 hDeriv = abs(l.z) < abs(r.z) ? l : r;
                    half3 vDeriv = abs(d.z) < abs(u.z) ? d : u;

                    // get view space normal from the cross product of the two smallest offsets
                    half3 viewNormal = normalize(cross(hDeriv, vDeriv));

                    return viewNormal;
                #elif defined (_NORMALTYPE_ACCURATE)
                    // current pixel's depth
                    float c = SampleDepth(uv);

                    // get current pixel's view space position
                    half3 viewSpacePos_c = viewSpacePosAtScreenUV(uv);

                    // get view space position at 1 pixel offsets in each major direction
                    half3 viewSpacePos_l = viewSpacePosAtScreenUV(uv + float2(-1.0, 0.0) * _CameraDepthTexture_TexelSize.xy);
                    half3 viewSpacePos_r = viewSpacePosAtScreenUV(uv + float2(1.0, 0.0) * _CameraDepthTexture_TexelSize.xy);
                    half3 viewSpacePos_d = viewSpacePosAtScreenUV(uv + float2(0.0, -1.0) * _CameraDepthTexture_TexelSize.xy);
                    half3 viewSpacePos_u = viewSpacePosAtScreenUV(uv + float2(0.0, 1.0) * _CameraDepthTexture_TexelSize.xy);

                    // get the difference between the current and each offset position
                    half3 l = viewSpacePos_c - viewSpacePos_l;
                    half3 r = viewSpacePos_r - viewSpacePos_c;
                    half3 d = viewSpacePos_c - viewSpacePos_d;
                    half3 u = viewSpacePos_u - viewSpacePos_c;

                    // get depth values at 1 & 2 pixels offsets from current along the horizontal axis
                    half4 H = half4(
                        SampleDepth(uv + float2(-1.0, 0.0) * _CameraDepthTexture_TexelSize.xy),
                        SampleDepth(uv + float2(1.0, 0.0) * _CameraDepthTexture_TexelSize.xy),
                        SampleDepth(uv + float2(-2.0, 0.0) * _CameraDepthTexture_TexelSize.xy),
                        SampleDepth(uv + float2(2.0, 0.0) * _CameraDepthTexture_TexelSize.xy)
                    );

                    // get depth values at 1 & 2 pixels offsets from current along the vertical axis
                    half4 V = half4(
                        SampleDepth(uv + float2(0.0, -1.0) * _CameraDepthTexture_TexelSize.xy),
                        SampleDepth(uv + float2(0.0, 1.0) * _CameraDepthTexture_TexelSize.xy),
                        SampleDepth(uv + float2(0.0, -2.0) * _CameraDepthTexture_TexelSize.xy),
                        SampleDepth(uv + float2(0.0, 2.0) * _CameraDepthTexture_TexelSize.xy)
                    );

                    // current pixel's depth difference from slope of offset depth samples
                    // differs from original article because we're using non-linear depth values
                    // see article's comments
                    half2 he = abs((2 * H.xy - H.zw) - c);
                    half2 ve = abs((2 * V.xy - V.zw) - c);

                    // pick horizontal and vertical diff with the smallest depth difference from slopes
                    half3 hDeriv = he.x < he.y ? l : r;
                    half3 vDeriv = ve.x < ve.y ? d : u;

                    // get view space normal from the cross product of the best derivatives
                    half3 viewNormal = normalize(cross(hDeriv, vDeriv));

                    return viewNormal;
                #endif
            }

            float4 fragment_base(vertexToFragment i) : SV_Target
            {
                //Single Pass Instanced Support
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float2 screenUV = i.screenPos.xy / i.screenPos.w;

                #if UNITY_UV_STARTS_AT_TOP
                    if (_CameraDepthTexture_TexelSize.y < 0)
                        screenUV.y = 1 - screenUV.y;
                #endif

                #if UNITY_SINGLE_PASS_STEREO
                    // If Single-Pass Stereo mode is active, transform the
                    // coordinates to get the correct output UV for the current eye.
                    float4 scaleOffset = unity_StereoScaleOffset[unity_StereoEyeIndex];
                    screenUV = (screenUV - scaleOffset.zw) / scaleOffset.xy;
                #endif

                #if defined (_SHOWBUFFER_RAWDEPTH)
                    float4 rawCameraDepthTexture = tex2D(_CameraDepthTexture, screenUV);
                    return float4(rawCameraDepthTexture.rgb, 1);
                #endif

                #if defined (_SHOWBUFFER_RAWDEPTHNORMALS)
                    float4 rawCameraDepthNormalsTexture = tex2D(_CameraDepthNormalsTexture, screenUV);
                    return float4(rawCameraDepthNormalsTexture.rgb, 1);
                #endif

                #if defined (_SHOWBUFFER_RAWMOTIONVECTORS)
                    float4 rawCameraMotionVectorsTexture = tex2D(_CameraMotionVectorsTexture, screenUV);
                    return float4(rawCameraMotionVectorsTexture.rgb, 1);
                #endif

                #if defined (_SHOWBUFFER_LINEAREYEDEPTH)
                    float rawDepth = SampleDepth(screenUV);
                    float linearEyeDepth = LinearEyeDepth(rawDepth);

                    return float4(linearEyeDepth, linearEyeDepth, linearEyeDepth, 1);
                #endif

                #if defined (_SHOWBUFFER_LINEAR01DEPTH)
                    float rawDepth = SampleDepth(screenUV);
                    float linear01Depth = Linear01Depth(rawDepth);

                    return float4(linear01Depth, linear01Depth, linear01Depth, 1);
                #endif

                #if defined (_SHOWBUFFER_VIEWNORMALS)
                    float3 computedViewNormals = SampleViewNormals(screenUV);

                    return float4(computedViewNormals, 1);
                #endif

                #if defined (_SHOWBUFFER_WORLDNORMALS)
                    float3 computedViewNormals = SampleViewNormals(screenUV);
                    //float3 computedWorldNormals = mul((float3x3)unity_CameraToWorld, computedViewNormals) * float3(1.0, 1.0, -1.0);
                    float3 computedWorldNormals = mul((float3x3)unity_MatrixInvV, computedViewNormals) * float3(1.0, 1.0, -1.0);

                    return float4(computedWorldNormals, 1);
                #endif

                #if defined (_SHOWBUFFER_VIEWPOSITION)
                    float3 computedViewPosition = float3(0, 0, 0);
                    computedViewPosition.x = (screenUV.x * 2.0f) - 1.0f;
                    computedViewPosition.y = (screenUV.y * 2.0f) - 1.0f;

                    float rawDepth = SampleDepth(screenUV);
                    computedViewPosition.z = LinearEyeDepth(rawDepth);
 
                    computedViewPosition.xy *= computedViewPosition.z;

                    return float4(computedViewPosition, 1);
                #endif

                #if defined (_SHOWBUFFER_WORLDPOSITION)
                    float rawDepth = SampleDepth(screenUV);
                    float linearDepth = LinearEyeDepth(rawDepth);
                    float3 cameraWorldPositionViewPlane = i.camRelativeWorldPos.xyz / dot(i.camRelativeWorldPos.xyz, unity_WorldToCamera._m20_m21_m22);
                    float3 computedWorldPosition = cameraWorldPositionViewPlane * linearDepth + _WorldSpaceCameraPos;

                    return float4(computedWorldPosition, 1);
                #endif


                return float4(0.5, 0.5, 0, 1);
            }
            ENDCG
        }
    }
}
