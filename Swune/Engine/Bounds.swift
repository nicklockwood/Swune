//
//  Bounds.swift
//  Swune
//
//  Created by Nick Lockwood on 18/02/2022.
//

import Foundation

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

    func contains(x: Double, y: Double) -> Bool {
        x >= self.x && y >= self.y && x < self.x + width && y < self.y + height
    }

    func contains(_ coord: TileCoord) -> Bool {
        contains(x: Double(coord.x), y: Double(coord.y))
    }
}
