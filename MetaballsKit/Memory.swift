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
