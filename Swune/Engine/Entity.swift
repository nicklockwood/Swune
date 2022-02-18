//
//  Entity.swift
//  Swune
//
//  Created by Nick Lockwood on 16/02/2022.
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

protocol EntityType {
    var avatarName: String? { get }
}

protocol Entity: AnyObject {
    var team: Int { get }
    var health: Double { get set }
    var maxHealth: Double { get }
    var bounds: Bounds { get }
    var avatarName: String? { get }

    func update(timeStep: Double, in world: World)
}

extension Entity {
    func nearestCoord(to coord: TileCoord) -> TileCoord {
        bounds.coords.min(by: {
            $0.distance(from: coord) < $1.distance(from: coord)
        }) ?? TileCoord(x: Int(bounds.x), y: Int(bounds.y))
    }

    func distance(from coord: TileCoord) -> Double {
        bounds.coords.map { $0.distance(from: coord) }.min() ?? .infinity
    }

    func distance(from entity: Entity) -> Double {
        entity.bounds.coords.map { distance(from: $0) }.min() ?? .infinity
    }
}

extension World {
    func remove(_ entity: Entity) {
        switch entity {
        case let unit as Unit:
            if let index = units.firstIndex(where: { $0 === unit }) {
                units.remove(at: index)
            }
        case let building as Building:
            if let index = buildings.firstIndex(where: { $0 === building }) {
                buildings.remove(at: index)
            }
        default:
            assertionFailure()
        }
    }

    func nearestCoord(from bounds: Bounds, to coord: TileCoord) -> TileCoord? {
        nodesAdjacentTo(bounds).min(by: {
            $0.distance(from: coord) < $1.distance(from: coord)
        })
    }

    func pickEntity(at coord: TileCoord) -> Entity? {
        for unit in units where unit.coord == coord {
            return unit
        }
        for building in buildings where building.bounds.contains(coord) {
            return building
        }
        return nil
    }
}
