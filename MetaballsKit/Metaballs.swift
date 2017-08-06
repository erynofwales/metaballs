//
//  Metaballs.swift
//  Metaballs
//
//  Created by Eryn Wells on 7/30/17.
//  Copyright © 2017 Eryn Wells. All rights reserved.
//

import Foundation
import MetalKit

public enum MetaballsError: Error {
    case metalError(String)
}

public struct Ball {
    let radius: Float
    var position = Point()
    var velocity = Vector()

    internal var bounds: CGRect {
        let diameter = CGFloat(radius * 2)
        return CGRect(x: CGFloat(position.x - radius), y: CGFloat(position.y - radius), width: diameter, height: diameter)
    }

    internal mutating func update() {
        position.x += velocity.dx
        position.y += velocity.dy
    }
}

extension Ball: CustomStringConvertible {
    public var description: String {
        return "<Ball p:\(position), r:\(radius), v:\(velocity)>"
    }
}

public class Field {
    public var size: CGSize {
        didSet {
            if size != oldValue {
                NSLog("Updating size of field: old:\(oldValue), new:\(size)")
                let numberOfBallsBeforeFilter = balls.count

                // Remove balls that fall outside the new bounds.
                balls = balls.filter { bounds.contains($0.bounds) }

                // Update Metal state as needed.
                populateParametersBuffer()
                if numberOfBallsBeforeFilter != balls.count {
                    ballBuffer = nil
                    populateBallBuffer()
                }
            }
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
        for i in 0..<balls.count {
            // Update position of ball.
            balls[i].update()

            if !selfBounds.contains(balls[i].position.CGPoint) {
                // Degenerate case. If the ball finds itself outside the bounds of the field, plop it back in the center.
                balls[i].position = Point(x: Float(selfBounds.midX), y: Float(selfBounds.midY))
            } else {
                // Do collision detection with walls.
                let ballBounds = balls[i].bounds
                if !selfBounds.contains(ballBounds) {
                    if ballBounds.minX < selfBounds.minX || ballBounds.maxX > selfBounds.maxX {
                        balls[i].velocity.dx *= -1
                    }
                    if ballBounds.minY < selfBounds.minY || ballBounds.maxY > selfBounds.maxY {
                        balls[i].velocity.dy *= -1
                    }
                }
            }
        }
        populateBallBuffer()
    }

    public func add(ballWithRadius radius: Float) {
        let insetBounds = bounds.insetBy(dx: CGFloat(radius), dy: CGFloat(radius))

        let x = Float(UInt32(insetBounds.minX) + arc4random_uniform(UInt32(insetBounds.width)))
        let y = Float(UInt32(insetBounds.minY) + arc4random_uniform(UInt32(insetBounds.height)))
        let position = Point(x: x, y: y)

        let dx = Float(5 - Int(arc4random_uniform(10)))
        let dy = Float(5 - Int(arc4random_uniform(10)))
        let velocity = Vector(dx: dx, dy: dy)

        let ball = Ball(radius: radius, position: position, velocity: velocity)
        balls.append(ball)
        NSLog("Added ball \(ball); fieldSize=\(size)")

        populateParametersBuffer()
        ballBuffer = nil
        populateBallBuffer()
    }

    public func clear() {
        balls.removeAll(keepingCapacity: true)
    }

    // MARK: - Metal Configuration

    private var device: MTLDevice?
    public private(set) var parametersBuffer: MTLBuffer?
    public private(set) var ballBuffer: MTLBuffer?

    /// Create the Metal buffer containing basic parameters of the simulation.
    private func populateParametersBuffer() {
        if parametersBuffer == nil {
            guard let device = self.device else { return }
            let length = 16     // A Parameters struct in shader-land is an int3, which takes 16 bytes.
            parametersBuffer = device.makeBuffer(length: length, options: [])
            NSLog("Making parameters buffer, length:\(length)")
        }

        if let parameters = parametersBuffer {
            var ptr = parameters.contents()
            var width = UInt32(size.width)
            parameters.addDebugMarker("Width", range: NSRange(location: parameters.contents().distance(to: ptr), length: 4))
            ptr = write(value: &width, to: ptr)
            var height = UInt32(size.height)
            parameters.addDebugMarker("Height", range: NSRange(location: parameters.contents().distance(to: ptr), length: 4))
            ptr = write(value: &height, to: ptr)
            var numberOfBalls = UInt32(self.balls.count)
            parameters.addDebugMarker("Number Of Balls", range: NSRange(location: parameters.contents().distance(to: ptr), length: 4))
            ptr = write(value: &numberOfBalls, to: ptr)
            NSLog("Populated parameters: w:\(width), h:\(height), n:\(numberOfBalls)")
        }
    }

    /// Create a Metal buffer containing the current set of metaballs.
    /// @param device The Metal device to use to create the buffer.
    /// @return A new buffer containing metaball data.
    private func populateBallBuffer() {
        if ballBuffer == nil && balls.count > 0 {
            guard let device = self.device else { return }
            let sizeOfBall = 16     // A Ball in shader-land is a float3, which takes 16 bytes.
            let length = balls.count * sizeOfBall
            NSLog("Making ball buffer, length:\(length)")
            ballBuffer = device.makeBuffer(length: length, options: [])
        }

        if let ballBuffer = ballBuffer {
            var ptr = ballBuffer.contents()
            var idx = 0
            for var ball in self.balls {
                ballBuffer.addDebugMarker("Ball \(idx)", range: NSRange(location: ballBuffer.contents().distance(to: ptr), length: 16))
                ptr = write(value: &ball.position.x, to: ptr)
                ptr = write(value: &ball.position.y, to: ptr)
                var r = ball.radius
                ptr = write(value: &r, to: ptr)
                ptr = ptr.advanced(by: 4)   // Skip 4 bytes to maintain alignment.
//                if idx == 0 {
//                    print("Populated ball \(idx): x:\(ball.position.x), y:\(ball.position.y), r:\(r)")
//                }
                idx += 1
            }
        }
    }

    private func write<T>(value: inout T, to ptr: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer {
        let sizeOfType = MemoryLayout<T>.stride
        ptr.copyBytes(from: &value, count: sizeOfType)
        return ptr.advanced(by: sizeOfType)
    }

    public func setupMetal(withDevice device: MTLDevice) throws {
        guard self.device == nil else {
            return
        }
        NSLog("Setting up Metal")
        self.device = device
        populateParametersBuffer()
        populateBallBuffer()
    }
}
