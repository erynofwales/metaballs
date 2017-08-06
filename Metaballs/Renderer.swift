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
    var renderSize: Size { get set }
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
        if let renderAttachment = pipelineStateDescriptor.colorAttachments[0] {
            renderAttachment.pixelFormat = view.colorPixelFormat
            // Pulled all this from SO. I don't know what all this does...
            // https://stackoverflow.com/q/43727335/1174185
            renderAttachment.isBlendingEnabled = true
            renderAttachment.alphaBlendOperation = .add
            renderAttachment.rgbBlendOperation = .add
            renderAttachment.sourceRGBBlendFactor = .sourceAlpha
            renderAttachment.sourceAlphaBlendFactor = .sourceAlpha
            renderAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            renderAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }
        renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)

        commandQueue = device.makeCommandQueue()
        super.init()
    }

    /// MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        delegate.renderSize = Size(size: size)
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

        field.update()

        let buffer = commandQueue.makeCommandBuffer()
        buffer.label = "Render"

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
