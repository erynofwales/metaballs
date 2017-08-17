//
//  PreferencesViewController.swift
//  Metaballs
//
//  Created by Eryn Wells on 8/12/17.
//  Copyright © 2017 Eryn Wells. All rights reserved.
//

import Cocoa

internal let PreferencesDidChange_Color = Notification.Name("PreferencesDidChange_Color")

class PreferencesViewController: NSViewController {
    private static var styleItems: [(name: String, tag: Int)] {
        return [
            (name: NSLocalizedString("Single Color", comment: "single color menu item"),
             tag: Int(ColorStyle.singleColor.rawValue)),
            (name: NSLocalizedString("Two Color Gradient — Horizontal", comment: "two color horizontal gradient menu item"),
             tag: Int(ColorStyle.gradient2Horizontal.rawValue)),
        ]
    }

    public var defaults = UserDefaults.standard

    private var colorStackView = NSStackView()
    private var colorViews = [ColorView]()

    private lazy var styleMenu: NSPopUpButton = {
        let button = NSPopUpButton()
        button.translatesAutoresizingMaskIntoConstraints = false

        let menu = NSMenu()
        for item in PreferencesViewController.styleItems {
            // TODO: Set action here.
            let menuItem = NSMenuItem(title: item.name, action: nil, keyEquivalent: "")
            menuItem.target = self
            menuItem.tag = item.tag
            menu.addItem(menuItem)
        }
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
        prepareColorPanel()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        NSColorPanel.shared().close()
    }

    private func prepareColorViews() {
        for (idx, cv) in colorViews.enumerated() {
            if let fColor = defaults.float4(forKey: "color\(idx)") {
                let color = NSColor(float4: fColor)
                cv.colorWell.color = color
            }
        }
    }

    private func prepareColorPanel() {
        let colorPanel = NSColorPanel.shared()
        colorPanel.isContinuous = true
        colorPanel.setTarget(self)
        colorPanel.setAction(#selector(PreferencesViewController.colorPanelDidUpdateValue))
    }

    func colorPanelDidUpdateValue(_ colorPanel: NSColorPanel) {
        // TODO: Post a notification about color change.
//        print("color panel did update: \(colorPanel.color)")
        var info = [String:NSColor]()
        for (idx, cv) in colorViews.enumerated() {
            if cv.colorWell.isActive {
                info["color\(idx)"] = colorPanel.color
            } else {
                info["color\(idx)"] = cv.colorWell.color
            }
        }
        NotificationCenter.default.post(name: PreferencesDidChange_Color, object: nil, userInfo: info)
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
