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

    var sampleGridSize = Size(16) {
        didSet {
            fieldDidResize()
        }
    }

    private var semaphore: DispatchSemaphore

    /// Compute pipeline for sampling the field.
    private var samplingPipeline: MTLComputePipelineState?
    /// Compute pipeline for calculating the contours based on a grid of samples.
    private var contouringPipeline: MTLComputePipelineState?

    private var parametersBuffer: MTLBuffer?
    /// Samples of the field's current state.
    private(set) var samplesBuffer: MTLBuffer?
    /// Indexes of geometry to render.
    private(set) var contourIndexesBuffer: MTLBuffer?

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

    var contourIndexesCount: Int {
        return (xSamples - 1) * (ySamples - 1)
    }

    init(field: Field) {
        self.field = field
        semaphore = DispatchSemaphore(value: 1)
    }

    func setupMetal(withDevice device: MTLDevice, library: MTLLibrary) {
        samplingPipeline = createComputePipeline(withFunctionNamed: "samplingKernel", device: device, library: library)
        contouringPipeline = createComputePipeline(withFunctionNamed: "contouringKernel", device: device, library: library)
        createParametersBuffer(withDevice: device)
        createSamplesBuffer(withDevice: device)
        createContourIndexesBuffer(withDevice: device)
    }

    func createComputePipeline(withFunctionNamed functionName: String, device: MTLDevice, library: MTLLibrary) -> MTLComputePipelineState? {
        guard let function = library.makeFunction(name: functionName) else {
            print("Couldn't get comput function \"\(functionName)\" from library")
            return nil
        }
        do {
            return try device.makeComputePipelineState(function: function)
        } catch let e {
            print("Error building compute pipeline state: \(e)")
            return nil
        }
    }

    func createParametersBuffer(withDevice device: MTLDevice) {
        // TODO: I'm cheating on this cause I didn't want to make a parallel struct in Swift and deal with alignment crap. >_> I should make a real struct for this.
        let parametersLength = MemoryLayout<packed_int2>.stride * 3 + MemoryLayout<uint>.stride
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

    func createContourIndexesBuffer(withDevice device: MTLDevice) {
        // Only reallocate the buffer if the length changed.
        let length = MemoryLayout<ushort>.stride * contourIndexesCount
        guard contourIndexesBuffer?.length != length else {
            return
        }
        contourIndexesBuffer = device.makeBuffer(length: length, options: .storageModePrivate)
        if contourIndexesBuffer == nil {
            fatalError("Couldn't create contourIndexesBuffer!")
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

        encoder.label = "Sampling"
        encoder.setComputePipelineState(samplingPipeline)
        encoder.setBuffer(parametersBuffer, offset: 0, index: 0)
        encoder.setBuffer(field.ballBuffer, offset: 0, index: 1)
        encoder.setBuffer(samplesBuffer, offset: 0, index: 2)

        // Dispatch!
        // TODO: Kernel threadgroup size limit is 256. Figure out how to make this work.
        let gridSize = MTLSize(width: xSamples, height: ySamples, depth: 1)
        let threadgroupSize = MTLSize(width: xSamples, height: 1, depth: 1)
        encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)

        encoder.endEncoding()
    }

    func encodeContouringKernel(intoBuffer buffer: MTLCommandBuffer) {
        guard let pipeline = contouringPipeline else {
            print("Encode called before contouring pipeline was set up!")
            return
        }
        guard let encoder = buffer.makeComputeCommandEncoder() else {
            print("Couldn't create compute encoder")
            return
        }

        encoder.label = "Contouring"
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(parametersBuffer, offset: 0, index: 0)
        encoder.setBuffer(samplesBuffer, offset: 0, index: 1)
        encoder.setBuffer(contourIndexesBuffer, offset: 0, index: 2)

        // Dispatch!
        let gridSize = MTLSize(width: contourIndexesCount, height: 1, depth: 1)
        let threadgroupSize = MTLSize(width: xSamples - 1, height: 1, depth: 1)
        encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)

        encoder.endEncoding()
    }
}

