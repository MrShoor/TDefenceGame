/*
 * File:   lighting.h
 * Author: alexander.busarov
 *
 * Created on November 22, 2017, 1:52 PM
 */
#include "hlsl.h"
#include "matrices.h"

#ifndef LIGHTING_H
#define	LIGHTING_H

struct LightItem {
    float  Kind  : Kind;
    float  Dist  : Dist;
    float2 wPos  : wPos;
    float4 Color : Color;
};

struct LightNode {
    uint LightIdx : LightIdx;
    uint Next     : Next;
};

Texture2D<uint> LightHead;
StructuredBuffer<LightNode> LightList;
StructuredBuffer<LightItem> LightData;
StructuredBuffer<float3x3>  LightProj;
Texture2D ShadowMap; SamplerState ShadowMapSampler;
float LightZ;

#define SHADOW_SAMPLES 5

float EvalShadow(float2 p, float2 dir, float y, uint lightIdx) {
    uint side;
    if (abs(dir.y)>abs(dir.x)) {
        if (dir.y < 0) {
            side = 1;
        } else {
            side = 3;
        }
    } else {
        if (dir.x < 0) {
            side = 2;
        } else {
            side = 0;
        }
    }
    
    float3x3 m = LightProj[lightIdx*8+side];
    float3 pp = mul(m, float3(p,1.0));
    pp.xy /= pp.z;
    pp.x += 1.0;
    pp.x *= 0.5;

    float4 shadow = ShadowMap.SampleLevel(ShadowMapSampler, float2(pp.x, y), 0);
    float d = 0;
    switch (side) {
        case 0: d = shadow.x; break;
        case 1: d = shadow.y; break;
        case 2: d = shadow.z; break;
        case 3: d = shadow.w; break;
    }
    if (d > pp.y) {
        return pow(saturate(d),1/5.0);
    } else {
        return 1.0;
    };
}

float4 ApplyLight(uint lightIdx, float2 p) {
    LightItem l = LightData[lightIdx];
    
    //lighting
    float2 dir = p - l.wPos;
    float dist = length(dir);
    float att = saturate(1.0 - dist/l.Dist);
    //return lerp(0.0, l.Color*1.0, att*att);
    
    float shadowSumm = 0;
    if (dot(dir, dir) > 0) {
        float smw, smh;
        ShadowMap.GetDimensions(smw, smh);
        float y = (lightIdx+0.5)/smh;
        float2 n = float2(-dir.y, dir.x)*0.00625;     
        
        for (uint i = 0; i<SHADOW_SAMPLES; i++) {
            float2 psample = p-n*(SHADOW_SAMPLES - 1.0)*0.5+i*n;
            shadowSumm += EvalShadow(psample, psample - l.wPos, y, lightIdx);
        }
        shadowSumm /= SHADOW_SAMPLES;
    } else {
        shadowSumm = 1.0;
    }
    
    return lerp(0.0, l.Color*1.0, att*att*shadowSumm);
}

float4 ApplyLighting(float2 UV, float2 Pos) {
    float4 Out = 0.0;
    uint2 pix = floor(UV*0.9999*(64.0));
    uint idx = LightHead[pix];
    //return UV.xyxy;
    //idx = 0;
    //return (idx != 0xFFFFFFFF)*100.0;

    for (int i = 0; i < 10; i++){
        if (idx != 0xFFFFFFFF) {
            LightNode ln = LightList[idx];
            Out += ApplyLight(ln.LightIdx, Pos);
            idx = ln.Next;
            //Out += 1.0;
        } else {
            return Out;
        }
    }
    return Out;
}

#endif	/* LIGHTING_H */