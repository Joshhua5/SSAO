// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Hidden/SSAO"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    { 
        Tags { "RenderType"="Opaque"}
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "SSAO.cginc"

            sampler2D _CameraGBufferTexture2;
            sampler2D _CameraDepthTexture;

			Texture2D _RandomTex;
			SamplerState sampler_linear_repeat; 
			 
			uniform float _Range;
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

            fixed4 frag (v2f i) : SV_Target
            { 
                float depth = tex2D(_CameraDepthTexture, i.uv);
                //depth = LinearEyeDepth(depth);

                // Calculate the world position of this pixel   
				float2 uvClip = ScreenToClip(i.uv);
                float3 clipPos = float3(uvClip, depth);
                float3 viewPos = mul(projToView, clipPos); 
  
                float3 worldSpace = mul(viewToWorld, viewPos).xyz;
				 

                // use a set of random offset vectors to sample from the surrounding world

				// Prime the random
				float3 random = _RandomTex.Sample(sampler_linear_repeat, uvClip);
				//float2 random = tex2D(_RandomTex, uvClip);  

				float depthSum = 0;
				float occlusion = 0;

				const int SAMPLE_COUNT = 32;

				float3 normal = tex2D(_CameraGBufferTexture2, i.uv);

				// How many samples to take per pixel
				for (int index = 0; index < SAMPLE_COUNT; index++) { 
					random = _RandomTex.Sample(sampler_linear_repeat, uvClip + random);
					
					// This random vector needs to prevent the self occlusion
					// we handle this by dot producting with the normal and inverting if occluded
					if (dot(normal, random) <= 0)
						random *= float3(-1, -1, -1);

					// Convert World space back to Screen Space 
					float3 sampleWS = worldSpace + random * _Range; 
					    
					float3 sampleVS = mul(worldToView, sampleWS);  
					float3 sampleCS = mul(viewToProj, sampleVS);
					float2 sampleSS = ClipToScreen(sampleCS);
					  
					float sampleDepth = tex2D(_CameraDepthTexture, sampleSS);

					float depthDelta =  sampleDepth - depth;

					if (depth < sampleDepth)
						occlusion += depthDelta;
					   
					depthSum += sampleDepth;
				}
				 
				return 1 - occlusion;

				return depthSum / (float)SAMPLE_COUNT;
				  
				// Sample the surrounding pixels using the worldspace offset


				//float2 samplePointUV = ((samplePointSS.xy * 0.5f) + 0.5f) * float2(1, -1);
				//float depth_sample1 = LinearEyeDepth(tex2D(_CameraDepthTexture, samplePointUV));
				  
				// return fixed4(i.uv, 0, 1);
				// I don't know why I can't go from a [-1, 1] space to [0, 1] for the lookup.. It might have something to do with it not being [-1, 1]

				//return fixed4(i.uv, 0, 1);

				//samplePointUV = (samplePointUV * float2(1, -1)) - float2(10, 1);

				//return fixed4(samplePointUV, 0, 1);
				//return fixed4(samplePointSS / 2.0 + 0.5, 0, 1);
				//return fixed4(i.uv, 0, 1);

                //return fixed4(depth_sample1, depth_sample1, depth_sample1, 1);
 


                //return fixed4(depth, depth, depth, 1);
                //UNITY_OUTPUT_DEPTH(i.uv);
                //return fixed4(COMPUTE_EYEDEPTH(i.depth));
            }
            ENDCG
        }
    }
}
