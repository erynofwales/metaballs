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
    case couldntAddBall
}

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

public class Field {
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

    public func add(ball: Ball) throws {
        guard bounds.contains(ball.bounds) else {
            throw MetaballsError.couldntAddBall
        }
        balls.append(ball)
    }

    // MARK: - Metal Configuration

    /// Create a Metal buffer containing the current set of metaballs.
    /// @param device The Metal device to use to create the buffer.
    /// @return A new buffer containing metaball data.
    public func makeBallBuffer(withDevice device: MTLDevice) -> MTLBuffer? {
        let sizeOfBall = MemoryLayout<Ball>.size
        let length = balls.count * sizeOfBall
        var ballBuffer: MTLBuffer? = nil
        balls.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
            if let bytes = buffer.baseAddress {
                ballBuffer = device.makeBuffer(bytesNoCopy: bytes, length: length, options: [], deallocator: nil)
            }
        }
        return ballBuffer
    }

    /// Create a Metal texture to hold sample values created by the sampling compute shader.
    /// @param device The Metal device to use to create the texture.
    /// @return A new texture.
    public func makeSampleTexture(withDevice device: MTLDevice) -> MTLTexture? {
        let desc = MTLTextureDescriptor()
        desc.pixelFormat = .r16Float
        desc.width = Int(size.width)
        desc.height = Int(size.height)
        desc.usage = .shaderWrite
        let texture = device.makeTexture(descriptor: desc)
        return texture
    }

    public func computePipelineStateForSamplingKernel(withDevice device: MTLDevice) throws -> MTLComputePipelineState? {
        let library = device.newDefaultLibrary()
        if let samplingKernel = library?.makeFunction(name: "samplingKernel") {
            let computePipelineState = try device.makeComputePipelineState(function: samplingKernel)
            return computePipelineState
        }
        else {
            return nil
        }
    }

    public func computeEncoderForSamplingKernel(withCommandBuffer buffer: MTLCommandBuffer, state: MTLComputePipelineState, balls: MTLBuffer, samples: MTLTexture) -> MTLComputeCommandEncoder {
        let encoder = buffer.makeComputeCommandEncoder()
        encoder.setComputePipelineState(state)
        encoder.setBuffer(balls, offset: 0, at: 0)
        encoder.setTexture(samples, at: 0)
        // TODO: Decide on actual values for these
        let threadgroupsPerGrid = MTLSize()
        let threadsPerThreadgroup = MTLSize()
        encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        return encoder
    }
}
