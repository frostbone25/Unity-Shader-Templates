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
        [KeywordEnum(CameraDepthNormals, 1 Tap Quad Intrinsics, Improved Quad Intrinsics, 3 Tap, 4 Tap, Improved, Accurate)] _NormalType("Normal Reconstruction Type", Float) = 0
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
            #pragma multi_compile _NORMALTYPE_CAMERADEPTHNORMALS _NORMALTYPE_3_TAP _NORMALTYPE_4_TAP _NORMALTYPE_IMPROVED _NORMALTYPE_ACCURATE _NORMALTYPE_1_TAP_QUAD_INTRINSICS _NORMALTYPE_IMPROVED_QUAD_INTRINSICS

            #pragma target 5.0
            #include "QuadIntrinsics.cginc"

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

            float rand(float co) { return frac(sin(co * (91.3458)) * 47453.5453); }
            float rand(float2 co) { return frac(sin(dot(co.xy, float2(12.9898, 78.233))) * 43758.5453); }
            float rand(float3 co) { return rand(co.xy + rand(co.z)); }

            float SampleDepth(float2 uv)
            {
                #if defined (_DEPTHTYPE_FROMCAMERADEPTH)
                    float4 rawCameraDepthTexture = tex2D(_CameraDepthTexture, uv);
                    return rawCameraDepthTexture.r;
                #elif defined (_DEPTHTYPE_FROMCAMERADEPTHNORMALS)
                    float4 rawCameraDepthNormalsTexture = tex2D(_CameraDepthNormalsTexture, uv);

                    //rawCameraDepthNormalsTexture = 1 - rawCameraDepthNormalsTexture;
                    //float decodedFloat = DecodeFloatRG(rawCameraDepthNormalsTexture.zw);
                    float decodedFloat = DecodeFloatRG(rawCameraDepthNormalsTexture.zw);

                    //decodedFloat += rand(uv) * 0.00001;
                    //decodedFloat = (QuadReadLaneAt(decodedFloat, uint2(0, 0)) + QuadReadLaneAt(decodedFloat, uint2(1, 0)) + QuadReadLaneAt(decodedFloat, uint2(0, 1)) + QuadReadLaneAt(decodedFloat, uint2(1, 1))) * 0.25;

                    //decodedFloat += rand(uv) * 0.0001;
                    //decodedFloat = decodedFloat * _ProjectionParams.w;
                    //decodedFloat = decodedFloat * _ZBufferParams.w;
                    //decodedFloat = decodedFloat * _ZBufferParams.z;
                    //decodedFloat = decodedFloat + _ProjectionParams.y;
                    //decodedFloat = UNITY_Z_0_FAR_FROM_CLIPSPACE(decodedFloat);
                    //decodedFloat *= 1.3563829787234042553191489361702;
                    //decodedFloat -= rand(uv) * 0.000005;
                    decodedFloat = Linear01Depth(decodedFloat);
                    //decodedFloat -= rand(uv) * 0.00001;
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
                float3 viewSpaceRay = mul(unity_CameraInvProjection, float4(uv * 2 - 1, 1, 1) * _ProjectionParams.z);
                float rawDepth = SampleDepth(uv);
                return viewSpaceRay * Linear01Depth(rawDepth);
            }

            float3 SampleViewNormals(float2 uv)
            {
                #if defined (_NORMALTYPE_CAMERADEPTHNORMALS)
                    float4 rawCameraDepthNormalsTexture = tex2D(_CameraDepthNormalsTexture, uv);
                    float3 computedViewNormals = DecodeViewNormalStereo(rawCameraDepthNormalsTexture);

                    return computedViewNormals;
                #elif defined (_NORMALTYPE_1_TAP_QUAD_INTRINSICS)
                    // get current pixel's view space position
                    half3 viewSpacePos_origin = viewSpacePosAtScreenUV(uv);

                    // get view space position at 1 pixel offsets in each major direction
                    half3 viewSpacePos_origin_topLeft = QuadReadLaneAt(viewSpacePos_origin, uint2(0, 0));
                    half3 viewSpacePos_origin_topRight = QuadReadLaneAt(viewSpacePos_origin, uint2(1, 0));
                    half3 viewSpacePos_origin_bottomLeft = QuadReadLaneAt(viewSpacePos_origin, uint2(0, 1));

                    // get the difference between the current and each offset position
                    half3 horizontalDifference = viewSpacePos_origin_topLeft - viewSpacePos_origin_topRight;
                    half3 verticalDifference = viewSpacePos_origin_topLeft - viewSpacePos_origin_bottomLeft;

                    // get view space normal from the cross product of the diffs
                    half3 viewNormal = normalize(cross(horizontalDifference, verticalDifference));

                    return viewNormal;
                #elif defined (_NORMALTYPE_IMPROVED_QUAD_INTRINSICS)
                    // get current pixel's view space position
                    half3 viewSpacePos_origin = viewSpacePosAtScreenUV(uv);
                    half3 viewSpacePos_up = viewSpacePosAtScreenUV(uv + float2(0, 1) * _CameraDepthTexture_TexelSize.xy);

                    // get view space position at 1 pixel offsets in each major direction
                    half3 viewSpacePos_origin_topLeft = QuadReadLaneAt(viewSpacePos_origin, uint2(0, 0));
                    half3 viewSpacePos_origin_topRight = QuadReadLaneAt(viewSpacePos_origin, uint2(1, 0));
                    half3 viewSpacePos_origin_bottomLeft = QuadReadLaneAt(viewSpacePos_origin, uint2(0, 1));
                    half3 viewSpacePos_origin_bottomRight = QuadReadLaneAt(viewSpacePos_origin, uint2(1, 1));

                    // get view space position at 1 pixel offsets in each major direction
                    half3 viewSpacePos_up_bottomLeft = QuadReadLaneAt(viewSpacePos_up, uint2(0, 0));

                    // get the difference between the current and each offset position
                    half3 leftDifference = viewSpacePos_origin_topLeft - viewSpacePos_origin_topRight;
                    half3 rightDifference = viewSpacePos_origin_topRight - viewSpacePos_origin_topLeft;
                    half3 downDifference = viewSpacePos_origin_bottomLeft - viewSpacePos_origin_topLeft;
                    half3 upDifference = viewSpacePos_up_bottomLeft - viewSpacePos_origin_topLeft;

                    // pick horizontal and vertical diff with the smallest z difference
                    half3 horizontalDifference = abs(leftDifference.z) < abs(rightDifference.z) ? leftDifference : rightDifference;
                    half3 verticalDifference = abs(downDifference.z) < abs(upDifference.z) ? downDifference : upDifference;

                    // get view space normal from the cross product of the diffs
                    half3 viewNormal = normalize(cross(horizontalDifference, verticalDifference));

                    return viewNormal;
                #elif defined (_NORMALTYPE_3_TAP)
                    // get current pixel's view space position
                    half3 viewSpacePos_origin = viewSpacePosAtScreenUV(uv);

                    // get view space position at 1 pixel offsets in each major direction
                    half3 viewSpacePos_right = viewSpacePosAtScreenUV(uv + float2(1, 0) * _CameraDepthTexture_TexelSize.xy);
                    half3 viewSpacePos_up = viewSpacePosAtScreenUV(uv + float2(0, 1) * _CameraDepthTexture_TexelSize.xy);

                    // get the difference between the current and each offset position
                    half3 horizontalDifference = viewSpacePos_right - viewSpacePos_origin;
                    half3 verticalDifference = viewSpacePos_up - viewSpacePos_origin;

                    // get view space normal from the cross product of the diffs
                    half3 viewNormal = normalize(cross(horizontalDifference, verticalDifference));

                    return viewNormal;
                #elif defined (_NORMALTYPE_4_TAP)
                    // get view space position at 1 pixel offsets in each major direction
                    half3 viewSpacePos_left = viewSpacePosAtScreenUV(uv + float2(-1, 0) * _CameraDepthTexture_TexelSize.xy); //shifted left
                    half3 viewSpacePos_right = viewSpacePosAtScreenUV(uv + float2(1, 0) * _CameraDepthTexture_TexelSize.xy); //shifted right
                    half3 viewSpacePos_down = viewSpacePosAtScreenUV(uv + float2(0, -1) * _CameraDepthTexture_TexelSize.xy); //shifted down
                    half3 viewSpacePos_up = viewSpacePosAtScreenUV(uv + float2(0, 1) * _CameraDepthTexture_TexelSize.xy); //shifted up

                    // get the difference between the current and each offset position
                    half3 horizontalDifference = viewSpacePos_right - viewSpacePos_left;
                    half3 verticalDifference = viewSpacePos_up - viewSpacePos_down;

                    // get view space normal from the cross product of the diffs
                    half3 viewNormal = normalize(cross(horizontalDifference, verticalDifference));

                    return viewNormal;
                #elif defined (_NORMALTYPE_IMPROVED)
                    // get current pixel's view space position
                    half3 viewSpacePos_origin = viewSpacePosAtScreenUV(uv);

                    // get view space position at 1 pixel offsets in each major direction
                    half3 viewSpacePos_left = viewSpacePosAtScreenUV(uv + float2(-1, 0) * _CameraDepthTexture_TexelSize.xy);
                    half3 viewSpacePos_right = viewSpacePosAtScreenUV(uv + float2(1, 0) * _CameraDepthTexture_TexelSize.xy);
                    half3 viewSpacePos_down = viewSpacePosAtScreenUV(uv + float2(0, -1) * _CameraDepthTexture_TexelSize.xy);
                    half3 viewSpacePos_up = viewSpacePosAtScreenUV(uv + float2(0, 1) * _CameraDepthTexture_TexelSize.xy);

                    // get the difference between the current and each offset position
                    half3 leftDifference = viewSpacePos_origin - viewSpacePos_left;
                    half3 rightDifference = viewSpacePos_right - viewSpacePos_origin;
                    half3 downDifference = viewSpacePos_origin - viewSpacePos_down;
                    half3 upDifference = viewSpacePos_up - viewSpacePos_origin;

                    // pick horizontal and vertical diff with the smallest z difference
                    half3 horizontalDifference = abs(leftDifference.z) < abs(rightDifference.z) ? leftDifference : rightDifference;
                    half3 verticalDifference = abs(downDifference.z) < abs(upDifference.z) ? downDifference : upDifference;

                    // get view space normal from the cross product of the two smallest offsets
                    half3 viewNormal = normalize(cross(horizontalDifference, verticalDifference));

                    return viewNormal;
                #elif defined (_NORMALTYPE_ACCURATE)
                    // current pixel's depth
                    float c = SampleDepth(uv);

                    // get current pixel's view space position
                    half3 viewSpacePos_origin = viewSpacePosAtScreenUV(uv);

                    // get view space position at 1 pixel offsets in each major direction
                    half3 viewSpacePos_left = viewSpacePosAtScreenUV(uv + float2(-1, 0) * _CameraDepthTexture_TexelSize.xy);
                    half3 viewSpacePos_right = viewSpacePosAtScreenUV(uv + float2(1, 0) * _CameraDepthTexture_TexelSize.xy);
                    half3 viewSpacePos_down = viewSpacePosAtScreenUV(uv + float2(0, -1) * _CameraDepthTexture_TexelSize.xy);
                    half3 viewSpacePos_up = viewSpacePosAtScreenUV(uv + float2(0, 1) * _CameraDepthTexture_TexelSize.xy);

                    // get the difference between the current and each offset position
                    half3 leftDifference = viewSpacePos_origin - viewSpacePos_left;
                    half3 rightDifference = viewSpacePos_right - viewSpacePos_origin;
                    half3 downDifference = viewSpacePos_origin - viewSpacePos_down;
                    half3 upDifference = viewSpacePos_up - viewSpacePos_origin;

                    // get depth values at 1 & 2 pixels offsets from current along the horizontal axis
                    half4 H = half4(
                        SampleDepth(uv + float2(-1, 0) * _CameraDepthTexture_TexelSize.xy),
                        SampleDepth(uv + float2(1, 0) * _CameraDepthTexture_TexelSize.xy),
                        SampleDepth(uv + float2(-2, 0) * _CameraDepthTexture_TexelSize.xy),
                        SampleDepth(uv + float2(2, 0) * _CameraDepthTexture_TexelSize.xy)
                    );

                    // get depth values at 1 & 2 pixels offsets from current along the vertical axis
                    half4 V = half4(
                        SampleDepth(uv + float2(0, -1) * _CameraDepthTexture_TexelSize.xy),
                        SampleDepth(uv + float2(0, 1) * _CameraDepthTexture_TexelSize.xy),
                        SampleDepth(uv + float2(0, -2) * _CameraDepthTexture_TexelSize.xy),
                        SampleDepth(uv + float2(0, 2) * _CameraDepthTexture_TexelSize.xy)
                    );

                    // current pixel's depth difference from slope of offset depth samples
                    // differs from original article because we're using non-linear depth values
                    // see article's comments
                    half2 he = abs((2 * H.xy - H.zw) - c);
                    half2 ve = abs((2 * V.xy - V.zw) - c);

                    // pick horizontal and vertical diff with the smallest depth difference from slopes
                    half3 horizontalDifference = he.x < he.y ? leftDifference : rightDifference;
                    half3 verticalDifference = ve.x < ve.y ? downDifference : upDifference;
                    //half3 horizontalDifference = half3(1, 1, 1);
                    //half3 verticalDifference = half3(1, 1, 1);

                    // get view space normal from the cross product of the best derivatives
                    half3 viewNormal = normalize(cross(horizontalDifference, verticalDifference));

                    return viewNormal;
                #endif
            }

            float4 fragment_base(vertexToFragment i) : SV_Target
            {
                //Single Pass Instanced Support
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                SETUP_QUAD_INTRINSICS(i.vertex)

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