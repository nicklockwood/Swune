//
//  Unit.swift
//  Swune
//
//  Created by Nick Lockwood on 14/02/2022.
//

import Foundation

class Unit {
    var x, y: Double
    var team: Int = 1
    var speed: Double = 2
    var range: Double = 3
    var health: Double = 1
    var attackCooldown: Double = 1
    var lastFired: Double = -.greatestFiniteMagnitude
    var path: [TileCoord] = []
    weak var target: Unit?

    var coord: TileCoord {
        TileCoord(x: Int(x + 0.5), y: Int(y + 0.5))
    }

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
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
            let distance = (dx * dx + dy * dy).squareRoot()
            let step = timeStep * speed
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
