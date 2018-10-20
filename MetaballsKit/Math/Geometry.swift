//
//  Geometry.swift
//  Metaballs
//
//  Created by Eryn Wells on 8/5/17.
//  Copyright © 2017 Eryn Wells. All rights reserved.
//

import Foundation
import simd

public typealias Size = packed_uint2

extension Size {
    public init(size: CGSize) {
        self.init(UInt32(size.width), UInt32(size.height))
    }
}

extension Size: CustomStringConvertible {
    public var description: String {
        return "(\(x), \(y))"
    }
}
