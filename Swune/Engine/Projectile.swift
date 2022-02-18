//
//  Projectile.swift
//  Swune
//
//  Created by Nick Lockwood on 15/02/2022.
//

import Foundation

class Projectile {
    var x, y: Double
    var speed: Double = 3
    var damage: Double = 0.25
    var target: TileCoord

    init(x: Double, y: Double, target: TileCoord) {
        self.x = x
        self.y = y
        self.target = target
    }

    func update(timeStep: Double, in world: World) {
        let dx = Double(target.x) - x, dy = Double(target.y) - y
        let distance = (dx * dx + dy * dy).squareRoot()
        let step = timeStep * speed
        if distance < step {
            x = Double(target.x)
            y = Double(target.y)
            if let entity = world.pickEntity(at: target) {
                entity.health -= damage
            }
            if let index = world.projectiles.firstIndex(where: { $0 === self }) {
                world.projectiles.remove(at: index)
            }
        } else {
            x += (dx / distance) * step
            y += (dy / distance) * step
        }
    }
}

extension World {
    func fireProjectile(from start: TileCoord, at entity: Entity) {
        fireProjectile(from: start, at: entity.nearestCoord(to: start))
    }

    func fireProjectile(from start: TileCoord, at target: TileCoord) {
        let projectile = Projectile(
            x: Double(start.x),
            y: Double(start.y),
            target: target
        )
        projectiles.append(projectile)
    }
}
