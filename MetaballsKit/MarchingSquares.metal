//
//  MarchingSquares.metal
//  Metaballs
//
//  Created by Eryn Wells on 10/14/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

#include <metal_stdlib>
#include "ShaderTypes.hh"
using namespace metal;

struct Rect {
    float4x4 transform;
    float4 color;
};

struct RasterizerData {
    float4 position [[position]];
    float4 color;
    float2 textureCoordinate;
    int instance;
};

vertex RasterizerData
gridVertexShader(constant Vertex *vertexes [[buffer(0)]],
                 constant Rect *rects [[buffer(1)]],
                 constant RenderParameters &renderParameters [[buffer(2)]],
                 uint vid [[vertex_id]],
                 uint instid [[instance_id]])
{
    Vertex v = vertexes[vid];

    Rect rect = rects[instid];

    RasterizerData out;
    out.position = renderParameters.projection * rect.transform * float4(v.position.xy, 0, 1);
    out.color = rect.color;
    out.textureCoordinate = v.textureCoordinate;
    out.instance = instid;
    return out;
}

fragment float4
gridFragmentShader(RasterizerData in [[stage_in]],
                   constant float *samples [[buffer(0)]])
{
    int instance = in.instance;
    float sample = samples[instance];
    return sample > 1.0 ? in.color : float4(0);
}
