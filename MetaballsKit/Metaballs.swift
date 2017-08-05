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
//                updateThreadgroupSizes(withFieldSize: size)
//                parametersBuffer = nil
//                sampleTexture = nil
                if numberOfBallsBeforeFilter != balls.count {
                    ballBuffer = nil
                }
                do {
                    try updateBuffers()
                } catch let e {
                    NSLog("Error updating size: \(e)")
                    return
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
        for var ball in balls {
            // Update position of ball.
            ball.update()

            if !selfBounds.contains(ball.position.CGPoint) {
                // Degenerate case. If the ball finds itself outside the bounds of the field, plop it back in the center.
                ball.position = Point(x: Float(selfBounds.midX), y: Float(selfBounds.midY))
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

    public func add(ballWithRadius radius: Float) {
        let insetBounds = bounds.insetBy(dx: CGFloat(radius), dy: CGFloat(radius))
//        let x = CGFloat(UInt32(insetBounds.minX) + arc4random_uniform(UInt32(insetBounds.width)))
//        let y = CGFloat(UInt32(insetBounds.minY) + arc4random_uniform(UInt32(insetBounds.height)))
        let position = Point(x: Float(insetBounds.midX), y: Float(insetBounds.midY))
        // TODO: Randomly generate velocity too.
        let ball = Ball(radius: radius, position: position, velocity: Vector())
        balls.append(ball)
        NSLog("Added ball \(ball); fieldSize=\(size)")
    }

    // MARK: - Metal Configuration

    private var device: MTLDevice?
//    private var sampleComputeState: MTLComputePipelineState?
    public private(set) var parametersBuffer: MTLBuffer?
    public private(set) var ballBuffer: MTLBuffer?
//    public private(set) var sampleTexture: MTLTexture?

//    private var threadgroupCount = MTLSize()
    // TODO: It might be possible to (more dynamically) right-size this.
//    private var threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)

    /// Create the Metal buffer containing basic parameters of the simulation.
    private func makeParametersBufferIfNeeded(withDevice device: MTLDevice) -> MTLBuffer? {
        if parametersBuffer == nil {
            parametersBuffer = device.makeBuffer(length: MemoryLayout<Int>.stride * 3, options: [])
        }
        return parametersBuffer
    }

    /// Create a Metal buffer containing the current set of metaballs.
    /// @param device The Metal device to use to create the buffer.
    /// @return A new buffer containing metaball data.
    private func makeBallBufferIfNeeded(withDevice device: MTLDevice) -> MTLBuffer? {
        if ballBuffer == nil && balls.count > 0 {
            let sizeOfBall = MemoryLayout<Float>.stride * 3     // A Ball in shader-land is a float3.
            let length = balls.count * sizeOfBall
            ballBuffer = device.makeBuffer(length: length, options: [])
        }
        return ballBuffer
    }

    /// Create a Metal texture to hold sample values created by the sampling compute shader.
    /// @param device The Metal device to use to create the texture.
    /// @return A new texture.
//    private func makeSampleTextureIfNeeded(withDevice device: MTLDevice) -> MTLTexture? {
//        if sampleTexture == nil {
//            let desc = MTLTextureDescriptor()
//            desc.pixelFormat = .r16Float
//            desc.width = Int(size.width)
//            desc.height = Int(size.height)
//            desc.usage = [.shaderWrite, .shaderRead]
//            sampleTexture = device.makeTexture(descriptor: desc)
//        }
//        return sampleTexture
//    }

    /// Update the threadgroup divisions based on the size of the field.
    /// @param size The size of the field.
//    private func updateThreadgroupSizes(withFieldSize size: CGSize) {
//        let width = Int(size.width)
//        let height = Int(size.height)
//        threadgroupCount = MTLSize(width: width + threadgroupSize.width - 1, height: height + threadgroupSize.height - 1, depth: 1)
//    }

    /// Copy metaballs data into the parameters buffer.
    public func updateBuffers() throws {
        guard let device = self.device else {
            throw MetaballsError.metalError("Missing Metal device for update")
        }

        guard let parameters = makeParametersBufferIfNeeded(withDevice: device),
              let balls = makeBallBufferIfNeeded(withDevice: device)
        else {
            throw MetaballsError.metalError("Couldn't create buffers")
        }

        var ptr = parameters.contents()
        
        var width = Int(size.width)
        ptr = write(value: &width, to: ptr)
        var height = Int(size.height)
        ptr = write(value: &height, to: ptr)

        var numberOfBalls = self.balls.count
        ptr = write(value: &numberOfBalls, to: ptr)

        ptr = balls.contents()
        for var ball in self.balls {
            ptr = write(value: &ball.position.x, to: ptr)
            ptr = write(value: &ball.position.y, to: ptr)
            var r = ball.radius
            ptr = write(value: &r, to: ptr)
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
//        sampleComputeState = try computePipelineStateForSamplingKernel(withDevice: device)
        parametersBuffer = makeParametersBufferIfNeeded(withDevice: device)
        ballBuffer = makeBallBufferIfNeeded(withDevice: device)
    }

//    public func computePipelineStateForSamplingKernel(withDevice device: MTLDevice) throws -> MTLComputePipelineState? {
//        let bundle = Bundle(for: type(of: self))
//        let library = try device.makeDefaultLibrary(bundle: bundle)
//        guard let samplingKernel = library.makeFunction(name: "sampleFieldKernel") else {
//            throw MetaballsError.metalError("Unable to create sampling kernel function")
//        }
//        let state = try device.makeComputePipelineState(function: samplingKernel)
//        return state
//    }

//    public func computeEncoderForSamplingKernel(withDevice device: MTLDevice, commandBuffer buffer: MTLCommandBuffer) throws -> MTLComputeCommandEncoder {
//        guard let parametersBuffer = makeParametersBufferIfNeeded(withDevice: device),
//              let ballBuffer = makeBallBufferIfNeeded(withDevice: device),
//              let sampleTexture = makeSampleTextureIfNeeded(withDevice: device),
//              let state = sampleComputeState
//        else {
//            throw MetaballsError.metalError("Missing Metal buffers or compute state")
//        }
//
//        let encoder = buffer.makeComputeCommandEncoder()
//        encoder.setComputePipelineState(state)
//        encoder.setBuffer(parametersBuffer, offset: 0, at: 0)
//        encoder.setBuffer(ballBuffer, offset: 0, at: 1)
//        encoder.setTexture(sampleTexture, at: 0)
//        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
//        encoder.endEncoding()
//
//        updateParametersBuffer()
//
//        return encoder
//    }
}