struct Variants {
    static let geometry: [Float] = [
        // 0: no triangles
        // 1: lower left corner, 1 triangle
        0.0, 1.0, 
        0.5, 1.0, 
        0.0, 0.5,
        // 2: lower right corner, 1 triangle
        1.0, 1.0, 
        0.5, 1.0, 
        1.0, 0.5, 
        // 3: bottom half, 2 triangles
        0.0, 1.0,
        1.0, 1.0,
        0.0, 0.5,
        0.0, 0.5,
        1.0, 1.0,
        1.0, 0.5,
        // 4: top right corner, 1 triangle
        1.0, 0.0,
        1.0, 0.5,
        0.5, 0.0,
        // 5: top right and bottom left, 2 triangles
        1.0, 0.0,
        0.5, 0.0,
        1.0, 0.5,
        0.0, 1.0,
        0.0, 0.5,
        0.5, 1.0,
        // 6: right half, 2 triangles
        0.0, 0.0,
        0.0, 1.0,
        0.5, 0.0,
        0.5, 0.0,
        0.0, 1.0,
        0.5, 1.0,
        // 7: bottom right corner 7/8ths, 3 triangles
        0.0, 0.5,
        0.5, 0.0,
        0.0, 1.0,
        0.0, 1.0,
        0.5, 0.0,
        1.0, 0.0,
        1.0, 0.0,
        0.0, 1.0,
        1.0, 1.0,
        // 8: top left corner, 1 triangle
        0.0, 0.0,
        0.0, 0.5,
        0.5, 0.0,
        // 9: left half, 2 triangles
        0.5, 0.0,
        0.5, 1.0,
        1.0, 0.0,
        1.0, 0.0,
        0.5, 1.0,
        1.0, 1.0,
        // 10: top left and bottom right, 2 triangles
        0.0, 0.0,
        0.0, 0.5,
        0.5, 0.0,
        1.0, 1.0,
        0.5, 1.0,
        1.0, 0.5,
        // 11: bottom left corner 7/8th, 3 triangles
        0.5, 0.0,
        1.0, 0.5,
        0.0, 0.0,
        0.0, 0.0,
        0.5, 0.0,
        1.0, 1.0,
        1.0, 1.0,
        0.0, 1.0,
        0.0, 0.0,
        // 12: top half, 2 triangles
        0.0, 0.0,
        0.0, 0.5,
        1.0, 0.0,
        1.0, 0.0,
        0.0, 0.5,
        1.0, 0.5,
        // 13: top left corner 7/8ths, 3 triangles
        0.5, 1.0,
        1.0, 0.5,
        1.0, 0.0,
        1.0, 0.0,
        0.5, 1.0,
        0.0, 1.0,
        0.0, 1.0,
        1.0, 0.0,
        0.0, 0.0,
        // 14: top right corner 7/8th, 3 triangles
        0.0, 0.5,
        0.5, 1.0,
        1.0, 1.0,
        1.0, 1.0,
        0.0, 0.5,
        0.0, 0.0,
        0.0, 0.0,
        1.0, 1.0,
        1.0, 0.0,
        // 15: full, 2 triangles
        0.0, 0.0,
        0.0, 1.0,
        1.0, 1.0,
        0.0, 0.0,
        1.0, 1.0,
        1.0, 0.0,
    ]

    static func numberOfTriangles(for variation: UInt) -> UInt {
        switch variation {
        case 0: return 0
        case 1: return 1
        case 2: return 1
        case 3: return 2
        case 4: return 1
        case 5: return 4
        case 6: return 2
        case 7: return 3
        case 8: return 1
        case 9: return 2
        case 10: return 4
        case 11: return 3
        case 12: return 2
        case 13: return 3
        case 14: return 3
        case 15: return 2
        default: return 0
        }
    }

    static func startingIndex(for variation: UInt) -> UInt {
        switch variation {
        case 0: return 0
        case 1: return 0
        case 2: return 3
        case 3: return 6
        case 4: return 10
        case 5: return 13
        case 6: return 19
        case 7: return 23
        case 8: return 28
        case 9: return 31
        case 10: return 35
        case 11: return 41
        case 12: return 46
        case 13: return 50
        case 14: return 55
        case 15: return 60
        default: return 0
        }
    }

    var buffer: MTLBuffer?
}
