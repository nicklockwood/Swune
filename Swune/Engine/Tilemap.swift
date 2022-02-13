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

extension Tilemap: Graph {
    typealias Node = TileCoord

    func nodesConnectedTo(_ node: TileCoord) -> [TileCoord] {
        return [
            Node(x: node.x - 1, y: node.y - 1),
            Node(x: node.x - 1, y: node.y),
            Node(x: node.x - 1, y: node.y + 1),
            Node(x: node.x, y: node.y + 1),
            Node(x: node.x + 1, y: node.y + 1),
            Node(x: node.x + 1, y: node.y),
            Node(x: node.x + 1, y: node.y - 1),
            Node(x: node.x, y: node.y - 1),
        ].filter {
            guard $0.x >= 0, $0.x < width, $0.y >= 0, $0.y < tiles.count / width else {
                return false
            }
            return tile(at: $0).isPassable &&
                tile(at: Node(x: $0.x, y: node.y)).isPassable &&
                tile(at: Node(x: node.x, y: $0.y)).isPassable
        }
    }

    func estimatedDistance(from a: Node, to b: Node) -> Double {
        return abs(Double(b.x - a.x)) + abs(Double(b.y - a.y))
    }

    func stepDistance(from a: Node, to b: Node) -> Double {
        return 1
    }
}
