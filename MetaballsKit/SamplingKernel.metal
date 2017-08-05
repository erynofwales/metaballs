//
//  SamplingKernel.metal
//  Metaballs
//
//  Created by Eryn Wells on 8/1/17.
//  Copyright © 2017 Eryn Wells. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

// TODO: This is a dupe of the Ball struct. Is there a way to DRY this?
typedef struct {
    float radius;
    float2 position;
    float2 velocity;
} Ball;

typedef struct {
    int2 size;
    int numberOfBalls;
} Parameters;

kernel void
sampleFieldKernel(constant Parameters& parameters           [[buffer(0)]],
                  constant Ball* balls                      [[buffer(1)]],
                  texture2d<half, access::write> samples    [[texture(0)]],
                  uint2 gid                                 [[thread_position_in_grid]])
{
    float sample = 0.0;
    // TODO: Get number of metaballs.
    for (int i = 0; i < 2; i++) {
        constant Ball& ball = balls[i];
        float r2 = ball.radius * ball.radius;
        float xDiff = gid[0] - ball.position[0];
        float yDiff = gid[1] - ball.position[1];
        sample += r2 / ((xDiff * xDiff) + (yDiff * yDiff));
    }
    samples.write(sample, gid);
}
