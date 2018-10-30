

#include "UnityCG.cginc"
 
uniform float4x4 projToView;
uniform float4x4 viewToWorld;

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

	float2 getRandom(float k) {
		if (k==0) return float2(0.07779833, 0.2529951);
		else if (k==1) return float2(-0.1778869f, -0.05900348);
		else if (k==2) return float2(0.8558092, 0.2799575);
		else if (k==3) return float2(-0.03023551, 0.8480632);
		else if (k==4) return float2(0.4166129, 0.8863604f);
		else if (k==5) return float2(0.3985788, -0.03791248);
		else if (k==6) return float2(-0.44102, 0.2654153);
		else if (k==7) return float2(-0.4586931, 0.7403293);
		else if (k==8) return float2(0.1117442, -0.5198008);
		else if (k==9) return float2(-0.8176585, 0.1296148);
		else if (k==10) return float2(-0.7903557, -0.2716176);
		else if (k==11) return float2(-0.4248519, -0.4493517);
		else if (k==12) return float2(0.8380554, -0.3609802);
		else if (k==13) return float2(0.4613214, 0.409142);
		else if (k==14) return float2(0.553355, -0.7046115);
		else return float2(-0.1786912f, -0.8461482);
	}