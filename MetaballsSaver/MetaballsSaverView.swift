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

public class MetaballsSaverView: ScreenSaverView, RendererDelegate {
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

    internal var renderer: Renderer

    override public init?(frame: NSRect, isPreview: Bool) {
        let params = MetaballsSaverView.defaultParameters()
        metalView = MetalView()
        field = Field(parameters: params)
        field.size = Size(size: frame.size)
        renderer = Renderer()

        super.init(frame: frame, isPreview: isPreview)

        animationTimeInterval = 1 / 30.0
    }
    
    required public init?(coder: NSCoder) {
        fatalError("initWithCoder: not implemented")
    }

    override public func startAnimation() {
        if metalView.superview == nil {
            metalView.isPaused = true   // Don't use the Metal View's internal timer.
            metalView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(metalView)
            NSLayoutConstraint.activate([
                metalView.topAnchor.constraint(equalTo: topAnchor),
                metalView.leftAnchor.constraint(equalTo: leftAnchor),
                metalView.bottomAnchor.constraint(equalTo: bottomAnchor),
                metalView.rightAnchor.constraint(equalTo: rightAnchor),
            ])
            renderer.delegate = self
        }

        for _ in 1...10 {
            addBallWithRandomRadius()
        }

        super.startAnimation()
    }

    override public func stopAnimation() {
        super.stopAnimation()
    }

    override public func animateOneFrame() {
        metalView.draw()
    }

    override public func hasConfigureSheet() -> Bool {
        return true
    }

    override public func configureSheet() -> NSWindow? {
        let prefs = PreferencesViewController()
        prefs.showsCloseButton = true
        let window = NSWindow(contentViewController: prefs)
        return window
    }

    // MARK: - NSView

    override public func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        NSLog("Resizing: \(newSize)")
    }

    // MARK: - Private

    private func addBallWithRandomRadius() {
        let base = UInt32(bounds.width * 0.05)
        let variance = UInt32(base * 2)
        let r = Float(base + arc4random_uniform(variance))
        field.add(ballWithRadius: r)
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

class MetalView: MTKView {
    override var isOpaque: Bool {
        return true
    }
}
