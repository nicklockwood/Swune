//
//  World.swift
//  Swune
//
//  Created by Nick Lockwood on 13/02/2022.
//

typealias UnitTypes = [String: UnitType]
typealias BuildingTypes = [String: BuildingType]

class World {
    var map: Tilemap
    var elapsedTime: Double = 0
    private(set) var units: [Unit] = []
    private(set) var buildings: [Building] = []
    var projectiles: [Projectile] = []
    var selectedUnit: Unit?

    init(level: Level, unitTypes: UnitTypes, buildingTypes: BuildingTypes) {
        map = Tilemap(level: level)
        buildings = level.buildings.compactMap {
            guard let type = buildingTypes[$0.type] else {
                assertionFailure()
                return nil
            }
            let coord = TileCoord(x: $0.x, y: $0.y)
            let building = Building(type: type, coord: coord)
            building.team = $0.team
            return building
        }
        units = level.units.compactMap {
            guard let type = unitTypes[$0.type] else {
                assertionFailure()
                return nil
            }
            let coord = TileCoord(x: $0.x, y: $0.y)
            let unit = Unit(type: type, coord: coord)
            unit.team = $0.team
            return unit
        }
    }

    func tileIsPassable(at coord: TileCoord) -> Bool {
        map.tile(at: coord).isPassable && !buildings.contains(where: {
            $0.contains(coord)
        })
    }

    func update(timeStep: Double) {
        elapsedTime += timeStep
        // Update units
        for unit in units {
            unit.update(timeStep: timeStep, in: self)
        }
        // Update projectiles
        for projectile in projectiles {
            projectile.update(timeStep: timeStep, in: self)
        }
    }
}

extension World: Graph {
    typealias Node = TileCoord

    func nodesConnectedTo(_ node: TileCoord) -> [TileCoord] {
        return [
            Node(x: node.x - 1, y: node.y - 1),
            Node(x: node.x - 1, y: node.y),
            Node(x: node.x - 1, y: node.y + 1),
            Node(x: node.x, y: node.y + 1),
            Node(x: node.x + 1, y: node.y + 1),
            Node(x: node.x + 1, y: node.y),
            Node(x: node.x + 1, y: node.y - 1),
            Node(x: node.x, y: node.y - 1),
        ].filter {
            guard $0.x >= 0, $0.x < map.width, $0.y >= 0, $0.y < map.height else {
                return false
            }
            return tileIsPassable(at: $0) &&
                tileIsPassable(at: Node(x: $0.x, y: node.y)) &&
                tileIsPassable(at: Node(x: node.x, y: $0.y))
        }
    }

    func estimatedDistance(from a: Node, to b: Node) -> Double {
        return abs(Double(b.x - a.x)) + abs(Double(b.y - a.y))
    }

    func stepDistance(from a: Node, to b: Node) -> Double {
        return 1
    }
}
