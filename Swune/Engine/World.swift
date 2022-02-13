//
//  World.swift
//  Swune
//
//  Created by Nick Lockwood on 13/02/2022.
//

class Unit {
    var x, y: Double
    var speed: Double = 1
    var path: [TileCoord] = []

    var coord: TileCoord {
        TileCoord(x: Int(x + 0.5), y: Int(y + 0.5))
    }

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    func update(timeStep: Double, in world: World) {
        if let next = path.first {
            let dx = Double(next.x) - x, dy = Double(next.y) - y
            let distance = (dx * dx + dy * dy).squareRoot()
            let step = timeStep * speed
            let oldX = x, oldY = y
            if distance < step {
                path.removeFirst()
                x = Double(next.x)
                y = Double(next.y)
            } else {
                x += (dx / distance) * step
                y += (dy / distance) * step
            }
            if !world.unit(self, canMoveTo: coord) {
                if let unit = world.pickUnit(at: coord) {
                    _ = world.moveUnitAside(unit)
                }
                x = oldX
                y = oldY
            }
        }
    }
}

class World {
    var map: Tilemap = .init()
    private(set) var units: [Unit] = []

    var selectedUnit: Unit?

    init() {
        units.append(Unit(x: 5, y: 5))
        units.append(Unit(x: 10, y: 10))
    }

    func pickUnit(at coord: TileCoord) -> Unit? {
        for unit in units {
            if unit.coord == coord {
                return unit
            }
        }
        return nil
    }

    func moveUnit(_ unit: Unit, to coord: TileCoord) {
        let path = map.findPath(
            from: unit.coord,
            to: coord,
            maxDistance: .infinity
        )
        unit.path = (unit.path.first.map { [$0] } ?? []) + path
    }

    func moveUnitAside(_ unit: Unit) -> Bool {
        guard let target = map.nodesConnectedTo(unit.coord).first(where: {
            self.unit(unit, canMoveTo: $0)
        }) else {
            return false
        }
        guard let current = unit.path.last else {
            unit.path = [target]
            return true
        }
        let path = map.findPath(
            from: target,
            to: current,
            maxDistance: .infinity
        )
        unit.path = [target] + path
        return true
    }

    func unit(_ unit: Unit, canMoveTo coord: TileCoord) -> Bool {
        return map.tile(at: coord).isPassable && !units.contains(where: {
            $0 !== unit && $0.coord == coord
        })
    }

    func update(timeStep: Double) {
        // Update units
        for unit in units {
            unit.update(timeStep: timeStep, in: self)
        }
    }
}
