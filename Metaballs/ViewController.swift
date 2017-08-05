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
    private var field = Field(size: CGSize()) {
        didSet {
            field.size = metalView.drawableSize
        }
    }

    private var renderer: Renderer!

    private var metalView: MTKView! {
        return self.view as! MTKView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let metalView = metalView else {
            view = newErrorView()
            print("self.view should be an MTKView; got \(type(of: self.view)) instead")
            return
        }

        do {
            renderer = try Renderer(view: metalView, field: field)
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

