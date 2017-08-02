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


typedef struct {
    float2 position;
    float2 textureCoordinate;
} VertexIn;

// From HelloCompute sample code project.
// Vertex shader outputs and per-fragmeht inputs. Includes clip-space position and vertex outputs interpolated by rasterizer and fed to each fragment genterated by clip-space primitives.
typedef struct {
    // The [[position]] attribute qualifier of this member indicates this value is the clip space position of the vertex when this structure is returned from the vertex shader.
    float4 position [[position]];

    // Since this member does not have a special attribute qualifier, the rasterizer will interpolate its value with values of other vertices making up the triangle and pass that interpolated value to the fragment shader for each fragment in that triangle;
    float2 textureCoordinate;
} RasterizerData;

//vertex RasterizerData
//passthroughVertexShader(uint vertexID [[vertex_id]])
//{
//    // TODO: Nothing really. Just pass on through to the fragment shader.
//}

fragment float4
sampleToColorShader(RasterizerData in       [[stage_in]],
                    constant float* samples [[buffer(0)]],
                    constant float2* size   [[buffer(1)]])
{
    int index = in.textureCoordinate.y * size->y + in.textureCoordinate.x;
    float sample = samples[index];

    float4 out;
    if (sample > 1.0) {
        out = float4(0.0, 1.0, 0.0, 0.0);
    }
    else {
        out = float4(0.0, 0.0, 0.0, 0.0);
    }
    return out;
}
