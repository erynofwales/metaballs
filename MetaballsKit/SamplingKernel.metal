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
sampleFieldKernel(constant Ball* balls                      [[buffer(0)]],
                  texture2d<half, access::write> samples    [[texture(1)]],
                  uint2 gid                                 [[thread_position_in_grid]])
{
    float sample = 0.0;
    // TODO: Get number of metaballs.
    for (int i = 0; i < 2; i++) {
        constant Ball& ball = metaballs[i];
        float r2 = ball.radius * ball.radius;
        float xDiff = gid[0] - ball.position[0];
        float yDiff = gid[1] - ball.position[1];
        sample += r2 / ((xDiff * xDiff) + (yDiff * yDiff));
    }
    samples.write(sample, gid);
}
