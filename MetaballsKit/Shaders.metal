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

typedef enum {
    /// Single flat color
    SingleColor = 1,
    /// Two color gradient
    Gradient2 = 2,
    /// Four color gradient
    Gradient4 = 4,
} ColorStyle;

typedef struct {
    packed_uint2 size;
    uint numberOfBalls;
    uint colorStyle;
    float target;
    float feather;
    float4 colors[4];
    float3x3 colorTransform;
} Parameters;

typedef float3 Ball;

#pragma mark - Vertex

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

float sampleAtPoint(float2, constant Ball*, int);

#pragma mark - Color Samplers
float4 singleColor(float, float, float, float4);

#pragma mark - Helpers
float mapValueFromRangeOntoRange(float, float, float, float, float);

#pragma mark - Fragment

fragment float4
sampleToColorShader(RasterizerData in               [[stage_in]],
                    constant Parameters& parameters [[buffer(0)]],
                    constant Ball* balls            [[buffer(1)]])
{
    const float target = parameters.target;
    const float feather = parameters.feather;
    const float sample = sampleAtPoint(in.position.xy, balls, parameters.numberOfBalls);

    float4 out;
    switch (parameters.colorStyle) {
        case SingleColor:
            out = singleColor(sample, target, feather, parameters.colors[0]);
            break;
        case Gradient2: {
            const float3 transformedColor = parameters.colorTransform * float3(in.position.xy, 1.0);
            const float blend = transformedColor.x / parameters.size[0];
            const float4 color = mix(parameters.colors[0], parameters.colors[1], blend);
            out = singleColor(sample, target, feather, color);
            break;
        }
        case Gradient4: {
            const float3 transformedColorCoords = parameters.colorTransform * float3(in.position.xy, 1.0);
            const float2 blend = float2(transformedColorCoords.x / parameters.size[0],
                                        transformedColorCoords.y / parameters.size[1]);
            const float4 color = mix(mix(parameters.colors[0], parameters.colors[2], blend.y),
                                     mix(parameters.colors[1], parameters.colors[3], blend.y),
                                     blend.x);
            out = singleColor(sample, target, feather, color);
            break;
        }
    }


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

float4
singleColor(float sample,
            float target,
            float feather,
            float4 color)
{
    float4 out;
    if (sample > target) {
        out = color;
    }

    // Feather the alpha value.
    const float mappedAlpha = mapValueFromRangeOntoRange(sample, (1.0 - feather) * target, target, 0, 1);
    const float a = clamp(mappedAlpha, 0.0, 1.0);
    out = float4(out.xyz, a);

    return out;
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
