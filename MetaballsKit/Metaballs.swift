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

public struct Parameters {
    /// Metal's short type. 2 bytes, 2 byte aligned
    typealias Short = UInt16
    /// Metal's short2 type. 2 bytes per int, 4 bytes, 4 byte aligned
    typealias Short2 = (UInt16, UInt16)
    /// Metal's float4 type. 4 bytes per float, 16 bytes total, 16 byte aligned.
    typealias Color4 = (r: Float, g: Float, b: Float, a: Float)

    // Simulation parameters
    var size: Size
    var numberOfBalls: Short
    // 4 bytes unused

    // Color parameters
    var topLeft: Color4
    var topRight: Color4
    var bottomLeft: Color4
    var bottomRight: Color4

    public static var size: Int {
        var size = 0
        size += MemoryLayout<Size>.stride
        size += MemoryLayout<Short>.stride
        size += 2+8
        size += 4 * MemoryLayout<Color4>.stride
        return size
    }

    public init() {
        size = Size(width: 0, height: 0)
        numberOfBalls = 0
        topLeft = (0, 0, 0, 0)
        topRight = (0, 0, 0, 0)
        bottomLeft = (0, 0, 0, 0)
        bottomRight = (0, 0, 0, 0)
    }

    public mutating func write(to buffer: MTLBuffer, offset: Int = 0) {
        let start = buffer.contents().advanced(by: offset)
        var ptr = start

        let simBegin = ptr
        ptr = ptr.writeAndAdvance(value: &size)
        ptr = ptr.writeAndAdvance(value: &numberOfBalls)
        ptr = ptr.advanced(by: 2+8)   // Skip 10 bytes to maintain alignment.
        let simLength = simBegin.distance(to: ptr)
        buffer.addDebugMarker("Simulation Parameters", range: NSRange(location: start.distance(to: simBegin), length: simLength))

        ptr = ptr.writeAndAdvance(value: &topLeft)
        ptr = ptr.writeAndAdvance(value: &topRight)
        ptr = ptr.writeAndAdvance(value: &bottomLeft)
        ptr = ptr.writeAndAdvance(value: &bottomRight)

        NSLog("Populated parameters: size:\(size), n:\(numberOfBalls)")
    }
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
    public var size: Size {
        get {
            return parameters.size
        }
        set {
            if parameters.size != newValue {
                NSLog("Updating size of field: old:\(parameters.size), new:\(newValue)")

                // Scale balls to new position and size.
                let scale = parameters.size.width != 0 ? Float(newValue.width / parameters.size.width) : 1
                balls = balls.map {
                    let r = $0.radius * scale
                    let p = randomPoint(forBallWithRadius: r)
                    let v = Vector(dx: $0.velocity.dx * scale, dy: $0.velocity.dy * scale)
                    return Ball(radius: r, position: p, velocity: v)
                }

                // Update Metal state as needed.
                populateParametersBuffer()
                populateBallBuffer()

                parameters.size = newValue
            }
        }
    }

    private(set) var balls = [Ball]()

    private var parameters = Parameters()

    internal var bounds: CGRect {
        return CGRect(origin: CGPoint(), size: CGSize(size: size))
    }

    public init(size s: Size) {
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
        let position = randomPoint(forBallWithRadius: radius)

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

    private func randomPoint(forBallWithRadius radius: Float) -> Point {
        let insetBounds = bounds.insetBy(dx: CGFloat(radius), dy: CGFloat(radius))
        let x = Float(UInt32(insetBounds.minX) + arc4random_uniform(UInt32(insetBounds.width)))
        let y = Float(UInt32(insetBounds.minY) + arc4random_uniform(UInt32(insetBounds.height)))
        let position = Point(x: x, y: y)
        return position
    }

    // MARK: - Metal Configuration

    private var device: MTLDevice?
    public private(set) var parametersBuffer: MTLBuffer?
    public private(set) var ballBuffer: MTLBuffer?

    /// Create the Metal buffer containing basic parameters of the simulation.
    private func populateParametersBuffer() {
        if parametersBuffer == nil {
            guard let device = self.device else { return }
            let length = Parameters.size
            parametersBuffer = device.makeBuffer(length: length, options: [])
            NSLog("Making parameters buffer, length:\(length)")
        }

        if let parametersBuffer = parametersBuffer {
            parameters.numberOfBalls = Parameters.Short(balls.count)
            self.parameters.write(to: parametersBuffer)
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
