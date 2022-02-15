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

enum Tile: Character, Codable {
    case sand = " "
    case stone = "1"
    case spice = "2"
    case boulder = "3"

    var isPassable: Bool {
        return self != .boulder
    }
}

struct Tilemap: Codable {
    private(set) var width, height: Int
    private var tiles: [Tile] = []

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
        return tiles[coord.y * width + coord.x]
    }
}

