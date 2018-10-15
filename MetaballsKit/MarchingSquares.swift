//
//  MarchingSquares.swift
//  Metaballs
//
//  Created by Eryn Wells on 10/11/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

import Foundation
import Metal
import simd

class MarchingSquares {
    private var field: Field
    private var sampleGridSize = Size(16)

    private var semaphore: DispatchSemaphore

    private var samplingPipeline: MTLComputePipelineState?

    private var parametersBuffer: MTLBuffer?
    /// Samples of the field's current state.
    private(set) var samplesBuffer: MTLBuffer?
    /// Indexes of geometry to render.
    private(set) var indexBuffer: MTLBuffer?

    private(set) var gridGeometry: MTLBuffer?

    private var xSamples: Int {
        return Int(field.size.x / sampleGridSize.x)
    }

    private var ySamples: Int {
        return Int(field.size.y / sampleGridSize.y)
    }

    private var lastSamplesCount = 0

    var samplesCount: Int {
        return xSamples * ySamples
    }

    init(field: Field) {
        self.field = field
        semaphore = DispatchSemaphore(value: 1)
    }

    func setupMetal(withDevice device: MTLDevice, library: MTLLibrary) {
        guard let samplingFunction = library.makeFunction(name: "samplingKernel") else {
            fatalError("Couldn't get samplingKernel function from library")
        }
        do {
            samplingPipeline = try device.makeComputePipelineState(function: samplingFunction)
        } catch let e {
            fatalError("Error building compute pipeline state for sampling kernel: \(e)")
        }

        createParametersBuffer(withDevice: device)
        createSamplesBuffer(withDevice: device)
    }

    func createParametersBuffer(withDevice device: MTLDevice) {
        // TODO: I'm cheating on this cause I didn't want to make a parallel struct in Swift and deal with alignment crap. >_> I should make a real struct for this.
        let parametersLength = MemoryLayout<simd.packed_int2>.stride * 3 + MemoryLayout<simd.uint>.stride
        parametersBuffer = device.makeBuffer(length: parametersLength, options: .storageModeShared)
    }

    func createSamplesBuffer(withDevice device: MTLDevice) {
        // Only reallocate the buffer if the length changed.
        let samplesLength = MemoryLayout<Float>.stride * samplesCount
        guard samplesBuffer?.length != samplesLength else {
            return
        }
        samplesBuffer = device.makeBuffer(length: samplesLength, options: .storageModePrivate)
        if samplesBuffer == nil {
            fatalError("Couldn't create samplesBuffer!")
        }
    }

    func fieldDidResize() {
        // Please just get the device from somewhere. 😅
        guard let device = gridGeometry?.device ?? samplesBuffer?.device else {
            return
        }
        populateParametersBuffer()
        populateGrid(withDevice: device)
        createSamplesBuffer(withDevice: device)
        lastSamplesCount = samplesCount
    }

    func populateParametersBuffer() {
        guard let buffer = parametersBuffer else {
            print("Tried to copy parameters buffer before buffer was allocated!")
            return
        }
        // TODO: I'm cheating on this cause I didn't want to make a parallel struct in Swift and deal with alignment crap. >_> I should make a real struct for this.
        let params: [uint] = [
            field.size.x, field.size.y,
            uint(xSamples), uint(ySamples),
            sampleGridSize.x, sampleGridSize.y,
            uint(field.balls.count)
        ]
        memcpy(buffer.contents(), params, MemoryLayout<uint>.stride * params.count)
    }

    func populateGrid(withDevice device: MTLDevice) {
        guard lastSamplesCount != samplesCount else {
            return
        }

        print("Populating grid with (\(xSamples), \(ySamples)) samples")

        let gridSizeX = Float(sampleGridSize.x)
        let gridSizeY = Float(sampleGridSize.y)

        var grid = [Rect]()
        grid.reserveCapacity(samplesCount)

        for y in 0..<ySamples {
            for x in 0..<xSamples {
                let transform = Matrix4x4.translation(dx: Float(x) * gridSizeX, dy: Float(y) * gridSizeY, dz: 0.0) * Matrix4x4.scale(x: gridSizeX, y: gridSizeY, z: 1)
                let color = Float4(r: 0, g: 1, b: 0, a: 1)
                let rect = Rect(transform: transform, color: color)
                grid.append(rect)
            }
        }

        if let buffer = device.makeBuffer(length: MemoryLayout<Rect>.stride * samplesCount, options: .storageModeShared) {
            memcpy(buffer.contents(), grid, MemoryLayout<Rect>.stride * grid.count)
            gridGeometry = buffer
        } else {
            fatalError("Couldn't create buffer for grid rects")
        }
    }

    func encodeSamplingKernel(intoBuffer buffer: MTLCommandBuffer) {
        guard let samplingPipeline = samplingPipeline else {
            print("Encode called before sampling pipeline was set up!")
            return
        }
        guard let encoder = buffer.makeComputeCommandEncoder() else {
            print("Couldn't create compute encoder")
            return
        }
        encoder.label = "Sample Field"
        encoder.setComputePipelineState(samplingPipeline)
        encoder.setBuffer(parametersBuffer, offset: 0, index: 0)
        encoder.setBuffer(field.ballBuffer, offset: 0, index: 1)
        encoder.setBuffer(samplesBuffer, offset: 0, index: 2)

        // Dispatch!
        let gridSize = MTLSize(width: xSamples, height: ySamples, depth: 1)
        let threadgroupSize = MTLSize(width: xSamples, height: 1, depth: 1)
        encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)

        encoder.endEncoding()
    }
}
