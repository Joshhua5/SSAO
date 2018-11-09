Shader "Hidden/SSAO"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
	}
		SubShader
	{

		Pass
		{
			// No culling or depth
			Cull Off ZWrite Off ZTest Always

			CGPROGRAM 

			#pragma vertex vertexShader
			#pragma fragment occlusionShader

			#include "UnityCG.cginc"  

			struct appdata
			{
				uint vertexID : SV_VertexID;
			};

			struct v2f {
				float4 position : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 ray : TEXCOORD1;
			};

			Texture2D _CameraGBufferTexture2;
			Texture2D _CameraDepthTexture;
			Texture2D _MainTex;
			Texture2D _RandomTex;

			SamplerState sampler_linear_repeat;
			SamplerState sampler_linear_clamp;

			uniform uint _Samples;
			uniform float _Range;
			uniform float _Intensity;
			uniform float _DropOffFactor;

			uniform half3 _RandomSamples[32];

			uniform float4x4 clipToView;
			uniform float4x4 viewToWorld;
			uniform float4x4 worldToView;
			uniform float4x4 viewToClip;

			// [0, 1] to [-1, 1]
			inline float2 ScreenToClip(float2 value) { 
				return value * 2 - 1;
			}

			// [-1,1] to [0, 1]
			inline float2 ClipToScreen(float2 value) { 
				return value * 0.5 + 0.5;
			}

			inline half occlusionFunction(half value) {
				return pow(1 - value, _DropOffFactor);
			}

			inline float sm5Linear01Depth(float z) {
				return rcp(_ZBufferParams.x * z + _ZBufferParams.y);
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
				o.uv = (vertexPos.xy + 1) * 0.5; 
				o.ray = lerp(rayPerspective, rayOrtho, isOrtho);

				return o;
			}

			half3 occlusionShader(v2f i) : SV_Target {
				const float near = _ProjectionParams.y;
				const float far = _ProjectionParams.z;
				const float isOrtho = unity_OrthoParams.w;

				const float pixelDepth = _CameraDepthTexture.Sample(sampler_linear_clamp, i.uv).r; 

				if (pixelDepth == 0)
					return half3(1, 1, 1);

				const half3 normal = _CameraGBufferTexture2.Sample(sampler_linear_clamp, i.uv).xyz * 2 - 1;
				half3 random = _RandomTex.Sample(sampler_linear_repeat, i.uv);
					  random = _RandomTex.Sample(sampler_linear_repeat, i.uv + random);
				  
				//float depthOrtho = lerp(near, far, pixelDepth);
				//float3 vertexPosOrtho = float3(i.ray.xy, depthOrtho);

				// Pixel_ViewSpace = i.ray * sm5Linear01Depth(pixelDepth)
				// Pixel_WorldSpace = mul(viewToWorld, Pixel_ViewSpace)
				float3 pixelWS = mul(viewToWorld, float4(i.ray * sm5Linear01Depth(pixelDepth), 1)).xyz;

				// Prime the random  
				float occlusionFactor = 0;

				// How many samples to take per pixel
				// Sample the surrounding pixels using the worldspace offset 

				// SampleSetSize is set to a value that allows for the most Wavefronts to hide latency
				// while also allowing loop unrolling
				const uint SampleSetSize = 3;
				const uint SampleSetCount = _Samples / SampleSetSize;
				  
				[loop]
				for (uint sampleSet = 0; sampleSet < SampleSetCount; sampleSet++) {
					[unroll(SampleSetSize)]
					for (uint index = 0; index < SampleSetSize; index++) {
						// Working on removing the texture sample for a random, this method allows us to use a 16x16 texture for the random sample.
						// Although it's still a Texture request, per sample, per pixel
						random = _RandomTex.Sample(sampler_linear_repeat, i.uv + random).xyz;	
						//random = cross(random, _RandomSamples[(sampleSet * SampleSetSize) + index].xyz);
						//random = (random + _RandomSamples[sampleSet * SampleSetSize + index]) * 0.5;

						// This random vector needs to prevent the self occlusion
						// we handle this by dot producting with the normal and inverting if occluded
						if (dot(normal, random) < 0)
							random = -random;

						// Convert World space back to Screen Space 

						// It is possible that since the pixelWS isn't true worldspace, that the _Range has no depth taken into account
						// We need to properly convert the screen space pixel into worldspace to do this.
						const float4 sampleWS = float4(random * _Range + pixelWS, 1);

						const float4 sampleVS = mul(worldToView, sampleWS);
						const float4 sampleCS = mul(viewToClip, sampleVS);
						const float2 sampleSS = ClipToScreen(sampleCS.xy / sampleCS.w);

						// Sample the depth at this position
						const float sampledDepth = -far * sm5Linear01Depth(_CameraDepthTexture.Sample(sampler_linear_repeat, sampleSS));

						// Sample depth is in worldspace
						// Sampled depth is in view space
						// const float3 sampledVS = float4(sampleVS.xy, sampledDepth, 1);
						const float4 sampledWS = mul(viewToWorld, float4(sampleVS.xy, sampledDepth, 1));

						// If the sampled depth is infront of the sample then it's occluded 
						// Do the occlusion check in ViewSpace 
						if (sampledDepth > sampleVS.z) {
							occlusionFactor += occlusionFunction(saturate(length(sampledWS - sampleWS)));
						}
					}
				}

				return 1 - (occlusionFactor * _Intensity / _Samples);
			}

			ENDCG
		}

		pass {
			// No culling or depth
			Cull Off ZWrite Off ZTest Always

			CGPROGRAM
			#pragma vertex vertH
			#pragma fragment blur5

			#include "SSAO.cginc"  
				  
			ENDCG
		}

		pass {
			// No culling or depth
			Cull Off ZWrite Off ZTest Always

			CGPROGRAM
			#pragma vertex vertV
			#pragma fragment blur5Combine

			#include "SSAO.cginc" 
 
			ENDCG
		}
	}
}
