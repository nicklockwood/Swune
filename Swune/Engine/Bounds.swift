//
//  Bounds.swift
//  Swune
//
//  Created by Nick Lockwood on 18/02/2022.
//

import Foundation

typealias Point = (x: Double, y: Double)

struct Bounds {
    var x, y, width, height: Double

    var coords: [TileCoord] {
        var coords = [TileCoord]()
        for y in Int(y) ..< Int(ceil(y + height)) {
            for x in Int(x) ..< Int(ceil(x + width)) {
                coords.append(TileCoord(x: x, y: y))
            }
        }
        return coords
    }

    var center: Point {
        (x: x + width / 2, y: y + height / 2)
    }

    func contains(_ p: Point) -> Bool {
        p.x >= x && p.y >= y && p.x < x + width && p.y < y + height
    }

    func contains(_ coord: TileCoord) -> Bool {
        contains(coord.center)
    }
}
