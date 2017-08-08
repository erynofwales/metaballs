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

typedef struct {
    short2 size;
    ushort numberOfBalls;

    ushort unused1;
    uint unused2;
    ushort unused3;

    ushort colorStyle;
    float4 colors[4];
} Parameters;

typedef float3 Ball;

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

float mapValueFromRangeOntoRange(float, float, float, float, float);
float sampleAtPoint(float2, constant Ball*, int);

fragment float4
sampleToColorShader(RasterizerData in               [[stage_in]],
                    constant Parameters& parameters [[buffer(0)]],
                    constant Ball* balls            [[buffer(1)]])
{
    const float sample = sampleAtPoint(in.position.xy, balls, parameters.numberOfBalls);

    const float3 left = float3(0.50, 0.79, 1.00);
    const float3 right = float3(0.88, 0.50, 1.00);
    const float blend = in.position.x / parameters.size.x;
    const float invBlend = 1.0 - blend;

    const float target = 1.0;

    const float r = (blend * left.x + invBlend * right.x) / 2.0;
    const float g = (blend * left.y + invBlend * right.y) / 2.0;
    const float b = (blend * left.z + invBlend * right.z) / 2.0;
    const float a = clamp(mapValueFromRangeOntoRange(sample, 0.75 * target, target, 0, 1), 0.0, 1.0);

    float4 out = float4(r, g, b, a);
    return out;
}

float
sampleAtPoint(float2 point,
              constant Ball* balls,
              int count)
{
    float sample = 0.0;
    for (int i = 0; i < count; i++) {
        Ball ball = balls[i];
        float r2 = ball.z * ball.z;     // Radius stored in z coordinate.
        float xDiff = point.x - ball.x;
        float yDiff = point.y - ball.y;
        sample += r2 / ((xDiff * xDiff) + (yDiff * yDiff));
    }
    return sample;
}

float
mapValueFromRangeOntoRange(float value,
                           float inputStart,
                           float inputEnd,
                           float outputStart,
                           float outputEnd)
{
    const float slope = (outputEnd - outputStart) / (inputEnd - inputStart);
    float output = outputStart + slope * (value - inputStart);
    return output;
}
