//
//  Geometry.swift
//  Metaballs
//
//  Created by Eryn Wells on 8/5/17.
//  Copyright © 2017 Eryn Wells. All rights reserved.
//

import Foundation

public struct Point {
    var x: Float
    var y: Float

    var CGPoint: CGPoint {
        return CoreGraphics.CGPoint(x: CGFloat(x), y: CGFloat(y))
    }

    init() {
        self.init(x: 0, y: 0)
    }

    init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }
}

extension Point: CustomStringConvertible {
    public var description: String {
        return "(\(x), \(y))"
    }
}

public struct Vector {
    var dx: Float
    var dy: Float

    init() {
        self.init(dx: 0, dy: 0)
    }

    init(dx: Float, dy: Float) {
        self.dx = dx
        self.dy = dy
    }
}

extension Vector: CustomStringConvertible {
    public var description: String {
        return "(\(dx), \(dy))"
    }
}
