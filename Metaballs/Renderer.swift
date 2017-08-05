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
    var metalView: MTKView { get }
}

struct Point {
    let x: Float
    let y: Float
}

struct Vertex {
    let position: Point
    let textureCoordinate: Point
}

class Renderer: NSObject, MTKViewDelegate {
    var delegate: RendererDelegate

    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var renderPipelineState: MTLRenderPipelineState

    init(delegate: RendererDelegate) throws {
        self.delegate = delegate

        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RendererError.MetalError("Unable to create Metal system device")
        }
        let view = delegate.metalView

        self.device = device
        view.device = device

        try delegate.field.setupMetal(withDevice: device)

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
        delegate.renderSize = size
        // TODO: Reallocate the sample buffer and texture
    }

    func draw(in view: MTKView) {
        let field = delegate.field

        // Two triangles, plus texture coordinates.
        let points: [Vertex] = [
            Vertex(position: Point(x:  1, y: -1), textureCoordinate: Point(x: 1, y: 0)),
            Vertex(position: Point(x: -1, y: -1), textureCoordinate: Point(x: 0, y: 0)),
            Vertex(position: Point(x: -1, y:  1), textureCoordinate: Point(x: 0, y: 1)),

            Vertex(position: Point(x:  1, y: -1), textureCoordinate: Point(x: 1, y: 0)),
            Vertex(position: Point(x: -1, y:  1), textureCoordinate: Point(x: 0, y: 1)),
            Vertex(position: Point(x:  1, y:  1), textureCoordinate: Point(x: 1, y: 1))
        ]

        do {
            try field.updateBuffers()
        } catch let e {
            NSLog("Error updating buffers: \(e)")
        }

        let buffer = commandQueue.makeCommandBuffer()
        buffer.label = "Render"

//        do {
//            let _ = try field.computeEncoderForSamplingKernel(withDevice: device, commandBuffer: buffer)
//        } catch let e {
//            print("\(e)")
//        }

        if let renderPass = view.currentRenderPassDescriptor {
            let encoder = buffer.makeRenderCommandEncoder(descriptor: renderPass)
            encoder.label = "Render Pass"
            encoder.setViewport(MTLViewport(originX: 0.0, originY: 0.0, width: Double(view.drawableSize.width), height: Double(view.drawableSize.height), znear: -1.0, zfar: 1.0))
            encoder.setRenderPipelineState(renderPipelineState)
            encoder.setVertexBytes(points, length: points.count * MemoryLayout<Vertex>.stride, at: 0)
            encoder.setFragmentBuffer(field.parametersBuffer, offset: 0, at: 0)
            encoder.setFragmentBuffer(field.ballBuffer, offset: 0, at: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()

            if let drawable = view.currentDrawable {
                buffer.present(drawable)
            }
        }
        buffer.commit()
    }
}
