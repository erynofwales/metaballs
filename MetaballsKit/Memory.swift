//
//  Memory.swift
//  Metaballs
//
//  Created by Eryn Wells on 8/6/17.
//  Copyright © 2017 Eryn Wells. All rights reserved.
//

import Foundation

extension UnsafeMutableRawPointer {
    func writeAndAdvance<T>(value: inout T) -> UnsafeMutableRawPointer {
        let stride = MemoryLayout.stride(ofValue: value)
        copyBytes(from: &value, count: stride)
        return advanced(by: stride)
    }
}

/// Metal's float4 type. 4 bytes per float, 16 bytes total, 16 byte aligned.
public struct Float4 {
    public var x: Float = 0
    public var y: Float = 0
    public var z: Float = 0
    public var w: Float = 0

    public init() { }

    public init(_ x: Float, _ y: Float, _ z: Float, _ w: Float) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }

    public init(r: Float, g: Float, b: Float, a: Float) {
        x = r
        y = g
        z = b
        w = a
    }
}

extension Array where Element == Float {
    init(float4: Float4) {
        self.init(arrayLiteral: float4.x, float4.y, float4.z, float4.w)
    }
}
