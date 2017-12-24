#include "hlsl.h"
#include "matrices.h"
#include "lighting.h"

struct VS_Input {
    uint VID : SV_VertexID;
};

struct VS_Output {
    float4 Pos : SV_Position;
    float3 wPos: wPos;
};

static const float2 Quad[4] = {
    {-1,-1},
    {-1, 1},
    { 1,-1},
    { 1, 1}
};

VS_Output VS(VS_Input In) {
    VS_Output Out;
    float4 tmp = mul(float4(0,0,0,1), VP_Matrix);
    
    Out.Pos.xy = Quad[In.VID]*LightZ;
    Out.Pos.z = tmp.z;
    Out.Pos.w = LightZ;
    float4 wp = mul(Out.Pos, P_InverseMatrix);
    wp /= wp.w;
    wp = mul(wp, V_InverseMatrix);
    Out.wPos = wp.xyz / wp.w;
    return Out;
}

struct PS_Output {
    float4 Color : SV_Target0;
};

float2 ScreenSize;

PS_Output PS(VS_Output In) {
    PS_Output Out;
    float2 UV = (In.Pos.xy)/ScreenSize;
    Out.Color.rgb = ApplyLighting(UV, In.wPos.xy).rgb;
    Out.Color.a = 1.0;
    return Out;
}