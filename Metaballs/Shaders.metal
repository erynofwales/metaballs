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
    float2 textureCoordinate;
} Vertex;

// From HelloCompute sample code project.
// Vertex shader outputs and per-fragmeht inputs. Includes clip-space position and vertex outputs interpolated by rasterizer and fed to each fragment genterated by clip-space primitives.
typedef struct {
    // The [[position]] attribute qualifier of this member indicates this value is the clip space position of the vertex when this structure is returned from the vertex shader.
    float4 position [[position]];

    // Since this member does not have a special attribute qualifier, the rasterizer will interpolate its value with values of other vertices making up the triangle and pass that interpolated value to the fragment shader for each fragment in that triangle;
    float2 textureCoordinate;
} RasterizerData;

vertex RasterizerData
passthroughVertexShader(uint vid                    [[vertex_id]],
                        constant Vertex* vertexes   [[buffer(0)]])
{
    RasterizerData out;
    Vertex v = vertexes[vid];
    out.position = float4(v.position.xy, 0.0, 1.0);
    out.textureCoordinate = v.textureCoordinate;
    return out;
}

fragment float4
sampleToColorShader(RasterizerData in           [[stage_in]],
                    texture2d<half> samples     [[texture(0)]])
{
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    const half4 sample = samples.sample(textureSampler, in.textureCoordinate);

    float4 out;
    if (sample.r > 1.0) {
        out = float4(0.0, 1.0, 0.0, 0.0);
    }
    else {
        out = float4(0.0, 0.0, 0.0, 0.0);
    }
    return out;
}
