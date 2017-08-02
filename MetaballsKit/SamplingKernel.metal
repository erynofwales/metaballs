//
//  SamplingKernel.metal
//  Metaballs
//
//  Created by Eryn Wells on 8/1/17.
//  Copyright © 2017 Eryn Wells. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

typedef struct {
    float radius;
    float2 position;
    float2 velocity;
} Ball;

kernel void
sampleFieldKernel(const device Ball* metaballs      [[buffer(0)]],
                  texture2d<half, access::write>    [[texture(1)]],
                  uint2 gid                         [[thread_position_in_grid]])
{
    // TODO: Compute a sample for this pixel given the field data, and write it to the out texture.
}
