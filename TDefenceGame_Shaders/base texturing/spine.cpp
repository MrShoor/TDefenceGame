#include "hlsl.h"
#include "matrices.h"

struct VS_Input {
    float3 vsCoord   : vsCoord;
    float2 vsTexCrd  : vsTexCrd;
    float4 vsColor   : vsColor;
    float  vsAtlasRef: vsAtlasRef;
    float2 vsWrapMode: vsWrapMode;
};

struct VS_Output {
    float4 Pos      : SV_Position;
    float3 TexCrd   : TexCrd;
    float4 TexClamp : TexClamp;
    float2 WrapMode : WrapMode;
    float4 Color    : Color;
};

struct RegionRef {
    float4 Region;
    float  Slice;
};

float2 ScreenSize;

float UIRender;
float2 AtlasSize;
StructuredBuffer<RegionRef> AtlasRegionRefs;

VS_Output VS(VS_Input In) {
    VS_Output Out;
    if (UIRender) {
        Out.Pos.zw = float2(0,1);
        Out.Pos.xy = In.vsCoord.xy/ScreenSize;
        Out.Pos.xy -= 0.5;
        Out.Pos.xy *= float2(2.0,2.0);
    } else {
        Out.Pos = mul(float4(In.vsCoord, 1.0), VP_Matrix);
    }
    Out.TexCrd.xy = In.vsTexCrd;
    Out.WrapMode = In.vsWrapMode;
    
    if (In.vsAtlasRef < 0) {
        Out.TexCrd = float3(0,0,-1);
    } else {
        RegionRef RRef = AtlasRegionRefs[(int)In.vsAtlasRef];
        
        Out.TexClamp = (RRef.Region)/AtlasSize.xyxy;
        if (!In.vsWrapMode.x)
            Out.TexClamp.xz += float2(0.5, -0.5)/AtlasSize.xy;
        if (!In.vsWrapMode.y)
            Out.TexClamp.yw += float2(0.5, -0.5)/AtlasSize.xy;
        //RRef.Region += float4(0.5,0.5,-0.5,-0.5);
        float4 RegionUV = RRef.Region/AtlasSize.xyxy;
        Out.TexCrd.xy *= (RegionUV.zw - RegionUV.xy);
        Out.TexCrd.xy += RegionUV.xy;
        Out.TexCrd.z = RRef.Slice;
    }
        
    Out.Color = In.vsColor;
    
    return Out;
}

struct PS_Output {
    float4 Color : SV_Target;
};

Texture2DArray Atlas; SamplerState AtlasSampler;
Texture2D Noise; SamplerState NoiseSampler;

float  UseDynamicLighting;

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

float sum( float4 v ) { return v.x+v.y+v.z; }

Texture2D LightMap; SamplerState LightMapSampler;

PS_Output PS(VS_Output In) {
    PS_Output Out;
//    Out.Color = 0.0;
//    return Out;
    float4 diff;
    
    if (In.TexCrd.z < 0) {
        diff = 1.0;
    } else {
        float2 TexClampSize = (In.TexClamp.zw - In.TexClamp.xy);
        float2 ntex = (In.TexCrd.xy - In.TexClamp.xy) / TexClampSize;

        if(In.WrapMode.x>1.5) {
            float f;
            float4 suffleCrd = frac(textureNoTile(ntex, f));
            suffleCrd *= TexClampSize.xyxy;
            suffleCrd += In.TexClamp.xyxy;

            float4 cola = Atlas.Sample(AtlasSampler, float3(suffleCrd.xy, In.TexCrd.z));
            float4 colb = Atlas.Sample(AtlasSampler, float3(suffleCrd.zw, In.TexCrd.z));
            
            diff = lerp( cola, colb, smoothstep(0.2,0.8,f-0.1*sum(cola-colb)) );
        } else {
            if (!In.WrapMode.x<0.5){
                In.TexCrd.x = frac(ntex.x) * TexClampSize.x + In.TexClamp.x;
            } else {
                In.TexCrd.x = clamp(In.TexCrd.x, In.TexClamp.x, In.TexClamp.z);
            }
            if (!In.WrapMode.y<0.5){
                In.TexCrd.y = frac(ntex.y) * TexClampSize.y + In.TexClamp.y;            
            } else {
                In.TexCrd.y = clamp(In.TexCrd.y, In.TexClamp.y, In.TexClamp.w);
            }

            diff = Atlas.Sample(AtlasSampler, In.TexCrd);
        }
    }
    Out.Color = diff * In.Color;

    if (UseDynamicLighting) {
        float4 LightK = LightMap.Load(int3(In.Pos.xy, 0));
        Out.Color.rgb *= LightK.rgb;
    }

    return Out;
}