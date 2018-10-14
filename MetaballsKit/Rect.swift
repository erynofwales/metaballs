//
//  Square.swift
//  Metaballs
//
//  Created by Eryn Wells on 10/13/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

import Foundation

/// A simple rectangle made of two triangles
struct Rect {
    static var geometry: [Vertex] {
        return [
            Vertex(position: Float2(x: 1, y: 1), textureCoordinate: Float2(x: 1, y: 1)),
            Vertex(position: Float2(x: 0, y: 1), textureCoordinate: Float2(x: 0, y: 1)),
            Vertex(position: Float2(x: 0, y: 0), textureCoordinate: Float2(x: 0, y: 0)),
            Vertex(position: Float2(x: 1, y: 1), textureCoordinate: Float2(x: 1, y: 1)),
            Vertex(position: Float2(x: 0, y: 0), textureCoordinate: Float2(x: 0, y: 0)),
            Vertex(position: Float2(x: 1, y: 0), textureCoordinate: Float2(x: 1, y: 0)),
        ]
    }

    var transform: Matrix3x3
}
