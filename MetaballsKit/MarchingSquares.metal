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
    out.textureCoordinate = v.textureCoordinate;
    return out;
}

fragment float4
gridFragmentShader(RasterizerData in [[stage_in]])
{
    return in.color;
}
