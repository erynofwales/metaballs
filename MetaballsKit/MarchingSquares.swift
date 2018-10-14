//
//  MarchingSquares.swift
//  Metaballs
//
//  Created by Eryn Wells on 10/11/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

import Foundation
import Metal

class MarchingSquares {
    private var field: Field
    private var sampleGridSize = Size(16)

    private var semaphore: DispatchSemaphore

    /// Samples of the field's current state.
    private(set) var samplesBuffer: MTLBuffer?
    /// Indexes of geometry to render.
    private(set) var indexes: MTLTexture?

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

    func setupMetal(withDevice device: MTLDevice) {
//        let samplesDesc = MTLTextureDescriptor()
//        samplesDesc.textureType = .type2D
//        samplesDesc.width = xSamples
//        samplesDesc.height = ySamples
//        samplesDesc.pixelFormat = .r32Float
//        samples = device.makeTexture(descriptor: samplesDesc)
//
//        let indexesDesc = MTLTextureDescriptor()
//        indexesDesc.textureType = .type2D
//        indexesDesc.width = xSamples - 1
//        indexesDesc.height = ySamples - 1
//        indexesDesc.pixelFormat = .a8Unorm
//        indexes = device.makeTexture(descriptor: indexesDesc)
    }

    func fieldDidResize() {
        guard let device = gridGeometry?.device else {
            return
        }
        populateGrid(withDevice: device)
        populateSamples(withDevice: device)
        lastSamplesCount = samplesCount
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

    func populateSamples(withDevice device: MTLDevice) {
        print("Populating samples buffer with \(samplesCount) values")

        var samples = [Float]()
        samples.reserveCapacity(samplesCount)

        for ys in 0..<ySamples {
            let y = Float(ys * Int(sampleGridSize.y))
            for xs in 0..<xSamples {
                let x = Float(xs * Int(sampleGridSize.x))
                let sample = field.sample(at: Float2(x: x, y: y))
                samples.append(sample)
            }
        }

        let samplesLength = MemoryLayout<Float>.stride * samplesCount
        if let buffer = device.makeBuffer(length: MemoryLayout<Float>.stride * samples.count, options: .storageModeShared) {
            memcpy(buffer.contents(), samples, samplesLength)
            samplesBuffer = buffer
        } else {
            fatalError("Couldn't create buffer for samples")
        }
    }
}
