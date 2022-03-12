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
    var speed: Double = Projectile.speed
    var damage: Double = 0.25
    var lastSmoked: Double = -.greatestFiniteMagnitude

    // TODO: refactor
    fileprivate static let speed: Double = 5

    init(x: Double, y: Double, target: TileCoord) {
        self.x = x
        self.y = y
        self.tx = target.center.x + .random(in: -0.5 ... 0.5)
        self.ty = target.center.y + .random(in: -0.5 ... 0.5)
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
                let smoke = world.emitSmoke(from: (x, y))
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
        if let unit = entity as? Unit, let next = unit.path.first {
            // Try to fire at where unit is going
            var target = unit.coord
            let distance = start.distance(from: next)
            let estimatedTime = distance / Projectile.speed
            let estimatedUnitDistance = min(estimatedTime * unit.type.speed, 1)
            let dx = Double(next.x) - unit.x
            let dy = Double(next.y) - unit.y
            let norm = (dx * dx + dy * dy).squareRoot()
            if norm > 0 {
                target = TileCoord(
                    x: Int(unit.x + dx / norm * estimatedUnitDistance),
                    y: Int(unit.y + dy / norm * estimatedUnitDistance)
                )
            }
            fireProjectile(from: start, at: target)
        } else {
            fireProjectile(from: start, at: entity.nearestCoord(to: start))
        }
    }

    func fireProjectile(from start: TileCoord, at target: TileCoord) {
        let projectile = Projectile(
            x: start.center.x,
            y: start.center.y,
            target: target
        )
        projectiles.append(projectile)
    }
}
