

#include "UnityCG.cginc"
 

struct appdata
{
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
};

struct v2f
{ 
    float4 vertex : SV_POSITION;
    float2 uv : TEXCOORD0;
};

v2f vert (appdata v)
{
    v2f o;
    o.vertex = UnityObjectToClipPos(v.vertex); 
    o.uv = v.uv;  
    return o;
} 