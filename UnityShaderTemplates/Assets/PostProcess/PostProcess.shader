Shader "Hidden/PostProcess"
{
	SubShader
	{
		Cull Off ZWrite Off ZTest Always

		//||||||||||||||||||||||||||||||||| PASS 0: BLITTING RENDER TARGET COLOR |||||||||||||||||||||||||||||||||
		//||||||||||||||||||||||||||||||||| PASS 0: BLITTING RENDER TARGET COLOR |||||||||||||||||||||||||||||||||
		//||||||||||||||||||||||||||||||||| PASS 0: BLITTING RENDER TARGET COLOR |||||||||||||||||||||||||||||||||
		Pass
		{
			HLSLPROGRAM
			#pragma vertex vertex_base
			#pragma fragment fragment_base
			#pragma fragmentoption ARB_precision_hint_fastest
			#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"

			TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);

			TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);
			TEXTURE2D_SAMPLER2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture);
			TEXTURE2D_SAMPLER2D(_CameraMotionVectorsTexture, sampler_CameraMotionVectorsTexture);

			//Raw Buffers
			int _ShowRawDepthTexture;
			int _ShowRawDepthNormalsTexture;
			int _ShowRawMotionVectorsTexture;

			//Calculated Buffers
			int _ShowLinearEyeDepth;
			int _ShowLinear01Depth;
			int _ShowViewNormals;
			int _ShowWorldNormals;
			int _ShowViewPosition;
			int _ShowWorldPosition;

			float4x4 _ViewProjInv;
			float4x4 unity_CameraToWorld;
			float4x4 unity_CameraInvProjection;

			struct meshData
			{
				float3 vertex : POSITION;
				float4 texcoord : TEXCOORD;
			};

			struct vertexToFragment
			{
				float4 vertex : SV_POSITION;
				float2 texcoord : TEXCOORD0;
				float2 texcoordStereo : TEXCOORD1;

				#if STEREO_INSTANCING_ENABLED
					uint stereoTargetEyeIndex : SV_RenderTargetArrayIndex;
				#endif
			};

			vertexToFragment vertex_base(meshData v)
			{
				vertexToFragment o;

				o.vertex = float4(v.vertex.xy, 0.0, 1.0);
				o.texcoord = TransformTriangleVertexToUV(v.vertex.xy);

				#if UNITY_UV_STARTS_AT_TOP
					o.texcoord = o.texcoord * float2(1.0, -1.0) + float2(0.0, 1.0);
				#endif

				o.texcoordStereo = TransformStereoScreenSpaceTex(o.texcoord, 1.0);

				return o;
			}

			float4 fragment_base(vertexToFragment i) : SV_Target
			{
				float2 uv = i.texcoordStereo.xy;
				float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);

				float cameraDepthColor = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv);
				float4 cameraDepthNormalsColor = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, uv);
				float2 cameraMotionVectorsColor = SAMPLE_TEXTURE2D(_CameraMotionVectorsTexture, sampler_CameraMotionVectorsTexture, uv);

				//color.rgb = 1 - color.rgb;

				//------------------------------- RAW DEPTH TEXTURE -------------------------------
				if (_ShowRawDepthTexture > 0)
				{
					return float4(cameraDepthColor, 0, 0, 1);
				}

				//------------------------------- RAW DEPTH NORMALS TEXTURE -------------------------------
				if (_ShowRawDepthNormalsTexture > 0)
				{
					return float4(cameraDepthNormalsColor.rgb, 1);
				}

				//------------------------------- RAW MOTION VECTORS TEXTURE -------------------------------
				if (_ShowRawMotionVectorsTexture > 0)
				{
					return float4(cameraMotionVectorsColor, 0, 1);
				}

				//------------------------------- LINEAR 01 DEPTH -------------------------------
				if (_ShowLinear01Depth > 0)
				{
					float linear01Depth = Linear01Depth(cameraDepthColor);

					return float4(linear01Depth, linear01Depth, linear01Depth, 1);
				}

				//------------------------------- LINEAR EYE DEPTH -------------------------------
				if (_ShowLinearEyeDepth > 0)
				{
					float linearEyeDepth = LinearEyeDepth(cameraDepthColor);

					return float4(linearEyeDepth, linearEyeDepth, linearEyeDepth, 1);
				}

				//------------------------------- VIEW NORMALS -------------------------------
				if (_ShowViewNormals > 0)
				{
					float3 computedViewNormals = DecodeViewNormalStereo(cameraDepthNormalsColor);

					return float4(computedViewNormals, 1);
				}

				//------------------------------- WORLD NORMALS -------------------------------
				if (_ShowWorldNormals > 0)
				{
					float3 computedViewNormals = DecodeViewNormalStereo(cameraDepthNormalsColor);
					float3 computedWorldNormals = mul((float3x3)unity_CameraToWorld, computedViewNormals) * float3(1.0, 1.0, -1.0);

					return float4(computedWorldNormals, 1);
				}

				//------------------------------- VIEW POSITION -------------------------------
				if (_ShowViewPosition > 0)
				{
					float3 computedViewPosition = mul(unity_CameraInvProjection, float4(uv * 2 - 1, 1, 1) * _ProjectionParams.z);
					computedViewPosition *= Linear01Depth(cameraDepthColor);

					return float4(computedViewPosition, 1);
				}

				//------------------------------- WORLD POSITION -------------------------------
				if (_ShowWorldPosition > 0)
				{
					float4 computedWorldPosition = float4(0, 0, 0, 1);
					computedWorldPosition.x = (uv.x * 2.0f) - 1.0f;
					computedWorldPosition.y = (uv.y * 2.0f) - 1.0f;
					computedWorldPosition.z = cameraDepthColor.r;
					computedWorldPosition = mul(_ViewProjInv, computedWorldPosition);
					computedWorldPosition /= computedWorldPosition.w;

					return float4(computedWorldPosition.xyz, 1);
				}

				return color;
			}

			ENDHLSL
		}
	}
}