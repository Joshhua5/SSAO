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

            sampler2D _RandomTex;
            sampler2D _CameraDepthTexture;

			uniform float _Range;
			uniform float4x4 projToView;
			uniform float4x4 viewToWorld;

            fixed4 frag (v2f i) : SV_Target
            { 
                float depth = tex2D(_CameraDepthTexture, i.uv);
                //depth = LinearEyeDepth(depth);

                // Calculate the world position of this pixel   
                float2 uvClip = float2(i.uv * 2.0 - 1.0);
                float4 clipPos = float4(uvClip, depth, 1.0);
                float4 viewPos = mul(projToView, clipPos);
  
                float3 worldSpace = mul(projToView, viewPos.xyz / viewPos.w).xyz;
    

				//return fixed4(worldSpace, 1);

                // use a set of random offset vectors to sample from the surrounding world

				float3 random1 = tex2D(_RandomTex, uvClip);
				float3 random2 = tex2D(_RandomTex, uvClip + random1.xy);
				float3 random3 = tex2D(_RandomTex, uvClip + random2.xy);
				float3 random4 = tex2D(_RandomTex, uvClip + random3.xy);
				float3 random5 = tex2D(_RandomTex, uvClip + random4.xy);
				float3 random6 = tex2D(_RandomTex, uvClip + random5.xy);
				float3 random7 = tex2D(_RandomTex, uvClip + random6.xy);
				float3 random8 = tex2D(_RandomTex, uvClip + random7.xy);

				// Sample the surrounding pixels using the worldspace offset

				float3 samplePointWS = worldSpace + (random1 * _Range);
				float3 samplePointSS = mul(UNITY_MATRIX_VP, samplePointWS).xyw;
				float2 samplePointUV = (((samplePointSS.xy / samplePointSS.z) * 0.5f) + 0.5f) * float2(1, -1);
				float depth_sample1 = tex2D(_CameraDepthTexture, samplePointUV);
				 
				// I don't know why I can't go from a [-1, 1] space to [0, 1] for the lookup.. It might have something to do with it not being [-1, 1]
				return fixed4(samplePointUV,  0, 1);

				//return fixed4(i.uv, 0, 1);

				//samplePointUV = (samplePointUV * float2(1, -1)) - float2(10, 1);

				//return fixed4(samplePointUV, 0, 1);
				//return fixed4(samplePointSS / 2.0 + 0.5, 0, 1);
				//return fixed4(i.uv, 0, 1);

                return fixed4(depth_sample1, depth_sample1, depth_sample1, 1);
 


                //return fixed4(depth, depth, depth, 1);
                //UNITY_OUTPUT_DEPTH(i.uv);
                //return fixed4(COMPUTE_EYEDEPTH(i.depth));
            }
            ENDCG
        }
    }
}
