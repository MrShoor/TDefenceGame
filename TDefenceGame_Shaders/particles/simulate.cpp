#include "hlsl.h"
#include "particle.h"

struct CS_Input {
    uint GroupID    : SV_GroupID;
    uint GroupIndex : SV_GroupIndex;
};

#define THREAD_GROUP_X 256

float SimTime;
float MaxParticlesCount;

RWStructuredBuffer<Particle> Particles : register(u0);

void sDefault(inout Particle p) {
    p.Vel += p.Acc;
    p.Vel *= p.Damp;
    p.Pos += p.Vel;
    p.Size += p.SizeVel;
    p.ColMult += p.ColMultVel;
    p.ColAdd += p.ColAddVel;
}

void sDust(inout Particle p) {
    float2x2 mrot;
    mrot[0] = float2(cos(p.Acc.z*3), sin(p.Acc.z*3));
    mrot[1] = float2(-mrot[0].y, mrot[0].x);
    
    p.Vel += p.Acc;
    p.Vel.xy = mul(p.Vel.xy, mrot);
    p.Vel *= p.Damp;
//    p.Vel.y *= p.Damp.y;
//    p.Vel.y *= p.Damp.y;
    p.Pos += p.Vel;
    p.Size += p.SizeVel;
    p.ColMult.a = 1.0 - (SimTime-p.BornTime)/(p.DeadTime-p.BornTime);
    p.ColMult.a = pow(saturate(p.ColMult.a), 2.5);
}

void sFog(inout Particle p) {
    float t = SimTime * 0.001;
    p.Pos.xy = float2(cos(t*p.Vel.x), cos(t*p.Vel.y)*0.2) + p.Acc.xy;
}

[numthreads(THREAD_GROUP_X,1,1)]
void CS(CS_Input In) {
    uint idx = In.GroupID.x * THREAD_GROUP_X + In.GroupIndex;
    if (idx >= (uint)MaxParticlesCount) return;
    Particle p = Particles[idx];
    if ((p.BornTime <= SimTime)&&(p.DeadTime>SimTime)) {
        switch ((uint)p.CustomSolver) {
            case 1: sDust(p); break;
            case 2: sFog(p); break;
            default: sDefault(p); break;
        }
//        sDust(p);
        Particles[idx] = p;
    }
}