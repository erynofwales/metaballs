//
//  PreferencesWindowController.swift
//  Metaballs
//
//  Created by Eryn Wells on 8/15/17.
//  Copyright © 2017 Eryn Wells. All rights reserved.
//

import Cocoa

class PreferencesWindowController: NSWindowController {
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        print("prepare for segue:\(segue), sender:\(String(describing: sender))")
    }
}
