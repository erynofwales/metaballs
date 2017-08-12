//
//  PreferencesViewController.swift
//  Metaballs
//
//  Created by Eryn Wells on 8/12/17.
//  Copyright © 2017 Eryn Wells. All rights reserved.
//

import Cocoa

class PreferencesViewController: NSViewController {
    public var defaults = UserDefaults.standard

    private var colorStackView = NSStackView()
    private var colorViews = [ColorView]()

    private lazy var styleMenu: NSPopUpButton = {
        let button = NSPopUpButton()
        button.translatesAutoresizingMaskIntoConstraints = false

        let menu = NSMenu()
        menu.addItem(withTitle: NSLocalizedString("Single Color", comment: "single color menu item"), action: nil, keyEquivalent: "")
        menu.addItem(withTitle: NSLocalizedString("Two Color Gradient — Horizontal", comment: "two color horizontal gradient menu item"), action: nil, keyEquivalent: "")
        button.menu = menu

        return button
    }()

    override func loadView() {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        colorStackView.setAccessibilityIdentifier("colorStackView")
        colorStackView.translatesAutoresizingMaskIntoConstraints = false
        colorStackView.orientation = .vertical
        colorStackView.alignment = .left
        colorStackView.distribution = .fillProportionally
        colorStackView.spacing = 8
        view.addSubview(colorStackView)

        let centerX = colorStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        centerX.priority = 999
        let centerY = colorStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        centerY.priority = 999
        NSLayoutConstraint.activate([
            centerX, centerY,
            colorStackView.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor, constant: 8),
            colorStackView.leftAnchor.constraint(greaterThanOrEqualTo: view.leftAnchor, constant: 8),
            colorStackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -8),
            colorStackView.rightAnchor.constraint(lessThanOrEqualTo: view.rightAnchor, constant: -8),
        ])

        colorStackView.addArrangedSubview(styleMenu)
        for i in 0..<4 {
            let colorView = ColorView()
            colorView.translatesAutoresizingMaskIntoConstraints = false
            colorView.label.stringValue = "Color \(i+1)"
            colorStackView.addArrangedSubview(colorView)
            colorViews.append(colorView)
        }

        self.view = view
    }


    override func viewWillAppear() {
        super.viewWillAppear()
        prepareColorViews()
    }

    private func prepareColorViews() {
        guard let colors = defaults.array(forKey: "colors") else { return }
        for (idx, cv) in colorViews.enumerated() {
            if idx >= colors.count {
                continue
            }
            if let color = colors[idx] as? NSColor {
                cv.colorWell.color = color
            }
        }
    }
}

class ColorView: NSView {
    private let stackView = NSStackView()
    internal let colorWell = NSColorWell()
    internal let label = NSTextField(labelWithString: "Hello")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.spacing = 8
        stackView.alignment = .centerY
        stackView.distribution = .equalSpacing

        colorWell.translatesAutoresizingMaskIntoConstraints = false
        colorWell.setContentHuggingPriority(251, for: .horizontal)
        stackView.addArrangedSubview(colorWell)

        label.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(label)

        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leftAnchor.constraint(equalTo: leftAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.rightAnchor.constraint(equalTo: rightAnchor),
        ])
    }
}
