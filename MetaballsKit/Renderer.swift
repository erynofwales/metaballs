//
//  Renderer.swift
//  Metaballs
//
//  Created by Eryn Wells on 7/30/17.
//  Copyright © 2017 Eryn Wells. All rights reserved.
//

import Foundation
import MetalKit

public enum RendererError: Error {
    case MetalError(String)
}

public protocol RendererDelegate {
    var renderSize: Size { get set }
    var field: Field { get }
    var metalView: MTKView { get }
}

struct Vertex {
    let position: Float2
    let textureCoordinate: Float2
}

public class Renderer: NSObject, MTKViewDelegate {
    public var delegate: RendererDelegate? = nil {
        didSet {
            guard let delegate = delegate else {
                return
            }

            let view = delegate.metalView
            view.device = device

            do {
                let bundle = Bundle(for: type(of: self))
                let library = try device.makeDefaultLibrary(bundle: bundle)
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

                try delegate.field.setupMetal(withDevice: device)
            } catch let e {
                fatalError("\(e)")
            }
        }
    }

    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var renderPipelineState: MTLRenderPipelineState? = nil

    override public init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Unable to create Metal system device")
        }
        guard let queue = device.makeCommandQueue() else {
            fatalError("Unable to create Metal command queue")
        }

        self.device = device
        commandQueue = queue

        super.init()
    }

    public convenience init(delegate: RendererDelegate) throws {
        self.init()
        self.delegate = delegate
    }

    /// MARK: - MTKViewDelegate

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        delegate?.renderSize = Size(size: size)
    }

    public func draw(in view: MTKView) {
        guard let field = delegate?.field else {
            return
        }

        // Two triangles, plus texture coordinates.
        let points: [Vertex] = [
            Vertex(position: Float2(x:  1, y: -1), textureCoordinate: Float2(x: 1, y: 0)),
            Vertex(position: Float2(x: -1, y: -1), textureCoordinate: Float2(x: 0, y: 0)),
            Vertex(position: Float2(x: -1, y:  1), textureCoordinate: Float2(x: 0, y: 1)),

            Vertex(position: Float2(x:  1, y: -1), textureCoordinate: Float2(x: 1, y: 0)),
            Vertex(position: Float2(x: -1, y:  1), textureCoordinate: Float2(x: 0, y: 1)),
            Vertex(position: Float2(x:  1, y:  1), textureCoordinate: Float2(x: 1, y: 1))
        ]

        field.update()

        if let buffer = commandQueue.makeCommandBuffer() {
            buffer.label = "Render"

            if let renderPass = view.currentRenderPassDescriptor, let renderPipelineState = renderPipelineState, let encoder = buffer.makeRenderCommandEncoder(descriptor: renderPass) {
                encoder.label = "Render Pass"
                encoder.setViewport(MTLViewport(originX: 0.0, originY: 0.0, width: Double(view.drawableSize.width), height: Double(view.drawableSize.height), znear: -1.0, zfar: 1.0))
                encoder.setRenderPipelineState(renderPipelineState)
                encoder.setVertexBytes(points, length: points.count * MemoryLayout<Vertex>.stride, index: 0)
                encoder.setFragmentBuffer(field.parametersBuffer, offset: 0, index: 0)
                encoder.setFragmentBuffer(field.ballBuffer, offset: 0, index: 1)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                encoder.endEncoding()

                if let drawable = view.currentDrawable {
                    buffer.present(drawable)
                }
            }
            buffer.commit()
        }
    }
}
