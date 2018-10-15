//
//  ShaderTypes.h
//  Metaballs
//
//  Created by Eryn Wells on 10/14/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

#ifndef ShaderTypes_hh
#define ShaderTypes_hh

#include <metal_stdlib>

/// A Ball is a float 3-tuple: (x, y, r).
typedef float3 Ball;

struct Vertex {
    float2 position;
    float2 textureCoordinate;
};

struct RenderParameters {
    /// Projection matrix.
    metal::float4x4 projection;
};

#endif /* ShaderTypes_hh */
