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

            configurePixelPipeline(withPixelFormat: view.colorPixelFormat)
            configureMarchingSquaresPipeline(withPixelFormat: view.colorPixelFormat)

            try! delegate.field.setupMetal(withDevice: device)
        }
    }

    private var device: MTLDevice

    private lazy var library: MTLLibrary? = {
        let bundle = Bundle(for: type(of: self))
        return try? device.makeDefaultLibrary(bundle: bundle)
    }()

    private var commandQueue: MTLCommandQueue
    private var pixelPipeline: MTLRenderPipelineState?
    private var marchingSquaresPipeline: MTLRenderPipelineState?

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

    private func configurePixelPipeline(withPixelFormat pixelFormat: MTLPixelFormat) {
        guard let library = library else {
            fatalError("Couldn't get Metal library")
        }

        let vertexShader = library.makeFunction(name: "passthroughVertexShader")
        let fragmentShader = library.makeFunction(name: "sampleToColorShader")

        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.label = "Pixel Pipeline"
        pipelineDesc.vertexFunction = vertexShader
        pipelineDesc.fragmentFunction = fragmentShader
        if let renderAttachment = pipelineDesc.colorAttachments[0] {
            renderAttachment.pixelFormat = pixelFormat
            // Pulled all this from SO. I don't know what it means, but it makes the alpha channel work.
            // TODO: Learn what this means???
            // https://stackoverflow.com/q/43727335/1174185
            renderAttachment.isBlendingEnabled = true
            renderAttachment.alphaBlendOperation = .add
            renderAttachment.rgbBlendOperation = .add
            renderAttachment.sourceRGBBlendFactor = .sourceAlpha
            renderAttachment.sourceAlphaBlendFactor = .sourceAlpha
            renderAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            renderAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }

        do {
            pixelPipeline = try device.makeRenderPipelineState(descriptor: pipelineDesc)
        } catch let e {
            print("Couldn't set up pixel pipeline! \(e)")
            pixelPipeline = nil
        }
    }

    private func configureMarchingSquaresPipeline(withPixelFormat pixelFormat: MTLPixelFormat) {
        guard let library = library else {
            fatalError("Couldn't get Metal library")
        }

        let vertexShader = library.makeFunction(name: "passthroughVertexShader")
        let fragmentShader = library.makeFunction(name: "passthroughFragmentShader")

        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.label = "Marching Squares Pipeline"
        pipelineDesc.vertexFunction = vertexShader
        pipelineDesc.fragmentFunction = fragmentShader
        if let renderAttachment = pipelineDesc.colorAttachments[0] {
            renderAttachment.pixelFormat = pixelFormat
            // Pulled all this from SO. I don't know what it means, but it makes the alpha channel work.
            // TODO: Learn what this means???
            // https://stackoverflow.com/q/43727335/1174185
            renderAttachment.isBlendingEnabled = true
            renderAttachment.alphaBlendOperation = .add
            renderAttachment.rgbBlendOperation = .add
            renderAttachment.sourceRGBBlendFactor = .sourceAlpha
            renderAttachment.sourceAlphaBlendFactor = .sourceAlpha
            renderAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            renderAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }

        do {
            marchingSquaresPipeline = try device.makeRenderPipelineState(descriptor: pipelineDesc)
        } catch let e {
            print("Couldn't set up marching squares pipeline! \(e)")
            marchingSquaresPipeline = nil
        }
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

        if let buffer = commandQueue.makeCommandBuffer(),
           let renderPass = view.currentRenderPassDescriptor {
            buffer.label = "Metaballs Command Buffer"
            var didEncode = false

            if let pipeline = pixelPipeline,
               let encoder = buffer.makeRenderCommandEncoder(descriptor: renderPass) {
                encoder.label = "Pixel Render"
                encoder.setViewport(MTLViewport(originX: 0.0, originY: 0.0, width: Double(view.drawableSize.width), height: Double(view.drawableSize.height), znear: -1.0, zfar: 1.0))
                encoder.setRenderPipelineState(pipeline)
                encoder.setVertexBytes(points, length: points.count * MemoryLayout<Vertex>.stride, index: 0)
                encoder.setFragmentBuffer(field.parametersBuffer, offset: 0, index: 0)
                encoder.setFragmentBuffer(field.ballBuffer, offset: 0, index: 1)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                encoder.endEncoding()
                didEncode = true
            }

            let pass = renderPass.copy() as! MTLRenderPassDescriptor
            pass.colorAttachments[0].loadAction = .load
            if let pipeline = marchingSquaresPipeline,
               let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) {
                encoder.label = "Marching Squares Render"
                encoder.setRenderPipelineState(pipeline)
                encoder.setVertexBytes(points, length: points.count * MemoryLayout<Vertex>.stride, index: 0)
                encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: 6)
                encoder.endEncoding()
                didEncode = true
            }

            if didEncode, let drawable = view.currentDrawable {
                buffer.present(drawable)
            }
            buffer.commit()
        }
    }
}
