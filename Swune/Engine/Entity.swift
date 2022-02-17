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
}

protocol EntityType {
    var avatarName: String { get }
}

protocol Entity: AnyObject {
    var team: Int { get }
    var health: Double { get }
    var maxHealth: Double { get }
    var bounds: Bounds { get }
    var avatarName: String { get }

    func update(timeStep: Double, in world: World)
}
