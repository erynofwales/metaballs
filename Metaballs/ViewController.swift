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
    internal var field = Field(size: CGSize()) {
        didSet {
            field.size = metalView.drawableSize
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
            let r = Float(20 + arc4random_uniform(50))
            field.add(ballWithRadius: r)
        }
    }

    private func newErrorView() -> NSView {
        let view = NSView()
        view.layer?.backgroundColor = NSColor.red.cgColor
        return view
    }

    // MARK: - RendererDelegate

    var renderSize: CGSize {
        get {
            return field.size
        }
        set {
            field.size = newValue
        }
    }
}

