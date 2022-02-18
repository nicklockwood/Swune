//
//  Entity.swift
//  Swune
//
//  Created by Nick Lockwood on 16/02/2022.
//

import Foundation

struct EntityID: RawRepresentable, Hashable {
    var rawValue: Int
}

protocol EntityType {
    var avatarName: String? { get }
}

protocol Entity: AnyObject {
    var id: EntityID { get }
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
