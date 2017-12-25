#include "hlsl.h"
#include "matrices.h"

struct VS_Input {
    float2 vsCoord : vsCoord;
};

VS_Input VS(VS_Input In) {
    return In;
}

struct GS_Output {
    float4 Pos : SV_Position;
    float3 pPos: pPos;
    uint   Side: Side;
};

float DrawFrontFaces = 0.0;
float LightsCount;
StructuredBuffer<float3x3>  LightProj;

#define MAX_LIGHTS 64
[maxvertexcount(MAX_LIGHTS)]
void GS(line VS_Input In[2], inout LineStream<GS_Output> OutStream) {
    for (uint i=0; i<min(MAX_LIGHTS, (uint)LightsCount); i++){
        GS_Output Out1, Out2;
        float y = ((float)i+0.5)/(float)MAX_LIGHTS;
        y -= 0.5;
        y *= -2.0;
        for (uint j=0; j<4; j++) {
            float3x3 m = LightProj[i*8+j];
            
            Out1.pPos = mul(m, float3(In[0].vsCoord, 1.0));
            Out1.Side = j;
            Out1.Pos  = float4(Out1.pPos.x, y*Out1.pPos.z, Out1.pPos.yz);
            
            Out2.pPos = mul(m, float3(In[1].vsCoord, 1.0));
            Out2.Side = j;
            Out2.Pos  = float4(Out2.pPos.x, y*Out2.pPos.z, Out2.pPos.yz);
            
            float front_face_sign = DrawFrontFaces ? 1 : -1;
            if (Out1.pPos.x*front_face_sign/max(0.01,Out1.pPos.z) < Out2.pPos.x*front_face_sign/max(0.01,Out2.pPos.z)) {
                OutStream.Append(Out1);
                OutStream.Append(Out2);
                OutStream.RestartStrip();
            }
        }
    }
}

struct PS_Output {
    float4 Color : SV_Target0;
};

Texture2D FrontFaceTex; SamplerState FrontFaceTexSampler;

PS_Output PS(GS_Output In) {
    PS_Output Out;
    Out.Color = 0.0;
    float d = In.pPos.y/In.pPos.z;
    
    float4 ff_depth = DrawFrontFaces ? 1.0 : FrontFaceTex.Load(int3((int2)In.Pos.xy, 0));
    //ff_depth = 1.0;
    switch (In.Side) {
        case 0: if (ff_depth.x > d) Out.Color.x = d; break;
        case 1: if (ff_depth.y > d) Out.Color.y = d; break;
        case 2: if (ff_depth.z > d) Out.Color.z = d; break;
        case 3: if (ff_depth.w > d) Out.Color.w = d; break;
    }
    return Out;
}