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

            sampler2D _MainTex;
            sampler2D _CameraDepthTexture; 

            fixed4 frag (v2f i) : SV_Target
            { 
                float depth = tex2D(_CameraDepthTexture, i.uv);
                //depth = LinearEyeDepth(depth);

                // Calculate the world position of this pixel   
                float2 uvClip = float2(i.uv * 2.0 - 1.0);
                float4 clipPos = float4(uvClip, depth, 1.0);
                float4 viewPos = mul(projToView, clipPos);
  
                float3 worldSpace = mul(viewToWorld, viewPos.xyz / viewPos.w).xyz;
    
                // use a set of offset vectors to sample from the surrounding world

                

                return fixed4(worldSpace, 1);
 


                //return fixed4(depth, depth, depth, 1);
                //UNITY_OUTPUT_DEPTH(i.uv);
                //return fixed4(COMPUTE_EYEDEPTH(i.depth));
            }
            ENDCG
        }
    }
}
