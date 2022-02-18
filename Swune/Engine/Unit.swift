//
//  Unit.swift
//  Swune
//
//  Created by Nick Lockwood on 14/02/2022.
//

import Foundation

struct UnitType: EntityType, Decodable {
    var id: EntityTypeID
    var speed: Double
    var turnSpeed: Double
    var health: Double
    var idle: Animation

    var avatarName: String? {
        idle.frame(angle: .init(radians: .pi), time: 0)
    }
}

class Unit {
    let id: EntityID
    var type: UnitType
    var x, y: Double
    var angle: Angle
    var team: Int
    var range: Double = 3
    var health: Double
    var attackCooldown: Double = 1
    var lastFired: Double = -.greatestFiniteMagnitude
    var path: [TileCoord] = []
    var target: EntityID?

    var coord: TileCoord {
        TileCoord(x: Int(x + 0.5), y: Int(y + 0.5))
    }

    init(id: EntityID, type: UnitType, team: Int, coord: TileCoord) {
        self.id = id
        self.type = type
        self.team = team
        self.x = Double(coord.x)
        self.y = Double(coord.y)
        self.angle = .zero
        self.health = type.health
    }

    // MARK: Serialization

    struct State: Codable {
        var id: EntityID
        var type: EntityTypeID
        var team: Int
        var x, y: Double
        var angle: Angle
        var health: Double
        var target: EntityID?
    }

    var state: State {
        .init(
            id: id,
            type: type.id,
            team: team,
            x: x,
            y: y,
            angle: angle,
            health: health,
            target: target
        )
    }

    init(state: State, assets: Assets) throws {
        guard let type = assets.unitTypes[state.type] else {
            throw AssetError.unknownUnitType(state.type)
        }
        self.id = state.id
        self.type = type
        self.team = state.team
        self.x = state.x
        self.y = state.y
        self.angle = state.angle
        self.health = state.health
        self.target = state.target
    }
}

extension Unit: Entity {
    var bounds: Bounds {
        .init(x: x, y: y, width: 1, height: 1)
    }

    var imageName: String? {
        type.idle.frame(angle: angle, time: 0)
    }

    var avatarName: String? {
        type.avatarName
    }

    var maxHealth: Double {
        type.health
    }

    func update(timeStep: Double, in world: World) {
        if health <= 0 {
            world.remove(self)
            world.particles.append(Particle(
                x: x + 0.5,
                y: y + 0.5,
                animation: world.assets.explosion
            ))
            world.screenShake += maxHealth
            return
        }
        if let target = world.get(target) {
            if target.health <= 0 {
                self.target = nil
            } else if distance(from: target) < range {
                path = []
                // Attack
                if world.elapsedTime - lastFired > attackCooldown {
                    world.fireProjectile(from: coord, at: target)
                    lastFired = world.elapsedTime
                }
                return
            } else if let destination = path.last,
                target.distance(from: destination) < range {
                    // Carry on moving
            } else if let destination = world.nearestCoord(
                from: target.bounds,
                to: coord
            ) {
                // Recalculate path
                path = world.findPath(
                    from: coord,
                    to: destination,
                    maxDistance: .infinity
                )
            }
        }
        if let next = path.first {
            guard world.unit(self, canMoveTo: next) else {
                if let unit = world.pickUnit(at: next), world.moveUnitAside(unit) {
                    return
                } else if !world.moveUnitAside(self) {
                    path = []
                }
                return
            }

            let dx = Double(next.x) - x, dy = Double(next.y) - y
            if let direction = Angle(x: dx, y: dy) {
                var da = direction.radians - angle.radians
                if da > .pi {
                    da -= .pi * 2
                } else if da < -.pi {
                    da += .pi * 2
                }
                guard abs(da) < 0.001 else {
                    let astep = timeStep * type.turnSpeed * 2 * .pi
                    if abs(da) < astep {
                        angle = direction
                    } else {
                        angle.radians += astep * (da < 0 ? -1 : 1)
                    }
                    return
                }
            }

            let distance = (dx * dx + dy * dy).squareRoot()
            let step = timeStep * type.speed
            if distance < step {
                path.removeFirst()
                x = Double(next.x)
                y = Double(next.y)
            } else {
                x += (dx / distance) * step
                y += (dy / distance) * step
            }

        } else if !world.tileIsPassable(at: coord) {
            _ = world.moveUnitAside(self)
            return
        }
    }
}

extension World {
    var units: [Unit] {
        entities.compactMap { $0 as? Unit }
    }

    var selectedUnit: Unit? {
        selectedEntity as? Unit
    }

    func pickUnit(at coord: TileCoord) -> Unit? {
        pickEntity(at: coord) as? Unit
    }

    func moveUnit(_ unit: Unit, to coord: TileCoord) {
        let path = findPath(
            from: unit.coord,
            to: coord,
            maxDistance: .infinity
        )
        unit.path = (unit.path.first.map { [$0] } ?? []) + path
    }

    func moveUnitAside(_ unit: Unit) -> Bool {
        guard let target = nodesConnectedTo(unit.coord).first(where: { node in
            self.unit(unit, canMoveTo: node) && !units.contains(where: {
                $0 !== unit && ($0.path.first == node || $0.path.last == node)
            })
        }) else {
            return false
        }
        guard let current = unit.path.last else {
            unit.path = [target]
            return true
        }
        let path = findPath(
            from: target,
            to: current,
            maxDistance: .infinity
        )
        guard !path.isEmpty else {
            return false
        }
        unit.path = [target] + path
        return true
    }

    func unit(_ unit: Unit, canMoveTo coord: TileCoord) -> Bool {
        return tileIsPassable(at: coord) && !units.contains(where: {
            $0 !== unit && $0.coord == coord
        })
    }
}
