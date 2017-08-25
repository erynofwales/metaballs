//
//  PreferencesViewController.swift
//  Metaballs
//
//  Created by Eryn Wells on 8/12/17.
//  Copyright © 2017 Eryn Wells. All rights reserved.
//

import Cocoa

internal let PreferencesDidChange_Color = Notification.Name("PreferencesDidChange_Color")

private struct StyleItem {
    let name: String
    let tag: Int
    let colorNames: [String]
}

public class PreferencesViewController: NSViewController {
    private static var styleItems: [StyleItem] {
        return [
            StyleItem(name: NSLocalizedString("Single Color", comment: "single color menu item"),
                      tag: Int(ColorStyle.singleColor.rawValue),
                      colorNames: [NSLocalizedString("Color", comment: "single color name")]),
            StyleItem(name: NSLocalizedString("Two Color Gradient — Horizontal", comment: "two color horizontal gradient menu item"),
                      tag: Int(ColorStyle.gradient2Horizontal.rawValue),
                      colorNames: [NSLocalizedString("Right", comment: "two color horizontal gradient, color 1"),
                                   NSLocalizedString("Left", comment: "two color horizontal gradient, color 2")]),
        ]
    }

    public var defaults = UserDefaults.standard
    public var showsCloseButton: Bool = true {
        didSet {
            showCloseButtonIfNeeded()
        }
    }

    private var colorStackView = NSStackView()
    private var colorViews = [ColorView]()

    private lazy var styleMenu: NSPopUpButton = {
        let button = NSPopUpButton()
        button.translatesAutoresizingMaskIntoConstraints = false

        let menu = NSMenu()
        for item in PreferencesViewController.styleItems {
            // TODO: Set action here.
            let menuItem = NSMenuItem(title: item.name, action: #selector(PreferencesViewController.styleDidUpdate(sender:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.tag = item.tag
            menu.addItem(menuItem)
        }
        button.menu = menu

        return button
    }()

    private lazy var closeView: NSView = {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let buttonTitle = NSLocalizedString("Close", comment: "close button label")
        let button = NSButton(title: buttonTitle, target: self, action: #selector(PreferencesViewController.closeWindow))
        button.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        return container
    }()

    override public func loadView() {
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

        showCloseButtonIfNeeded()

        self.view = view
    }


    override public func viewWillAppear() {
        super.viewWillAppear()
        if let style = defaults.colorStyle {
            styleMenu.selectItem(withTag: Int(style.rawValue))
            updateColorViewVisibility()
        }
        prepareColorViews()
        prepareColorPanel()
    }

    override public func viewWillDisappear() {
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

    private func showCloseButtonIfNeeded() {
        if showsCloseButton {
            colorStackView.addArrangedSubview(closeView)
        } else {
            colorStackView.removeArrangedSubview(closeView)
        }
    }

    // MARK: - Actions

    func colorPanelDidUpdateValue(_ colorPanel: NSColorPanel) {
        postColorNotification()
    }

    func styleDidUpdate(sender: NSMenuItem) {
        updateColorViewVisibility()
        postColorNotification()
    }

    func closeWindow() {
        self.view.window?.close()
    }

    // MARK: - Private

    func updateColorViewVisibility() {
        let idx = styleMenu.indexOfSelectedItem
        guard idx != -1 && idx < PreferencesViewController.styleItems.count else { return }
        let styleItem = PreferencesViewController.styleItems[idx]
        for (idx, colorView) in colorViews.enumerated() {
            if idx < styleItem.colorNames.count {
                colorView.isHidden = false
                colorView.label.stringValue = styleItem.colorNames[idx]
            } else {
                colorView.isHidden = true
            }
        }
    }

    func postColorNotification() {
        var info = [String:Any]()
        if let item = styleMenu.selectedItem {
            info["colorStyle"] = ColorStyle(rawValue: UInt16(item.tag))
        }
        for (idx, cv) in colorViews.enumerated() {
            info["color\(idx)"] = cv.colorWell.color
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
