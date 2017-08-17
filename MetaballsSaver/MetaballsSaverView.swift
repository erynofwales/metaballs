//
//  MetaballsSaverView.swift
//  Metaballs
//
//  Created by Eryn Wells on 8/16/17.
//  Copyright © 2017 Eryn Wells. All rights reserved.
//

import Foundation
import MetaballsKit
import MetalKit
import ScreenSaver

class MetaballsSaverView: ScreenSaverView, RendererDelegate {
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

    public var metalView: MTKView

    public var field: Field {
        didSet {
            field.size = Size(size: metalView.drawableSize)
        }
    }

    internal var renderer: RendererDelegate

    override init?(frame: NSRect, isPreview: Bool) {
        let params = MetaballsSaverView.defaultParameters()
        field = Field(parameters: params)

        metalView = MTKView()
        metalView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(metalView)
        NSLayoutConstraint.activate([
            metalView.topAnchor.constraint(equalTo: topAnchor),
            metalView.leftAnchor.constraint(equalTo: leftAnchor),
            metalView.bottomAnchor.constraint(equalTo: bottomAnchor),
            metalView.rightAnchor.constraint(equalTo: rightAnchor),
        ])

        do {
            renderer = try Renderer(delegate: self)
        } catch let e {
            fatalError("\(e)")
        }

        super.init(frame: frame, isPreview: isPreview)
    }
    
    required init?(coder: NSCoder) {
        let params = MetaballsSaverView.defaultParameters()
        field = Field(parameters: params)

        metalView = MTKView()
        metalView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(metalView)
        NSLayoutConstraint.activate([
            metalView.topAnchor.constraint(equalTo: topAnchor),
            metalView.leftAnchor.constraint(equalTo: leftAnchor),
            metalView.bottomAnchor.constraint(equalTo: bottomAnchor),
            metalView.rightAnchor.constraint(equalTo: rightAnchor),
        ])

        do {
            renderer = try Renderer(delegate: self)
        } catch let e {
            fatalError("\(e)")
        }

        super.init(coder: coder)
    }

    override func animateOneFrame() {

    }

    // MARK: - RendererDelegate

    public var renderSize: Size {
        get {
            return field.size
        }
        set {
            field.size = newValue
        }
    }
}
