Shader "Hidden/PostProcessCompute"
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
				float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoordStereo.xy);

				//color.rgb = 1 - color.rgb;

				return color;
			}

			ENDHLSL
		}
	}
}