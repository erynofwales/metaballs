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
    private var sampleGridSize: Size

    /// Samples of the field's current state.
    private(set) var samples: MTLTexture?
    /// Indexes of geometry to render.
    private(set) var indexes: MTLTexture?

    init(field: Field) {
        self.field = field
        sampleGridSize = Size(16)
    }

    func setupMetal(withDevice device: MTLDevice) {
        let xSamples = Int(field.size.x / sampleGridSize.x)
        let ySamples = Int(field.size.y / sampleGridSize.y)

        let samplesDesc = MTLTextureDescriptor()
        samplesDesc.textureType = .type2D
        samplesDesc.width = xSamples
        samplesDesc.height = ySamples
        samplesDesc.pixelFormat = .depth32Float
        samples = device.makeTexture(descriptor: samplesDesc)

        let indexesDesc = MTLTextureDescriptor()
        indexesDesc.textureType = .type2D
        indexesDesc.width = xSamples - 1
        indexesDesc.height = ySamples - 1
        indexesDesc.pixelFormat = .a8Unorm
        indexes = device.makeTexture(descriptor: indexesDesc)
    }

    func sampleField() {
        guard let samples = samples else { return }

        let xSamples = Int(field.size.x / sampleGridSize.x)
        let ySamples = Int(field.size.y / sampleGridSize.y)
        for xSample in 0..<xSamples {
            let x = Float(xSample * Int(sampleGridSize.x))
            for ySample in 0..<ySamples {
                let y = Float(ySample * Int(sampleGridSize.y))
                let sample = [field.sample(at: Float2(x: x, y: y))]

                let origin = MTLOrigin(x: xSample, y: ySample, z: 0)
                let size = MTLSize(width: 1, height: 1, depth: 1)
                let region = MTLRegion(origin: origin, size: size)
                let bytesPerRow = samples.width * MemoryLayout<Float>.stride
                samples.replace(region: region, mipmapLevel: 0, withBytes: sample, bytesPerRow: bytesPerRow)
            }
        }
    }
}
