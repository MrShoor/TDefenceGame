#include "hlsl.h"
#include "matrices.h"
#include "lighting.h"

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

float WorldTime;
Texture2D Dust; SamplerState DustSampler;
Texture2D Noise; SamplerState NoiseSampler;

float4 textureNoTile( in float2 x, out float f)
{
    float k = Noise.Sample(NoiseSampler, 0.01*x).x; // cheap (cache friendly) lookup
    
    float l = k*8.0;
    float i = floor( l );
    f = frac( l );
    
    float2 offa = sin(float2(3.0,7.0)*(i+0.0)); // can replace with any other hash
    float2 offb = sin(float2(3.0,7.0)*(i+1.0)); // can replace with any other hash

    float4 Out;
    Out.xy = x + 1247.0*offa;
    Out.zw = x + 1247.0*offb;
    
    return Out;
}

float GetDustSample(float2 seed) {
    float f;
    float4 suffleCrd = frac(textureNoTile(seed, f));
    float cola = Dust.Sample(DustSampler, suffleCrd.xy).r;
    float colb = Dust.Sample(DustSampler, suffleCrd.zw).r;
    return lerp( cola, colb, smoothstep(0.2,0.8,f-0.1*(cola-colb)) );
}

float4 Ambient;
Texture2D LightMap; SamplerState LightMapSampler;

PS_Output PS(VS_Output In) {
    PS_Output Out;
       
    float4 c = LightMap.Load(int3(In.Pos.xy, 0)) - Ambient;
//    float4 c =0.0;
    c.a = 0.009;
    //c.a = 0.5;

//    float2 seed;
//    seed = In.wPos*5.0+float2(sin(WorldTime)*0.1, WorldTime*0.25);
//    float dl = 0.0;//Dust.Sample(DustSampler, seed.xy).r*6.0 + 1.0;
//    dl = GetDustSample(seed)*1.5+1.0;
    Out.Color = c;// * dl;
    return Out;
}
