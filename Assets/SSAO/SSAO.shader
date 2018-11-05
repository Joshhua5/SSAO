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

			Texture2D _CameraGBufferTexture2;
			Texture2D _CameraDepthTexture;
			Texture2D _MainTex; 
			Texture2D _RandomTex; 

			SamplerState sampler_linear_repeat; 

			uniform float _Range;
			uniform float _Intensity; 

			uniform float4x4 clipToView;
			uniform float4x4 viewToWorld;
			uniform float4x4 worldToView;
			uniform float4x4 viewToClip;
			  
			inline float2 ScreenToClip(float2 value) {
				return (value * 2) - 1;
			}

			inline float2 ClipToScreen(float2 value) {
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
				const float near = _ProjectionParams.y;
				const float far = _ProjectionParams.z;
				const float isOrtho = unity_OrthoParams.w;

				const float pixelDepth = _CameraDepthTexture.Sample(sampler_linear_clamp, uv);
				const float3 pixelColor = _MainTex.Sample(sampler_linear_clamp, uv);
				
				if (pixelDepth == 0)
					return pixelColor;

				const float3 normal = (_CameraGBufferTexture2.Sample(sampler_linear_clamp, uv) - 0.5) * 2;
				float3 random = _RandomTex.Sample(sampler_linear_repeat, i.uv);
				
				float3 vertexPosPerspective = i.ray * Linear01Depth(pixelDepth);
				  
				//float depthOrtho = lerp(near, far, pixelDepth);
				//float3 vertexPosOrtho = float3(i.ray.xy, depthOrtho);

				float3 pixelVS = vertexPosPerspective;// lerp(vertexPosPerspective, vertexPosOrtho, isOrtho);
				float3 pixelWS = mul(viewToWorld, float4(pixelVS, 1)).xyz;
				 
				// Prime the random

				const int SAMPLE_COUNT = 128;
				float occlusionFactor = 0;
				  
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
					const float4 sampleWS = float4(pixelWS + random * _Range, 1);  
					//sampleWS.z = Linear01Depth(sampleWS.z);
										
					const float4 sampleVS = mul(worldToView, sampleWS); 
					const float4 sampleCS = mul(viewToClip, sampleVS);
					const float2 sampleSS = ClipToScreen(sampleCS.xy / sampleCS.w);
					 
					// Sample the depth at this position
					const float sampledDepth = -1 * far * Linear01Depth(_CameraDepthTexture.Sample(sampler_linear_repeat, sampleSS));

					// Sample depth is in worldspace
					// Sampled depth is in view space
					const float4 sampledVS = float4(sampleVS.xy, sampledDepth, 1);
					const float4 sampledWS = mul(viewToWorld, sampledVS / sampledVS.w); 
					    
					// If the sampled depth is infront of the sample then it's occluded 
					// Do the occlusion check in ViewSpace 
					const bool isOccluded = sampledVS.z > sampleVS.z; 
					 
					if (isOccluded) {
						const float sampleDepthDelta = length(sampledWS - sampleWS);
						occlusionFactor += occlusionFunction(saturate(sampleDepthDelta));
					}
				}

				const float finalOcclusion = 1 - (occlusionFactor * _Intensity / SAMPLE_COUNT);
				return pixelColor * finalOcclusion;
			}
  
			ENDCG
		}
	}
}
