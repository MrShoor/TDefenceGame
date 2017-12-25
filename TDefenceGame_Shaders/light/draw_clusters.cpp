#include "hlsl.h"
#include "matrices.h"

float2 ScreenSize;

struct LightItem {
    float  Kind  : Kind;
    float  Dist  : Dist;
    float2 wPos  : wPos;
    float4 Color : Color;
};
StructuredBuffer<LightItem> LightData;

struct VS_Input {
    float2 vsCoord : vsCoord;
    uint   InstID  : SV_InstanceID;    
};

struct VS_Output {
    float4 Pos    : SV_Position;
    uint   InstID : SV_InstanceID;    
};

VS_Output VS(VS_Input In) {
    VS_Output Out;    
    LightItem l = LightData[In.InstID];
    
    Out.Pos.zw = float2(0.0, 1.0);
    Out.Pos.xy = In.vsCoord*(l.Dist+30.0/128.0);
    Out.Pos.xyz += mul(float4(l.wPos,0,1), V_Matrix).xyz;
    Out.Pos = mul(Out.Pos, P_Matrix);
    Out.InstID = In.InstID;
    return Out;
}

struct LightNode {
    uint LightIdx : LightIdx;
    uint Next     : Next;
};

globallycoherent RWTexture2D<uint> headBuffer : register(u0);
globallycoherent RWStructuredBuffer<LightNode> lightList : register(u1);

void PS(VS_Output In) {
    uint oldIndex;
    uint newIndex = lightList.IncrementCounter();
    
    if (newIndex == 0xffffffff) return;
    
    uint2 headPixel =(uint2) In.Pos.xy;

    InterlockedExchange(headBuffer[headPixel], newIndex, oldIndex);
    
    LightNode Out;
    Out.LightIdx = In.InstID;
    Out.Next = oldIndex;
    lightList[newIndex] = Out;
    
    return;
}