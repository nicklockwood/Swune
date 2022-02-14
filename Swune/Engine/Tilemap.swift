//
//  Tilemap.swift
//  Swune
//
//  Created by Nick Lockwood on 13/02/2022.
//

import UIKit

struct TileCoord: Hashable {
    var x, y: Int
}

struct Tile {
    var color: UIColor

    var isPassable: Bool {
        return color !== UIColor.white
    }

    init() {
        color = UIColor(
            hue: .random(in: 0 ... 1),
            saturation: 0.1,
            brightness: 0.5,
            alpha: 1
        )
        if Int.random(in: 0 ..< 10) > 8 {
            color = .white
        }
    }
}

struct Tilemap {
    private(set) var width, height: Int
    private var tiles: [Tile] = []

    init() {
        width = 64
        height = 64
        for _ in 0 ..< width * height {
            tiles.append(Tile())
        }
    }

    func tile(at coord: TileCoord) -> Tile {
        return tiles[coord.y * width + coord.x]
    }
}
