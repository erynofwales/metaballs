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
    case metalError
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
            updateThreadgroupSizes(withFieldSize: size)
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

    public func add(ball: Ball) {
        guard bounds.contains(ball.bounds) else { return }
        balls.append(ball)
    }

    // MARK: - Metal Configuration

    private var device: MTLDevice?
    private var sampleComputeState: MTLComputePipelineState?
    private var parametersBuffer: MTLBuffer?
    private var ballBuffer: MTLBuffer?
    private(set) var sampleTexture: MTLTexture?

    private var threadgroupCount = MTLSize()
    // TODO: It might be possible to (more dynamically) right-size this.
    private var threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)

    /// Create the Metal buffer containing basic parameters of the simulation.
    private func makeParametersBufferIfNeeded(withDevice device: MTLDevice) -> MTLBuffer? {
        if parametersBuffer == nil {
            parametersBuffer = device.makeBuffer(length: MemoryLayout<Int>.size * 3, options: [])
        }
        return parametersBuffer
    }

    /// Create a Metal buffer containing the current set of metaballs.
    /// @param device The Metal device to use to create the buffer.
    /// @return A new buffer containing metaball data.
    private func makeBallBufferIfNeeded(withDevice device: MTLDevice) -> MTLBuffer? {
        if ballBuffer == nil {
            let sizeOfBall = MemoryLayout<Ball>.size
            let length = balls.count * sizeOfBall
            balls.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
                if let bytes = buffer.baseAddress {
                    ballBuffer = device.makeBuffer(bytesNoCopy: bytes, length: length, options: [], deallocator: nil)
                }
            }
        }
        return ballBuffer
    }

    /// Create a Metal texture to hold sample values created by the sampling compute shader.
    /// @param device The Metal device to use to create the texture.
    /// @return A new texture.
    private func makeSampleTextureIfNeeded(withDevice device: MTLDevice) -> MTLTexture? {
        if sampleTexture == nil {
            let desc = MTLTextureDescriptor()
            desc.pixelFormat = .r16Float
            desc.width = Int(size.width)
            desc.height = Int(size.height)
            desc.usage = .shaderWrite
            sampleTexture = device.makeTexture(descriptor: desc)
        }
        return sampleTexture
    }

    /// Update the threadgroup divisions based on the size of the field.
    /// @param size The size of the field.
    private func updateThreadgroupSizes(withFieldSize size: CGSize) {
        let width = Int(size.width)
        let height = Int(size.height)
        threadgroupCount = MTLSize(width: width + threadgroupSize.width - 1, height: height + threadgroupSize.height - 1, depth: 1)
    }

    /// Copy metaballs data into the parameters buffer.
    private func updateParametersBuffer() {
        guard let parameters = parametersBuffer else {
            return
        }

        var ptr = parameters.contents()
        let sizeOfInt = MemoryLayout<Int>.size
        
        var width = Int(size.width)
        ptr.copyBytes(from: &width, count: sizeOfInt)
        ptr = ptr.advanced(by: sizeOfInt)

        var height = Int(size.height)
        ptr.copyBytes(from: &height, count: sizeOfInt)
        ptr = ptr.advanced(by: sizeOfInt)

        var numberOfBalls = balls.count
        ptr.copyBytes(from: &numberOfBalls, count: sizeOfInt)
    }

    public func setupMetal(withDevice device: MTLDevice) throws {
        guard self.device == nil else {
            return
        }
        self.device = device
        do {
            sampleComputeState = try computePipelineStateForSamplingKernel(withDevice: device)
        }
        catch let e {
            throw e
        }
    }

    public func computePipelineStateForSamplingKernel(withDevice device: MTLDevice) throws -> MTLComputePipelineState? {
        do {
            guard let samplingKernelLibraryPath = Bundle.main.path(forResource: "SamplingKernel", ofType: "metal") else {
                return nil
            }
            let library = try device.makeLibrary(filepath: samplingKernelLibraryPath)
            guard let samplingKernel = library.makeFunction(name: "samplingKernel") else {
                return nil
            }
            let state = try device.makeComputePipelineState(function: samplingKernel)
            return state
        }
        catch let e {
            throw e
        }
    }

    public func computeEncoderForSamplingKernel(withDevice device: MTLDevice, commandBuffer buffer: MTLCommandBuffer) throws -> MTLComputeCommandEncoder {
        guard let parametersBuffer = makeParametersBufferIfNeeded(withDevice: device),
              let ballBuffer = makeBallBufferIfNeeded(withDevice: device),
              let sampleTexture = makeSampleTextureIfNeeded(withDevice: device),
              let state = sampleComputeState
        else {
            throw MetaballsError.metalError
        }

        let encoder = buffer.makeComputeCommandEncoder()
        encoder.setComputePipelineState(state)
        encoder.setBuffer(parametersBuffer, offset: 0, at: 0)
        encoder.setBuffer(ballBuffer, offset: 0, at: 1)
        encoder.setTexture(sampleTexture, at: 0)
        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()

        updateParametersBuffer()

        return encoder
    }
}
