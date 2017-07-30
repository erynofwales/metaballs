//
//  Metaballs.swift
//  Metaballs
//
//  Created by Eryn Wells on 7/30/17.
//  Copyright © 2017 Eryn Wells. All rights reserved.
//

import Foundation

public struct Ball {
    let radius: CGFloat
    var position = CGPoint()
    var velocity = CGVector()

    internal var bounds: CGRect {
        let diameter = radius * 2
        return CGRect(x: position.x - radius, y: position.y - radius, width: diameter, height: diameter)
    }

    init(radius r: CGFloat) {
        radius = r
    }

    internal mutating func update() {
        position.x += velocity.dx
        position.y += velocity.dy
    }
}

public struct Field {
    public var size: CGSize {
        didSet {
            // Remove balls that fall outside the new bounds.
            balls = balls.filter { bounds.contains($0.bounds) }
        }
    }

    private(set) var balls = [Ball]()

    internal var bounds: CGRect {
        return CGRect(origin: CGPoint(), size: size)
    }

    public init(size s: CGSize) {
        size = s
    }

    public func update() {
        let selfBounds = bounds
        for var ball in balls {
            // Update position of ball.
            ball.update()

            if !selfBounds.contains(ball.position) {
                // Degenerate case. If the ball finds itself outside the bounds of the field, plop it back in the center.
                ball.position = CGPoint(x: selfBounds.midX, y: selfBounds.midY)
            } else {
                // Do collision detection with walls.
                let ballBounds = ball.bounds
                if !selfBounds.contains(ballBounds) {
                    if ballBounds.minX < selfBounds.minX || ballBounds.maxX > selfBounds.maxX {
                        ball.velocity.dx *= -1
                    }
                    if ballBounds.minY < selfBounds.minY || ballBounds.maxY > selfBounds.maxY {
                        ball.velocity.dy *= -1
                    }
                }
            }
        }
    }

    public func sample(at point: CGPoint) throws -> CGFloat {
        return 0.0
    }

    public mutating func add(ball: Ball) throws {
        guard bounds.contains(ball.bounds) else {
            /// TODO: Throw an error.
            return
        }
        balls.append(ball)
    }
}
