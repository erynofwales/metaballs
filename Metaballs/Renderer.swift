//
//  Renderer.swift
//  Metaballs
//
//  Created by Eryn Wells on 7/30/17.
//  Copyright © 2017 Eryn Wells. All rights reserved.
//

import Foundation
import MetaballsKit
import MetalKit

enum RendererError: Error {
    case MetalError(String)
}

protocol RendererDelegate {
    var renderSize: CGSize { get set }
    var field: Field { get }
}

struct Vertex {
    let x: Float
    let y: Float
    let texX: Float
    let texY: Float
}

class Renderer: NSObject, MTKViewDelegate {
    var delegate: RendererDelegate?

    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var renderPipelineState: MTLRenderPipelineState

    init(view: MTKView, field: Field) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RendererError.MetalError("Unable to create Metal system device")
        }
        self.device = device
        view.device = device
        do {
            try field.setupMetal(withDevice: device)
        } catch let e {
            throw e
        }

        let library = try device.makeDefaultLibrary(bundle: Bundle.main)
        let vertexShader = library.makeFunction(name: "passthroughVertexShader")
        let fragmentShader = library.makeFunction(name: "sampleToColorShader")

        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.label = "Render Pipeline"
        pipelineStateDescriptor.vertexFunction = vertexShader
        pipelineStateDescriptor.fragmentFunction = fragmentShader
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)

        commandQueue = device.makeCommandQueue()
        super.init()
    }

    /// MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        delegate?.renderSize = size
        // TODO: Reallocate the sample buffer and texture
    }

    func draw(in view: MTKView) {
        guard let field = delegate?.field else {
            return
        }

        // Two triangles, plus texture coordinates.
        let points: [Vertex] = [Vertex(x: 1, y: -1, texX: 1, texY: 0),
                                Vertex(x: -1, y: -1, texX: 0, texY: 0),
                                Vertex(x: -1, y: 1, texX: 0, texY: 1),

                                Vertex(x: 1, y: -1, texX: 1, texY: 0),
                                Vertex(x: -1, y: 1, texX: 0, texY: 1),
                                Vertex(x: 1, y: 1, texX: 1, texY: 1)]

        let buffer = commandQueue.makeCommandBuffer()
        do {
            let _ = try field.computeEncoderForSamplingKernel(withDevice: device, commandBuffer: buffer)
            buffer.commit()
        } catch let e {
            print("\(e)")
        }

        if let renderPass = view.currentRenderPassDescriptor {
            let encoder = buffer.makeRenderCommandEncoder(descriptor: renderPass)
            encoder.label = "Render Pass"
            encoder.setViewport(MTLViewport(originX: 0.0, originY: 0.0, width: Double(view.drawableSize.width), height: Double(view.drawableSize.height), znear: -1.0, zfar: 1.0))
            encoder.setRenderPipelineState(renderPipelineState)
            encoder.setVertexBytes(points, length: points.count * MemoryLayout<Vertex>.size, at: 0)
            encoder.setFragmentTexture(field.sampleTexture, at: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()

            if let drawable = view.currentDrawable {
                buffer.present(drawable)
            }
        }
        buffer.commit()
    }
}
