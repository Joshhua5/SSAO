
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