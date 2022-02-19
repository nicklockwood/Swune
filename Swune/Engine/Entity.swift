//
//  Entity.swift
//  Swune
//
//  Created by Nick Lockwood on 16/02/2022.
//

import Foundation

struct EntityTypeID: RawRepresentable, Hashable, Codable {
    var rawValue: String
}

extension EntityTypeID: ExpressibleByStringLiteral {
    init(stringLiteral value: StringLiteralType) {
        self.init(rawValue: value)
    }
}

protocol EntityType {
    var id: EntityTypeID { get }
    var avatarName: String? { get }
}

struct EntityID: RawRepresentable, Hashable, Codable {
    var rawValue: Int
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

extension World {
    func emitSmoke(from coord: TileCoord) {
        let x = Double(coord.x) + 0.5 + .random(in: -0.25 ... 0.25)
        let y = Double(coord.y) + 0.5 + .random(in: -0.25 ... 0)
        particles.append(Particle(
            x: x,
            y: y,
            dx: 1,
            dy: -1,
            animation: assets.smoke
        ))
    }
}
