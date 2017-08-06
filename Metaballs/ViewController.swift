//
//  ViewController.swift
//  Metaballs
//
//  Created by Eryn Wells on 7/30/17.
//  Copyright © 2017 Eryn Wells. All rights reserved.
//

import Cocoa
import MetalKit
import MetaballsKit

class ViewController: NSViewController, RendererDelegate {
    internal var field = Field(size: Size()) {
        didSet {
            field.size = Size(size: metalView.drawableSize)
        }
    }

    private var renderer: Renderer!

    internal var metalView: MTKView {
        return self.view as! MTKView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        do {
            renderer = try Renderer(delegate: self)
        } catch let e {
            print("\(e)")
            view = newErrorView()
            return
        }

        metalView.delegate = renderer
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        renderer.mtkView(metalView, drawableSizeWillChange: metalView.drawableSize)
        for _ in 1...10 {
            addBallWithRandomRadius()
        }
    }

    override func mouseDown(with event: NSEvent) {
        addBallWithRandomRadius()
    }

    override func rightMouseDown(with event: NSEvent) {
        field.clear()
        for _ in 1...10 {
            addBallWithRandomRadius()
        }
    }

    // MARK: - Private

    private func newErrorView() -> NSView {
        let view = NSView()
        view.layer?.backgroundColor = NSColor.red.cgColor
        return view
    }

    private func addBallWithRandomRadius() {
        let base = UInt32(view.bounds.width * 0.05)
        let variance = UInt32(base * 2)
        let r = Float(base + arc4random_uniform(variance))
        field.add(ballWithRadius: r)
    }

    // MARK: - RendererDelegate

    var renderSize: Size {
        get {
            return field.size
        }
        set {
            field.size = newValue
        }
    }
}

