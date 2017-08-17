//
//  Preferences.swift
//  Metaballs
//
//  Created by Eryn Wells on 8/14/17.
//  Copyright © 2017 Eryn Wells. All rights reserved.
//

import Cocoa

extension UserDefaults {
    var color0: Float4? {
        get {
            return float4(forKey: "color0")
        }
        set {
            set(newValue, forKey: "color0")
        }
    }

    var color1: Float4? {
        get {
            return float4(forKey: "color1")
        }
        set {
            set(newValue, forKey: "color1")
        }
    }

    var color2: Float4? {
        get {
            return float4(forKey: "color2")
        }
        set {
            set(newValue, forKey: "color2")
        }
    }

    var color3: Float4? {
        get {
            return float4(forKey: "color3")
        }
        set {
            set(newValue, forKey: "color3")
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
