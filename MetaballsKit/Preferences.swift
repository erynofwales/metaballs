//
//  Preferences.swift
//  Metaballs
//
//  Created by Eryn Wells on 8/14/17.
//  Copyright © 2017 Eryn Wells. All rights reserved.
//

import Cocoa

extension UserDefaults {
    public var target: Float {
        get {
            if let obj = object(forKey: "target") as? NSNumber {
                return obj.floatValue
            } else {
                let defaultValue: Float = 1.0
                set(defaultValue, forKey: "target")
                return defaultValue
            }
        }
        set {
            set(newValue, forKey: "target")
        }
    }

    public var feather: Float {
        get {
            if let obj = object(forKey: "feather") as? NSNumber {
                return obj.floatValue
            } else {
                let defaultValue: Float = 0.25
                set(defaultValue, forKey: "target")
                return defaultValue
            }
        }
        set {
            set(newValue, forKey: "feather")
        }
    }

    public var colorStyle: ColorStyle? {
        get {
            let value = integer(forKey: "colorStyle")
            if let colorStyle = ColorStyle(rawValue: UInt32(value)) {
                return colorStyle
            }
            return nil
        }
        set {
            if let style = newValue {
                set(style.rawValue, forKey: "colorStyle")
            } else {
                set(nil as Any?, forKey: "colorStyle")
            }
        }
    }

    public var color0: Float4? {
        get {
            return float4(forKey: "color0")
        }
        set {
            set(newValue, forKey: "color0")
        }
    }

    public var color1: Float4? {
        get {
            return float4(forKey: "color1")
        }
        set {
            set(newValue, forKey: "color1")
        }
    }

    public var color2: Float4? {
        get {
            return float4(forKey: "color2")
        }
        set {
            set(newValue, forKey: "color2")
        }
    }

    public var color3: Float4? {
        get {
            return float4(forKey: "color3")
        }
        set {
            set(newValue, forKey: "color3")
        }
    }

    public var colorRotation: Float {
        get {
            if let obj = object(forKey: "colorRotation") as? NSNumber {
                return obj.floatValue
            } else {
                let defaultValue: Float = 0.0
                set(defaultValue, forKey: "colorRotation")
                return defaultValue
            }
        }
        set {
            set(newValue, forKey: "colorRotation")
        }
    }

    func float4(forKey key: String) -> Float4? {
        guard let values = array(forKey: key) as? [Float], values.count >= 4 else {
            return nil
        }
        return Float4(values[0], values[1], values[2], values[3])
    }

    func set(_ value: Float4?, forKey key: String) {
        if let value = value {
            set([Float](float4: value), forKey: key)
        } else {
            set(nil as Any?, forKey: key)
        }
    }
}
