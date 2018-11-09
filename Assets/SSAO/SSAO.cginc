
#include "UnityCG.cginc"  

// Blur

uniform float2 _BlurOffset;

Texture2D _MainTex;
Texture2D _OcclusionTex;
SamplerState sampler_linear_repeat;

struct appdata
{
	float4 vertex : POSITION;
	float2 uv : TEXCOORD0;
};

struct v2f
{
	float2 uv : TEXCOORD0;
	float4 vertex : SV_POSITION;
};

v2f vertH(appdata v) {
	v2f o;
	o.vertex = UnityObjectToClipPos(v.vertex);
	o.uv = v.uv;
	return o;
}

v2f vertV(appdata v) {
	v2f o;
	o.vertex = UnityObjectToClipPos(v.vertex);
	o.uv = float2(v.uv.x, 1 - v.uv.y);
	return o;
}
 
half blur5(v2f i) : SV_Target{
	half occlusion = _OcclusionTex.Sample(sampler_linear_repeat, i.uv) * 0.29411764705882354f;
	occlusion += _OcclusionTex.Sample(sampler_linear_repeat, i.uv + _BlurOffset.xy) * 0.35294117647058826f;
	occlusion += _OcclusionTex.Sample(sampler_linear_repeat, i.uv - _BlurOffset.xy) * 0.35294117647058826f;
	return occlusion;
}

half4 blur5Combine(v2f i) : SV_Target{
	float4 color = _MainTex.Sample(sampler_linear_repeat, float2(i.uv.x, 1 - i.uv.y));
	half occlusion = _OcclusionTex.Sample(sampler_linear_repeat, i.uv).r * 0.29411764705882354f; 
	occlusion += _OcclusionTex.Sample(sampler_linear_repeat, i.uv + _BlurOffset.xy).r * 0.35294117647058826f;
	occlusion += _OcclusionTex.Sample(sampler_linear_repeat, i.uv - _BlurOffset.xy).r * 0.35294117647058826f;
	  
	return color * occlusion;
}