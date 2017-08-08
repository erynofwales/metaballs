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
struct Float4 {
    var x: Float = 0
    var y: Float = 0
    var z: Float = 0
    var w: Float = 0
}
