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
			#pragma vertex vertexShader
			#pragma fragment fragmentShader
			 
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

			uniform float4x4 clipToView;
			uniform float4x4 viewToWorld;
			uniform float4x4 worldToView;
			uniform float4x4 viewToClip;
			  
			float2 ScreenToClip(float2 value) {
				return (value * 2) - 1;
			}

			float2 ClipToScreen(float2 value) {
				return (value + 1) * 0.5;
			}
			 
			inline half occlusionFunction(half value) {
				return pow(1 - value, 3);
			}  

			v2f vertexShader(appdata i) {
				// Projection Settings
				const float far = _ProjectionParams.z;
				float2 orthoSize = unity_OrthoParams.xy;
				const float isOrtho = unity_OrthoParams.w; 
				  
				// Creates a single triangle that covers the whole screen,
				// the triangle goes to 3, so that the face of triangle is within clip space -1, 1
				float x = (i.vertexID != 1) ? -1 : 3;
				float y = (i.vertexID == 2) ? -3 : 1;
				float4 vertexPos = float4(x, y, 1, 1); 

				// Calculate a ray going from the camera to the far plan
				// We use the far plane because we later multiple by the linear pixelDepth
				// with 1 being the far plane and 0 being the near. 
				// therefor using the far we can get the world space depth
				float3 rayPerspective = mul(unity_CameraInvProjection, vertexPos.xyzz * far).xyz;
				float3 rayOrtho = float3(orthoSize * vertexPos.xy, 0);

				v2f o; 

				o.position = float4(vertexPos.x, -vertexPos.y, 1, 1);
				o.uv = (vertexPos.xy + 1) / 2;
				o.ray = lerp(rayPerspective, rayOrtho, isOrtho);

				return o; 
			} 

			half3 fragmentShader(v2f i) : SV_Target {
				float near = _ProjectionParams.y;
				float far = _ProjectionParams.z;
				float isOrtho = unity_OrthoParams.w;
				  
				const float pixelDepth = tex2D(_CameraDepthTexture, i.uv);
				const float3 pixelColor = tex2D(_MainTex, i.uv);

				if (pixelDepth == 0)
					return pixelColor;

				float3 vertexPosPerspective = i.ray * Linear01Depth(pixelDepth);
				  
				//float depthOrtho = lerp(near, far, pixelDepth);
				//float3 vertexPosOrtho = float3(i.ray.xy, depthOrtho);

				float3 pixelVS = vertexPosPerspective;// lerp(vertexPosPerspective, vertexPosOrtho, isOrtho);
				float3 pixelWS = mul(viewToWorld, float4(pixelVS, 1)).xyz;
				 
				// Prime the random
				float3 random = _RandomTex.Sample(sampler_linear_repeat, i.uv);
				float3 normal = (tex2D(_CameraGBufferTexture2, i.uv) - 0.5) * 2; 

				const int SAMPLE_COUNT = 128;
				int SAMPLED_COUNT = 0;
				float occlusion = 0;
				 
				// How many samples to take per pixel
				// Sample the surrounding pixels using the worldspace offset
				for (int index = 0; index < SAMPLE_COUNT; index++) {
					random = _RandomTex.Sample(sampler_linear_repeat, i.uv + random);

					// This random vector needs to prevent the self occlusion
					// we handle this by dot producting with the normal and inverting if occluded
					if (dot(normal, random) < 0)
						random *= float3(-1, -1, -1);

					// Convert World space back to Screen Space 

					// It is possible that since the pixelWS isn't true worldspace, that the _Range has no depth taken into account
					// We need to properly convert the screen space pixel into worldspace to do this.
					float3 sampleWS = pixelWS + random * _Range;  
					//sampleWS.z = Linear01Depth(sampleWS.z);
										
					const float4 sampleVS = mul(worldToView, float4(sampleWS.xyz, 1)); 
					const float4 sampleCS = mul(viewToClip, sampleVS);
					const float2 sampleSS = ClipToScreen(sampleCS.xy / sampleCS.w);
					 
					// Sample the depth at this position
					const float sampledDepth = -1 * far * Linear01Depth(tex2D(_CameraDepthTexture, sampleSS));

					// Sample depth is in worldspace
					// Sampled depth is in view space
					float4 sampledVS = float4(sampleVS.xy, sampledDepth, 1);
					float4 sampledWS = mul(viewToWorld, sampledVS / sampledVS.w); 
					    
					// If the sampled depth is infront of the sample then it's occluded 
					// Do the occlusion check in ViewSpace 
					const bool isOccluded = sampledVS.z > sampleVS.z; 
					const float sampleDepthDelta = length(sampledWS - sampleWS);
					
					//return sampleDepthDelta; 

					// Has to be outside the if statement otherwise unity crashes
					//float occluded = _OcclusionFunction.Sample(sampler_linear_clamp, float2(sampleDepthDelta, 0));

					//float occluded = 1 - smoothstep(0, _Range, abs(sampleDepthDelta));

					if (isOccluded) { 
						occlusion += occlusionFunction(saturate(sampleDepthDelta));
						SAMPLED_COUNT += 1.0f;
					} 
					/*

					float depthWorldDelta = length(pixelWS - sampledWS) / _Range;
					float depthOnlyDelta = (sampledDepth - pixelDepth) / _Range;

					//occlusion += (_OcclusionFunction.Sample(sampler_linear_clamp, float2(depthWorldDelta, 0)));
					//occlusion += (_OcclusionFunction.Sample(sampler_linear_clamp, float2(depthOnlyDelta, 0)));
					//SAMPLED_COUNT += 1.0f;

					// Attempt  2
					// Sample the worldspace check if the sampled space is infront of the sampleWS then we have occlusion
					//

					float occluded = (_OcclusionFunction.Sample(sampler_linear_clamp, float2(depthOnlyDelta, 0)));

					if (sampleWS.z < sampledDepth) {
						occlusion += occluded;
						SAMPLED_COUNT += 1.0f;
					}*/
				}

				const bool isOccluded = SAMPLED_COUNT == 0;
				const float finalOcclusion = 1 - ((isOccluded) ? 0 : (occlusion * _Intensity / SAMPLE_COUNT));
				    
				return finalOcclusion;

				return pixelColor * finalOcclusion;
			}
  
			ENDCG
		}
	}
}
