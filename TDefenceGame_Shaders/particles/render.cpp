#include "hlsl.h"
#include "matrices.h"
#include "particle.h"

struct VS_Input {
    uint VertID : SV_VertexID;
    uint InstID : SV_InstanceID;
};

struct VS_Output {
    float4 Pos      : SV_Position;
    float3 wPos     : wPos;
    float3 TexCrd   : TexCrd;
    float4 TexClamp : TexClamp;
    float4 ColMult  : ColMult;
    float4 ColAdd   : ColAdd;
};

float WorldTime;

static const float2 V[4] = {
    {-1,-1},
    {-1, 1},
    { 1,-1},
    { 1, 1}
};

static const float2 VTex[4] = {
    { 0, 0},
    { 0, 1},
    { 1, 0},
    { 1, 1}
};

struct RegionRef {
    float4 Region;
    float  Slice;
};

float2 AtlasSize;
StructuredBuffer<RegionRef> AtlasRegionRefs;

StructuredBuffer<Particle> Particles;

VS_Output VS(VS_Input In) {
    VS_Output Out = (VS_Output)0;
    Particle p = Particles[In.InstID];
    if ((p.BornTime<=WorldTime)&&(p.DeadTime>WorldTime)) {
        float2x2 mrot;
        mrot[0] = float2(cos(p.Pos.z), sin(p.Pos.z));
        mrot[1] = float2(-mrot[0].y, mrot[0].x);
        Out.wPos = float3(V[In.VertID]*p.Size*0.5, 0.0);
        Out.wPos.xy = mul(Out.wPos.xy, mrot);
        Out.wPos.xy += p.Pos.xy;
        Out.Pos  = mul(float4(Out.wPos,1.0), VP_Matrix);
        Out.TexCrd.xy = VTex[In.VertID];
        
        if (p.AtlasRef < 0) {
            Out.TexCrd = float3(0,0,-1);
        } else {
            RegionRef RRef = AtlasRegionRefs[(int)p.AtlasRef];

            Out.TexClamp = (RRef.Region)/AtlasSize.xyxy;
            //if (!In.vsWrapMode.x)
                Out.TexClamp.xz += float2(0.5, -0.5)/AtlasSize.xy;
            //if (!In.vsWrapMode.y)
                Out.TexClamp.yw += float2(0.5, -0.5)/AtlasSize.xy;
            //RRef.Region += float4(0.5,0.5,-0.5,-0.5);
            float4 RegionUV = RRef.Region/AtlasSize.xyxy;
            Out.TexCrd.xy *= (RegionUV.zw - RegionUV.xy);
            Out.TexCrd.xy += RegionUV.xy;
            Out.TexCrd.z = RRef.Slice;
            Out.ColMult = p.ColMult;
            Out.ColAdd = p.ColAdd;
        }
    };
    return Out;
}

struct PS_Output {
    float4 Color : SV_Target0;
};

Texture2DArray Atlas; SamplerState AtlasSampler;

float  UseDynamicLighting;
Texture2D LightMap; SamplerState LightMapSampler;

PS_Output PS(VS_Output In) {
    PS_Output Out;
    if (In.TexCrd.z < 0) {
        Out.Color = 0.0;
        return Out;
    }
    float2 TexClampSize = (In.TexClamp.zw - In.TexClamp.xy);
    float2 ntex = (In.TexCrd.xy - In.TexClamp.xy) / TexClampSize;    

    Out.Color = Atlas.Sample(AtlasSampler, In.TexCrd);
    Out.Color *= In.ColMult;
    Out.Color += In.ColAdd;
    
    if (UseDynamicLighting) {
        float4 LightK = LightMap.Load(int3(In.Pos.xy, 0));
        Out.Color.rgb *= LightK.rgb;
    }
    
//    Out.Color.rgb = 1.0;
//    Out.Color.a = 0.05;
    
    return Out;
}