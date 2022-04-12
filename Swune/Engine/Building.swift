//
//  Building.swift
//  Swune
//
//  Created by Nick Lockwood on 14/02/2022.
//

import Foundation

struct BuildingType: Decodable {
    var width: Int
    var height: Int
    var idle: Animation
}

class Building {
    var type: BuildingType
    var team: Int = 1
    var x, y: Int

    init(type: BuildingType, coord: TileCoord) {
        self.type = type
        self.x = coord.x
        self.y = coord.y
    }

    func contains(_ coord: TileCoord) -> Bool {
        return coord.x >= x && coord.y >= y &&
        coord.x < x + type.width && coord.y < y + type.height
    }
}

extension Building: Entity {
    var bounds: Bounds {
        .init(
            x: Double(x),
            y: Double(y),
            width: Double(type.width),
            height: Double(type.height)
        )
    }

    var imageName: String {
        type.idle.frame(angle: .zero, time: 0)
    }

    var avatarName: String {
        type.idle.frame(angle: .zero, time: 0)
    }

    var health: Double {
        1
    }

    var maxHealth: Double {
        1
    }
}

extension World {
    func pickBuilding(at coord: TileCoord) -> Building? {
        for building in buildings where building.contains(coord) {
            return building
        }
        return nil
    }
}
