/* 
 * File:   particle.h
 * Author: alexander.busarov
 *
 * Created on November 25, 2017, 11:20 PM
 */

#ifndef PARTICLE_H
#define	PARTICLE_H

struct Particle {
    float3 Pos;
    float3 Vel;
    float3 Acc;
    float3 Damp;
    float2 Size;
    float2 SizeVel;
    
    float4 ColMult;
    float4 ColMultVel;
    float4 ColAdd;
    float4 ColAddVel;
    
    float  BornTime;
    float  DeadTime;
    float  CustomSolver;
    float  AtlasRef;
};

#endif	/* PARTICLE_H */

