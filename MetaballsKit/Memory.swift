//
//  Memory.swift
//  Metaballs
//
//  Created by Eryn Wells on 8/6/17.
//  Copyright © 2017 Eryn Wells. All rights reserved.
//

import Cocoa
import Foundation
import simd

extension UnsafeMutableRawPointer {
    func writeAndAdvance<T>(value: inout T) -> UnsafeMutableRawPointer {
        let stride = MemoryLayout.stride(ofValue: value)
        copyMemory(from: &value, byteCount: stride)
        return advanced(by: stride)
    }
}

extension NSColor {
    convenience init(float4: Float4) {
        self.init(deviceRed: CGFloat(float4.x), green: CGFloat(float4.y), blue: CGFloat(float4.z), alpha: CGFloat(float4.w))
    }
}

extension Array where Element == Float {
    init(float4: Float4) {
        self.init(arrayLiteral: float4.x, float4.y, float4.z, float4.w)
    }
}
