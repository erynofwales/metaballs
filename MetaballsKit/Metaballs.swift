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

public enum ColorStyle: UInt16 {
    /// Single flat color
    case singleColor = 1
    /// Two color horizontal gradient
    case gradient2Horizontal = 2
    /// Two color vertical gradient
    case gradient2Vertical = 3
    /// Four color gradient from corners
    case gradient4Corners = 4
    /// Four color gradient from middle of sides
    case gradient4Sides = 5
}

public struct Parameters {
    public static var size: Int {
        let size = MemoryLayout<Parameters>.stride
        return size
    }

    // Simulation parameters
    var size = Size(width: 0, height: 0)
    var numberOfBalls: UInt16 = 0

    let unused1: UInt16 = 0xAB
    let unused2: UInt32 = 0xCDEF
    let unused3: UInt16 = 0xBA

    // Color parameters
    private var _colorStyle = ColorStyle.singleColor.rawValue
    public var color0 = Float4(r: 0, g: 1, b: 0, a: 1)
    public var color1 = Float4()
    public var color2 = Float4()
    public var color3 = Float4()

    public var colorStyle: ColorStyle {
        get {
            return ColorStyle(rawValue: _colorStyle)!
        }
        set {
            _colorStyle = newValue.rawValue
        }
    }

    public init() { }

    public mutating func write(to buffer: MTLBuffer, offset: Int = 0) {
        let start = buffer.contents().advanced(by: offset)
        let stride = MemoryLayout.stride(ofValue: self)
        start.copyBytes(from: &self, count: stride)
        NSLog("Populated parameters: size:\(size), n:\(numberOfBalls), style:\(colorStyle)(\(_colorStyle))")
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
            NSLog("Updating size of field: old:\(parameters.size), new:\(newValue)")
            if parameters.size != newValue {
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

    public var defaults = UserDefaults.standard
    private var parameters: Parameters

    internal var bounds: CGRect {
        return CGRect(origin: CGPoint(), size: CGSize(size: size))
    }

    public init(parameters p: Parameters) {
        parameters = p
        NotificationCenter.default.addObserver(self, selector: #selector(Field.preferencesDidChange(note:)), name: PreferencesDidChange_Color, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: PreferencesDidChange_Color, object: nil)
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
            parameters.numberOfBalls = UInt16(balls.count)
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

    // MARK: - Notifications

    @objc
    func preferencesDidChange(note: Notification) {
        guard let userInfo = note.userInfo else { return }
        var didChange = false
        if let style = userInfo["colorStyle"] as? ColorStyle {
            parameters.colorStyle = style
            defaults.colorStyle = style
            didChange = true
        }
        if let color = userInfo["color0"] as? NSColor {
            let cf = Float4(color: color)
            parameters.color0 = cf
            defaults.color0 = cf
            didChange = true
        }
        if let color = userInfo["color1"] as? NSColor {
            let cf = Float4(color: color)
            parameters.color1 = cf
            defaults.color1 = cf
            didChange = true
        }
        if let color = userInfo["color2"] as? NSColor {
            let cf = Float4(color: color)
            parameters.color2 = cf
            defaults.color2 = cf
            didChange = true
        }
        if let color = userInfo["color3"] as? NSColor {
            let cf = Float4(color: color)
            parameters.color3 = cf
            defaults.color3 = cf
            didChange = true
        }

        if didChange {
            populateParametersBuffer()
        }
    }
}
