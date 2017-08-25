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
    /// Two color horizontal gradient
    Gradient2Horizontal = 2,
    /// Two color vertical gradient
    Gradient2Vertical = 3,
    /// Four color gradient from corners
    Gradient4Corners = 4,
    /// Four color gradient from middle of sides
    Gradient4Sides = 5,
} ColorStyle;

typedef struct {
    short2 size;
    ushort numberOfBalls;

    ushort colorStyle;
    float target;
    float feather;

    float4 colors[4];
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
float4 gradient2(float, float, float, float, float4, float4);

#pragma mark - Helpers
float mapValueFromRangeOntoRange(float, float, float, float, float);
float4 averageTwoColors(float, float4, float4);

#pragma mark - Fragment

fragment float4
sampleToColorShader(RasterizerData in               [[stage_in]],
                    constant Parameters& parameters [[buffer(0)]],
                    constant Ball* balls            [[buffer(1)]])
{
    const float target = parameters.target;
    const float feather = parameters.feather;
    const float sample = sampleAtPoint(in.position.xy, balls, parameters.numberOfBalls);
    const float blend = in.position.x / parameters.size.x;

    float4 out;
    switch (parameters.colorStyle) {
        case SingleColor:
            out = singleColor(sample, target, feather, parameters.colors[0]);
            break;
        case Gradient2Horizontal:
            out = gradient2(sample, target, feather, blend, parameters.colors[0], parameters.colors[1]);
            break;
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

float4
gradient2(float sample,
          float target,
          float feather,
          float normalizedBlend,
          float4 fromColor,
          float4 toColor)
{
    float4 blendedColor = averageTwoColors(normalizedBlend, fromColor, toColor);
    float4 out = singleColor(sample, target, feather, blendedColor);
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

/// Compute the color at a given point along a 1-dimensional gradient. This averages the two colors. This function doesn't treat alpha. The returned color will have an alpha of 1.
/// @param coordinate A value between 0 and 1, a point along the gradient.
/// @param leftColor The color at the extreme left of the gradient.
/// @param rightColor The color at the extreme right of the gradient.
/// @return A color, a blend of `leftColor` and `rightColor` at the given point along the axis.
float4
averageTwoColors(float coordinate,
                 float4 leftColor,
                 float4 rightColor)
{
    const float invCoordinate = 1.0 - coordinate;
    const float r = (coordinate * leftColor.x + invCoordinate * rightColor.x) / 2.0;
    const float g = (coordinate * leftColor.y + invCoordinate * rightColor.y) / 2.0;
    const float b = (coordinate * leftColor.z + invCoordinate * rightColor.z) / 2.0;
    return float4(r, g, b, 1.0);
}
