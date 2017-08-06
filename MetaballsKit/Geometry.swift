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

public struct Size {
    var width: UInt16
    var height: UInt16

    public init() {
        self.init(width: 0, height: 0)
    }

    public init(width: UInt16, height: UInt16) {
        self.width = width
        self.height = height
    }

    public init(size: CGSize) {
        self.init(width: UInt16(size.width), height: UInt16(size.height))
    }
}

extension Size: CustomStringConvertible {
    public var description: String {
        return "(\(width), \(height))"
    }
}

extension Size: Equatable {
    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// Equality is the inverse of inequality. For any values `a` and `b`,
    /// `a == b` implies that `a != b` is `false`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    public static func ==(lhs: Size, rhs: Size) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height
    }
}

extension CGSize {
    init(size: Size) {
        self.init(width: CGFloat(size.width), height: CGFloat(size.height))
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
