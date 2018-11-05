
#include "UnityCG.cginc"  




// Blur

uniform float2 BlurOffset;

Texture2D _MainTex;
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


half4 blur5(v2f i) : SV_Target{ 
	float4 color
		   = _MainTex.Sample(sampler_linear_repeat, i.uv) * 0.29411764705882354f;
	color += _MainTex.Sample(sampler_linear_repeat, i.uv + BlurOffset.xy) * 0.35294117647058826f;
	color += _MainTex.Sample(sampler_linear_repeat, i.uv - BlurOffset.xy) * 0.35294117647058826f;
	return color;
}