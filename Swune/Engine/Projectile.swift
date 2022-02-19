//
//  Projectile.swift
//  Swune
//
//  Created by Nick Lockwood on 15/02/2022.
//

import Foundation

class Projectile {
    var x, y: Double
    var tx, ty: Double
    var speed: Double = 5
    var damage: Double = 0.25
    var lastSmoked: Double = -.greatestFiniteMagnitude

    init(x: Double, y: Double, target: TileCoord) {
        self.x = x
        self.y = y
        self.tx = Double(target.x) + 0.5 + .random(in: -0.5 ... 0.5)
        self.ty = Double(target.y) + 0.5 + .random(in: -0.5 ... 0.5)
    }

    func update(timeStep: Double, in world: World) {
        let dx = tx - x, dy = ty - y
        let distance = (dx * dx + dy * dy).squareRoot()
        let step = timeStep * speed
        if distance < step {
            world.emitSmallExplosion(at: x, y)
            if let entity = world.pickEntity(at: TileCoord(x: Int(x), y: Int(y))) {
                entity.health -= damage
            }
            if let index = world.projectiles.firstIndex(where: { $0 === self }) {
                world.projectiles.remove(at: index)
            }
        } else {
            if world.elapsedTime > lastSmoked + 0.1 {
                let x = x + .random(in: -0.05 ... 0.05)
                let y = y + .random(in: -0.05 ... 0.05)
                let smoke = world.emitSmoke(from: x, y)
                smoke.dx = .random(in: 0 ... 0.5)
                smoke.dy = .random(in: -0.5 ... 0)
                lastSmoked = world.elapsedTime
            }
            x += (dx / distance) * step
            y += (dy / distance) * step
        }
    }

    // MARK: Serialization

    struct State: Codable {
        var x, y: Double
        var tx, ty: Double
    }

    var state: State {
        .init(x: x, y: y, tx: tx, ty: ty)
    }

    init(state: State) {
        self.x = state.x
        self.y = state.y
        self.tx = state.tx
        self.ty = state.ty
    }
}

extension World {
    func fireProjectile(from start: TileCoord, at entity: Entity) {
        fireProjectile(from: start, at: entity.nearestCoord(to: start))
    }

    func fireProjectile(from start: TileCoord, at target: TileCoord) {
        let projectile = Projectile(
            x: Double(start.x) + 0.5,
            y: Double(start.y) + 0.5,
            target: target
        )
        projectiles.append(projectile)
    }
}
