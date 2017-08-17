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
    private static func defaultParameters() -> Parameters {
        var p = Parameters()
        let defaults = UserDefaults.standard
        let style = defaults.colorStyle ?? .gradient2Horizontal
        p.colorStyle = style
        let color0 = defaults.color0 ?? Float4(0.50, 0.79, 1, 1)
        p.color0 = color0
        let color1 = defaults.color1 ?? Float4(0.88, 0.50, 1, 1)
        p.color1 = color1
        return p
    }

    internal var field: Field {
        didSet {
            field.size = Size(size: metalView.drawableSize)
        }
    }

    private var renderer: Renderer!

    internal var metalView: MTKView {
        return self.view as! MTKView
    }

    override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        let params = ViewController.defaultParameters()
        field = Field(parameters: params)
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        let params = ViewController.defaultParameters()
        field = Field(parameters: params)
        super.init(coder: coder)
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

