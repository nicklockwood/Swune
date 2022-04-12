//
//  Unit.swift
//  Swune
//
//  Created by Nick Lockwood on 14/02/2022.
//

import Foundation

struct UnitType: Decodable {
    var speed: Double
    var turnSpeed: Double
//    var range: Double = 3
//    var health: Double = 1
//    var attackCooldown: Double = 1

    var idle: Animation
}

class Unit {
    var type: UnitType
    var x, y: Double
    var angle: Angle = .zero
    var team: Int = 1
    var range: Double = 3
    var health: Double = 1
    var attackCooldown: Double = 1
    var lastFired: Double = -.greatestFiniteMagnitude
    var path: [TileCoord] = []
    weak var target: Unit?

    var coord: TileCoord {
        TileCoord(x: Int(x + 0.5), y: Int(y + 0.5))
    }

    var imageName: String {
        type.idle.frame(angle: angle, time: 0)
    }

    init(type: UnitType, coord: TileCoord) {
        self.type = type
        self.x = Double(coord.x)
        self.y = Double(coord.y)
    }

    func distance(from coord: TileCoord) -> Double {
        let dx = Double(coord.x) - x, dy = Double(coord.y) - y
        return (dx * dx + dy * dy).squareRoot()
    }

    func update(timeStep: Double, in world: World) {
        if health <= 0 {
            // Dead
            return
        }
        if let target = target {
            if target.health <= 0 {
                self.target = nil
            } else if distance(from: target.coord) < range {
                path = []
                // Attack
                if world.elapsedTime - lastFired > attackCooldown {
                    world.fireProjectile(from: coord, at: target.coord)
                    lastFired = world.elapsedTime
                }
                return
            } else if let destination = path.last,
                target.distance(from: destination) < range {
                    // Carry on moving
            } else {
                // Recalculate path
                path = world.findPath(
                    from: coord,
                    to: target.coord,
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
    func pickUnit(at coord: TileCoord) -> Unit? {
        for unit in units {
            if unit.coord == coord {
                return unit
            }
        }
        return nil
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
            $0 !== unit && $0.coord == coord && $0.health > 0
        })
    }
}
