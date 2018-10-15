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

struct MarchingSquaresParameters {
    /// Field size in pixels.
    packed_uint2 pixelSize;
    /// Field size in grid units.
    packed_uint2 gridSize;
    /// Size of a cell in pixels.
    packed_uint2 cellSize;
    /// Number of balls in the array above.
    uint ballsCount;
};

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

kernel void
generateGridGeometry()
{
}

/// Sample the field at regularly spaced intervals and populate `samples` with the resulting values.
kernel void
samplingKernel(constant MarchingSquaresParameters &parameters [[buffer(0)]],
               constant Ball *balls [[buffer(1)]],
               device float *samples [[buffer(2)]],
               uint2 position [[thread_position_in_grid]])
{
    // Find the midpoint of this grid cell.
    const float2 point = float2(position.x * parameters.cellSize.x + (parameters.cellSize.x / 2.0),
                                position.y * parameters.cellSize.y + (parameters.cellSize.y / 2.0));

    // Sample the grid.
    float sample = 0.0;
    for (uint i = 0; i < parameters.ballsCount; i++) {
        constant Ball &ball = balls[i];
        float r2 = ball.z * ball.z;
        float xDiff = point.x - ball.x;
        float yDiff = point.y - ball.y;
        sample += r2 / ((xDiff * xDiff) + (yDiff * yDiff));
    }

    // Playing a bit fast and loose with these values here. The compute grid is the size of the grid itself, so parameters.gridSize == [[threads_per_grid]].
    uint idx = position.y * parameters.gridSize.x + position.x;
    samples[idx] = sample;
}

kernel void
contouringKernel(constant MarchingSquaresParameters &parameters [[buffer(0)]],
                 constant float *samples [[buffer(1)]],
                 device ushort *contourIndexes [[buffer(2)]],
                 uint position [[thread_position_in_grid]])
{
    // Calculate an index based on the samples at the four points around this cell.
    // If the point is above the threshold, adjust the value accordingly.
    //      d--c    8--4
    //      |  | -> |  |
    //      a--b    1--2
    uint a = position + parameters.gridSize.x;
    uint b = position + parameters.gridSize.x + 1;
    uint c = position + 1;
    uint d = position;
    uint index = (samples[d] >= 1.0 ? 0b1000 : 0) +
                 (samples[c] >= 1.0 ? 0b0100 : 0) +
                 (samples[b] >= 1.0 ? 0b0010 : 0) +
                 (samples[a] >= 1.0 ? 0b0001 : 0);
    contourIndexes[position] = index;
}

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
                   constant ushort *contourIndexes [[buffer(0)]])
{
    int instance = in.instance;
    uint sample = contourIndexes[instance];
    return sample >= 1 ? in.color : float4(0);
}
