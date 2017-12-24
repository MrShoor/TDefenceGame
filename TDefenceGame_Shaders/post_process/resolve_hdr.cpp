#include "hlsl.h"

struct VS_Input {
    uint VID : SV_VertexID;
};

struct VS_Output {
    float4 Pos : SV_Position;
};

static const float2 Quad[4] = {
    {-1,-1},
    {-1, 1},
    { 1,-1},
    { 1, 1}
};

VS_Output VS(VS_Input In) {
    VS_Output Out;    
    Out.Pos.xy = Quad[In.VID];
    Out.Pos.z = 0;
    Out.Pos.w = 1;
    return Out;
}

struct PS_Output {
    float4 Color : SV_Target0;
};

Texture2D Color; SamplerState ColorSampler;

PS_Output PS(VS_Output In) {
    PS_Output Out;
    Out.Color = Color.Load(int3(In.Pos.xy, 0));
    return Out;
}