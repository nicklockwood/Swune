//
//  Tilemap.swift
//  Swune
//
//  Created by Nick Lockwood on 13/02/2022.
//

import UIKit

struct TileCoord: Hashable, Codable {
    var x, y: Int

    var center: Point {
        (Double(x) + 0.5, Double(y) + 0.5)
    }

    func distance(from coord: TileCoord) -> Double {
        let dx = Double(coord.x) - Double(x), dy = Double(coord.y) - Double(y)
        return (dx * dx + dy * dy).squareRoot()
    }
}

enum Tile: Character, Codable {
    case sand = " "
    case spice = "2"
    case heavySpice = "5"
    case stone = "1"
    case boulder = "3"
    case slab = "4"
    case crater = "6"

    var isPassable: Bool {
        return self != .boulder
    }
}

struct Tilemap: Codable {
    private(set) var width, height: Int
    private(set) var tiles: [Tile] = []

    init(level: Level) {
        // Set tiles
        let rows = level.tiles
        height = rows.count
        width = rows.reduce(.max) { min($0, $1.count) }
        tiles = rows.flatMap { $0.map {
            Tile(rawValue: $0) ?? .sand
        }}
    }

    func tile(at coord: TileCoord) -> Tile {
        return tiles[
            min(height - 1, max(0, coord.y)) * width +
            min(width - 1, max(0, coord.x))
        ]
    }

    func coord(at index: Int) -> TileCoord {
        return TileCoord(x: index % width, y: index / width)
    }

    mutating func setTile(_ tile: Tile, at coord: TileCoord) {
        tiles[coord.y * width + coord.x] = tile
    }
}

