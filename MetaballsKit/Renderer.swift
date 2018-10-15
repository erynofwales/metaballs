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

protocol RendererDelegate {
    var renderSize: Size { get set }
    var field: Field { get }
    var marchingSquares: MarchingSquares { get }
    var metalView: MTKView { get }
}

private struct RenderParameters {
    var projection: Matrix4x4
}

struct Vertex {
    let position: Float2
    let textureCoordinate: Float2
}

public class Renderer: NSObject, MTKViewDelegate {
    var delegate: RendererDelegate? = nil {
        didSet {
            guard let delegate = delegate else {
                return
            }

            let view = delegate.metalView
            view.device = device

            configurePixelPipeline(withPixelFormat: view.colorPixelFormat)
            configureMarchingSquaresPipeline(withPixelFormat: view.colorPixelFormat)

            delegate.field.setupMetal(withDevice: device)
            delegate.marchingSquares.setupMetal(withDevice: device, library: library)
            delegate.marchingSquares.populateGrid(withDevice: device)
        }
    }

    private var device: MTLDevice

    private lazy var library: MTLLibrary = {
        let bundle = Bundle(for: type(of: self))
        return try! device.makeDefaultLibrary(bundle: bundle)
    }()

    private var commandQueue: MTLCommandQueue
    private var pixelPipeline: MTLRenderPipelineState?
    private var marchingSquaresPipeline: MTLRenderPipelineState?

    private var pixelGeometry: [Vertex]?
    private var parametersBuffer: MTLBuffer?

    private var inFlightSemaphore: DispatchSemaphore

    override public init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Unable to create Metal system device")
        }
        guard let queue = device.makeCommandQueue() else {
            fatalError("Unable to create Metal command queue")
        }

        self.device = device
        commandQueue = queue

        let parametersLength = MemoryLayout<RenderParameters>.size
        parametersBuffer = device.makeBuffer(length: parametersLength, options: .storageModeShared)

        inFlightSemaphore = DispatchSemaphore(value: 1)

        super.init()
    }

    convenience init(delegate: RendererDelegate) throws {
        self.init()
        self.delegate = delegate
    }

    private func configurePixelPipeline(withPixelFormat pixelFormat: MTLPixelFormat) {
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
        guard let vertexShader = library.makeFunction(name: "gridVertexShader"),
              let fragmentShader = library.makeFunction(name: "gridFragmentShader") else {
            fatalError("Couldn't get marching squares vertex or fragment function from library")
        }

        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.label = "Grid Pipeline"
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

    private func pixelGeometry(forViewSize size: CGSize) -> [Vertex] {
        let w = Float(size.width)
        let h = Float(size.height)
        return [
            Vertex(position: Float2(x: w, y: h), textureCoordinate: Float2(x: 1, y: 1)),
            Vertex(position: Float2(x: 0, y: h), textureCoordinate: Float2(x: 0, y: 1)),
            Vertex(position: Float2(x: 0, y: 0), textureCoordinate: Float2(x: 0, y: 0)),

            Vertex(position: Float2(x: w, y: h), textureCoordinate: Float2(x: 1, y: 1)),
            Vertex(position: Float2(x: 0, y: 0), textureCoordinate: Float2(x: 0, y: 0)),
            Vertex(position: Float2(x: w, y: 0), textureCoordinate: Float2(x: 1, y: 0))
        ]
    }

    /// MARK: - MTKViewDelegate

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        delegate?.renderSize = Size(size: size)

        // Generate a new surface to draw the pixel version on
        pixelGeometry = pixelGeometry(forViewSize: size)

        // Reproject with the new aspect ratio.
        if let buffer = parametersBuffer {
            let projectionMatrix = Matrix4x4.orthographicProjection(top: 0, left: 0, bottom: Float(size.height), right: Float(size.width), near: -1.0, far: 1.0)
            let params = RenderParameters(projection: projectionMatrix)
            memcpy(buffer.contents(), [params], MemoryLayout<RenderParameters>.size)
        }
    }

    public func draw(in view: MTKView) {
        guard let field = delegate?.field else {
            return
        }
        guard let buffer = commandQueue.makeCommandBuffer() else {
            return
        }

        var didEncode = false

        // Make sure we attempt to enqueue more than one buffer at a time.
        inFlightSemaphore.wait()
        buffer.addCompletedHandler { _ in
            self.inFlightSemaphore.signal()
        }

        buffer.label = "Metaballs Command Buffer"

        field.update()
        if let ms = delegate?.marchingSquares {
            ms.populateParametersBuffer()
        }

        if self.pixelGeometry == nil {
            self.pixelGeometry = self.pixelGeometry(forViewSize: view.drawableSize)
        }
        let pixelGeometry = self.pixelGeometry!

        if let renderPass = view.currentRenderPassDescriptor {
            // Render the per-pixel metaballs
//            if let pipeline = pixelPipeline,
//               let encoder = buffer.makeRenderCommandEncoder(descriptor: renderPass) {
//                encoder.label = "Pixel Render"
//                encoder.setRenderPipelineState(pipeline)
//                encoder.setVertexBytes(pixelGeometry, length: pixelGeometry.count * MemoryLayout<Vertex>.stride, index: 0)
//                encoder.setVertexBuffer(parametersBuffer, offset: 0, index: 1)
//                encoder.setFragmentBuffer(field.parametersBuffer, offset: 0, index: 0)
//                encoder.setFragmentBuffer(field.ballBuffer, offset: 0, index: 1)
//                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
//                encoder.endEncoding()
//                didEncode = true
//            }

            if let marchingSquares = delegate?.marchingSquares {
                // Compute samples first.
                marchingSquares.encodeSamplingKernel(intoBuffer: buffer)

                // Render the marching squares version over top of the pixel version.
                // We need our own render pass descriptor that specifies that we load the results of the previous pass to make this render pass appear on top of the other.
                let pass = renderPass.copy() as! MTLRenderPassDescriptor
//                pass.colorAttachments[0].loadAction = .load
                if let pipeline = marchingSquaresPipeline,
                    let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) {
                    encoder.label = "Marching Squares Grid Render"
                    encoder.setRenderPipelineState(pipeline)
                    encoder.setVertexBytes(Rect.geometry, length: MemoryLayout<Vertex>.stride * Rect.geometry.count, index: 0)
                    encoder.setVertexBuffer(marchingSquares.gridGeometry, offset: 0, index: 1)
                    encoder.setVertexBuffer(parametersBuffer, offset: 0, index: 2)
                    encoder.setFragmentBuffer(marchingSquares.samplesBuffer, offset: 0, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: Rect.geometry.count, instanceCount: marchingSquares.samplesCount)
                    encoder.endEncoding()
                    didEncode = true
                }
            }
        }

        if didEncode, let drawable = view.currentDrawable {
            buffer.present(drawable)
        }
        buffer.commit()
    }
}
