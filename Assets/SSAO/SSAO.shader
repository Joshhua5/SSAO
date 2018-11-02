// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Hidden/SSAO"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
	}
		SubShader
	{
		Tags { "RenderType" = "Opaque"}
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "SSAO.cginc"

			sampler2D _CameraGBufferTexture2;
			sampler2D _CameraDepthTexture;
			sampler2D _MainTex;

			Texture2D _RandomTex;
			Texture2D _OcclusionFunction;
			SamplerState sampler_linear_repeat;
			SamplerState sampler_linear_clamp;

			uniform float _Range;
			uniform float _Intensity;

			uniform float4x4 projToView;
			uniform float4x4 viewToWorld;
			uniform float4x4 worldToView;
			uniform float4x4 viewToProj;

			float2 ScreenToClip(float2 value) {
				return (value * 2) - 1;
			}

			float2 ClipToScreen(float2 value) {
				return (value + 1) * 0.5;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float pixelDepth = tex2D(_CameraDepthTexture, i.uv); 

				if (pixelDepth == 0)
					return tex2D(_MainTex, i.uv);

				//depth = LinearEyeDepth(depth);

				// Calculate the world position of this pixel    
				const float2 pixelSS = i.uv;
				const float2 pixelCS = ScreenToClip(i.uv);
				const float3 pixelCSd = float3(pixelCS, pixelDepth); // Clip Space with Depth
				const float3 pixelVS = mul(projToView, pixelCSd);

				const float3 pixelWS = mul(viewToWorld, pixelVS).xyz;
				 
				// use a set of random offset vectors to sample from the surrounding world

				// Prime the random
				float3 random = _RandomTex.Sample(sampler_linear_repeat, pixelSS);
				 
				const int SAMPLE_COUNT = 128;
				int SAMPLED_COUNT = 0;
				float occlusion = 0; 

				float3 normal = tex2D(_CameraGBufferTexture2, i.uv);
				 
				// How many samples to take per pixel
				// Sample the surrounding pixels using the worldspace offset
				for (int index = 0; index < SAMPLE_COUNT; index++) {
					random = _RandomTex.Sample(sampler_linear_repeat, pixelSS + random);

					// This random vector needs to prevent the self occlusion
					// we handle this by dot producting with the normal and inverting if occluded
					if (dot(normal, random) < 0)
						random *= float3(-1, -1, -1);

					// Convert World space back to Screen Space 
					float3 sampleWS = pixelWS + random * _Range;

					float3 sampleVS = mul(worldToView, sampleWS);
					float3 sampleCS = mul(viewToProj, sampleVS);
					float2 sampleSS = ClipToScreen(sampleCS);

					float sampledDepth = tex2D(_CameraDepthTexture, sampleSS);
					
					float3 sampledCSd = float3(sampleCS.xy, sampledDepth);
					float3 sampledVS = mul(projToView, sampledCSd);
					float3 sampledWS = mul(viewToWorld, sampledVS);
					
					/*
					float sampleDepthDelta = length((sampleWS - sampledWS)) / _Range;  
					float occluded = (_OcclusionFunction.Sample(sampler_linear_clamp, float2(sampleDepthDelta, 0)));  
					if (sampleDepthDelta > 0) {
						occlusion += occluded;
						SAMPLED_COUNT += 1.0f;
					}
					*/
					  
					float depthWorldDelta = length(pixelWS - sampledWS) / _Range;
					float depthOnlyDelta = (sampledDepth - pixelDepth) / _Range;

					//occlusion += (_OcclusionFunction.Sample(sampler_linear_clamp, float2(depthWorldDelta, 0)));
					//occlusion += (_OcclusionFunction.Sample(sampler_linear_clamp, float2(depthOnlyDelta, 0))); 
					//SAMPLED_COUNT += 1.0f;

					// Attempt  2
					// Sample the worldspace check if the sampled space is infront of the sampleWS then we have occlusion
					//  

					float occluded = (_OcclusionFunction.Sample(sampler_linear_clamp, float2(depthOnlyDelta, 0))); 

					return float4(sampleWS, 1);

					if (sampleWS.z < sampledDepth) {   
						occlusion += occluded;
						SAMPLED_COUNT += 1.0f;
					}
				}

				const float finalOcclusion = 1.0 - ((SAMPLED_COUNT == 0) ? 0 : (occlusion * _Intensity / SAMPLED_COUNT));
				 
				return finalOcclusion;

				return tex2D(_MainTex, i.uv) * finalOcclusion; 
			}
			ENDCG
		}
	}
}
