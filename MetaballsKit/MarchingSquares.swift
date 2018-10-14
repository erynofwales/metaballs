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

    /// Samples of the field's current state.
    private(set) var samples: MTLTexture?
    /// Indexes of geometry to render.
    private(set) var indexes: MTLTexture?

    private var lastGridCount: Int = 0
    private(set) var gridGeometry: MTLBuffer?

    private var xSamples: Int {
        return Int(field.size.x / sampleGridSize.x)
    }

    private var ySamples: Int {
        return Int(field.size.y / sampleGridSize.y)
    }

    var samplesCount: Int {
        return xSamples * ySamples
    }

    init(field: Field) {
        self.field = field
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
        guard let gridGeometry = gridGeometry else {
            return
        }
        createGridGeometryBuffer(withDevice: gridGeometry.device)
        populateGrid(withDevice: gridGeometry.device)
    }

    func populateGrid(withDevice device: MTLDevice) {
        guard lastGridCount != samplesCount else {
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
                let rect = Rect(transform: transform, color: Float4(1.0))
                grid.append(rect)
            }
        }

        if let buffer = device.makeBuffer(length: MemoryLayout<Rect>.stride * samplesCount, options: .storageModeShared) {
            memcpy(buffer.contents(), grid, MemoryLayout<Rect>.stride * grid.count)
            gridGeometry = buffer
        } else {
            fatalError("Couldn't create buffer for grid rects")
        }

        lastGridCount = samplesCount
    }

    private func createGridGeometryBuffer(withDevice device: MTLDevice) {
        // Allocate a buffer with enough space for the rect vertex data, and all the rect instances we need to render.
        // [rect] [rect] ...

    }

    func sampleField() {
        guard let samples = samples else { return }

        let bytesPerRow = samples.width * MemoryLayout<Float>.stride

        for xSample in 0..<samples.width {
            let x = Float(xSample * Int(sampleGridSize.x))
            for ySample in 0..<samples.height {
                let y = Float(ySample * Int(sampleGridSize.y))
                let sample = [field.sample(at: Float2(x: x, y: y))]

                let origin = MTLOrigin(x: xSample, y: ySample, z: 0)
                let size = MTLSize(width: 1, height: 1, depth: 1)
                let region = MTLRegion(origin: origin, size: size)
                samples.replace(region: region, mipmapLevel: 0, withBytes: sample, bytesPerRow: bytesPerRow)
            }
        }
    }

    func populateIndexes() {
        guard let indexes = indexes else { return }

        let bytesPerRow = indexes.width * MemoryLayout<UInt8>.stride

        for x in 0..<indexes.width {
            for y in 0..<indexes.height {
                guard let samples = getSampleBlock(x: x, y: y) else {
                    continue
                }

                let index = (samples[0] > 1.0 ? 0b1000 : 0) +
                            (samples[1] > 1.0 ? 0b0100 : 0) +
                            (samples[2] > 1.0 ? 0b0001 : 0) +
                            (samples[3] > 1.0 ? 0b0010 : 0)

                let origin = MTLOrigin(x: x, y: y, z: 0)
                let size = MTLSize(width: 1, height: 1, depth: 1)
                let region = MTLRegion(origin: origin, size: size)
                let indexArr = [index]
                indexes.replace(region: region, mipmapLevel: 0, withBytes: indexArr, bytesPerRow: bytesPerRow)
            }
        }
    }

    private func getSampleBlock(x: Int, y: Int) -> [Float]? {
        guard let samples = samples else {
            return nil
        }

        var block: [Float] = [0, 0, 0, 0]
        let bytesPerRow = samples.width * MemoryLayout<Float>.stride
        let origin = MTLOrigin(x: x, y: y, z: 0)
        let size = MTLSize(width: 2, height: 2, depth: 1)
        let region = MTLRegion(origin: origin, size: size)
        samples.getBytes(&block, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

        return block
    }
}
