//
//  Shaders.metal
//  Metaballs
//
//  Created by Eryn Wells on 7/30/17.
//  Copyright © 2017 Eryn Wells. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

typedef struct {
    float2 position;
    float radius;
} Ball;

kernel void
sampleFieldKernel(const device Ball* metaballs  [[buffer(0)]],
                  device float* samples         [[buffer(1)]],
                  uint2 gid                     [[thread_position_in_grid]])
{
    // TODO: Compute a sample for this pixel given the field data, and write it to the out texture.
}
