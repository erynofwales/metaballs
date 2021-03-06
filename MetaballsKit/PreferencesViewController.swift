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

    var allowsRotation: Bool {
        return colorNames.count > 1
    }
}

public class PreferencesViewController: NSViewController {
    private static var styleItems: [StyleItem] {
        return [
            StyleItem(name: NSLocalizedString("Single Color", comment: "single color menu item"),
                      tag: Int(ColorStyle.singleColor.rawValue),
                      colorNames: [NSLocalizedString("A", comment: "first color")]),
            StyleItem(name: NSLocalizedString("Two Color Gradient", comment: "two color gradient menu item"),
                      tag: Int(ColorStyle.gradient2.rawValue),
                      colorNames: [NSLocalizedString("A", comment: "first color"),
                                   NSLocalizedString("B", comment: "second color")]),
            StyleItem(name: NSLocalizedString("Four Color Gradient", comment: "four color gradient menu item"),
                      tag: Int(ColorStyle.gradient4.rawValue),
                      colorNames: [NSLocalizedString("A", comment: "first color"),
                                   NSLocalizedString("B", comment: "second color"),
                                   NSLocalizedString("C", comment: "third color"),
                                   NSLocalizedString("D", comment: "fourth color")]),
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

    private lazy var colorRotationSlider: RotationSliderView = {
        let rotationSlider = RotationSliderView(label: NSLocalizedString("Color θ", comment: "name of color rotation slider"))
        rotationSlider.slider.target = self
        rotationSlider.slider.action = #selector(PreferencesViewController.sliderDidUpdate(sender:))
        rotationSlider.slider.floatValue = self.defaults.colorRotation
        return rotationSlider
    }()

    private lazy var targetSlider: SliderView = {
        let targetSlider = SliderView(label: NSLocalizedString("Target", comment: "name of the target slider"))
        if #available(OSX 10.12.2, *) {
            targetSlider.slider.trackFillColor = nil
        }
        targetSlider.slider.minValue = 0
        targetSlider.slider.maxValue = 1
        targetSlider.slider.target = self
        targetSlider.slider.action = #selector(PreferencesViewController.sliderDidUpdate(sender:))
        targetSlider.slider.floatValue = self.defaults.target
        return targetSlider
    }()

    private lazy var featherSlider: SliderView = {
        let featherSlider = SliderView(label: NSLocalizedString("Feather", comment: "name of the feather slider"))
        if #available(OSX 10.12.2, *) {
            featherSlider.slider.trackFillColor = nil
        }
        featherSlider.slider.minValue = 0
        featherSlider.slider.maxValue = 1
        featherSlider.slider.target = self
        featherSlider.slider.action = #selector(PreferencesViewController.sliderDidUpdate(sender:))
        featherSlider.slider.floatValue = self.defaults.feather
        return featherSlider
    }()

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
        centerX.priority = NSLayoutConstraint.Priority(rawValue: 999)
        let centerY = colorStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        centerY.priority = NSLayoutConstraint.Priority(rawValue: 999)
        NSLayoutConstraint.activate([
            centerX, centerY,
            colorStackView.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor, constant: 8),
            colorStackView.leftAnchor.constraint(greaterThanOrEqualTo: view.leftAnchor, constant: 8),
            colorStackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -8),
            colorStackView.rightAnchor.constraint(lessThanOrEqualTo: view.rightAnchor, constant: -8),
        ])

        colorStackView.addArrangedSubview(styleMenu)
        for i in 0..<4 {
            let colorView = ColorView(label: "Color \(i+1)")
            colorView.translatesAutoresizingMaskIntoConstraints = false
            colorStackView.addArrangedSubview(colorView)
            colorViews.append(colorView)
        }
        colorStackView.addArrangedSubview(colorRotationSlider)

        colorStackView.addArrangedSubview(targetSlider)
        colorStackView.addArrangedSubview(featherSlider)

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
        NSColorPanel.shared.close()
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
        let colorPanel = NSColorPanel.shared
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

    @objc func colorPanelDidUpdateValue(_ colorPanel: NSColorPanel) {
        postColorNotification()
    }

    @objc func styleDidUpdate(sender: NSMenuItem) {
        updateColorViewVisibility()
        postColorNotification()
    }

    @objc func sliderDidUpdate(sender: NSSlider) {
        postColorNotification()
    }

    @objc func closeWindow() {
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

        // Hide the color rotation slider if there's only one color
        colorRotationSlider.isHidden = styleItem.colorNames.count == 1
    }

    func postColorNotification() {
        var info = [String:Any]()
        if let item = styleMenu.selectedItem {
            info["colorStyle"] = ColorStyle(rawValue: UInt32(item.tag))
        }
        for (idx, cv) in colorViews.enumerated() {
            info["color\(idx)"] = cv.colorWell.color
        }
        info["target"] = targetSlider.slider.floatValue
        info["feather"] = featherSlider.slider.floatValue
        info["colorRotation"] = colorRotationSlider.slider.floatValue
        NotificationCenter.default.post(name: PreferencesDidChange_Color, object: nil, userInfo: info)
    }
}

class ParameterView: NSView {
    private let stackView = NSStackView()
    internal let control: NSControl
    internal let label: NSTextField

    init(frame f: NSRect, control c: NSControl, label: String = "Hello") {
        control = c
        self.label = NSTextField(labelWithString: label)
        super.init(frame: f)
        commonInit()
    }

    convenience init(control c: NSControl) {
        self.init(frame: NSRect(), control: c)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func commonInit() {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.spacing = 12
        stackView.alignment = .centerY
        stackView.distribution = .fill

        label.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(label)

        control.translatesAutoresizingMaskIntoConstraints = false
        control.setContentHuggingPriority(NSLayoutConstraint.Priority(rawValue: 251), for: .horizontal)
        stackView.addArrangedSubview(control)

        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leftAnchor.constraint(equalTo: leftAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.rightAnchor.constraint(equalTo: rightAnchor),
        ])
    }
}

class ColorView: ParameterView {
    var colorWell: NSColorWell {
        return control as! NSColorWell
    }

    init(label: String) {
        super.init(frame: NSRect(), control: NSColorWell(), label: label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SliderView: ParameterView {
    var slider: NSSlider {
        return control as! NSSlider
    }

    init(label: String) {
        super.init(frame: NSRect(), control: NSSlider(), label: label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class RotationSliderView: SliderView {
    override init(label: String) {
        super.init(label: label)

        let slider = control as! NSSlider
        slider.minValue = -Double.pi
        slider.maxValue = Double.pi
        slider.numberOfTickMarks = 5
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
