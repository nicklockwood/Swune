//
//  Building.swift
//  Swune
//
//  Created by Nick Lockwood on 14/02/2022.
//

import Foundation

struct BuildingType: EntityType, Decodable {
    var width: Int
    var height: Int
    var idle: Animation

    var avatarName: String {
        idle.frame(angle: .zero, time: 0)
    }

    var maxHealth: Double {
        3
    }
}

class Construction {
    var type: EntityType
    var buildTime: Double = 5
    var elapsedTime: Double = 0

    var progress: Double {
        elapsedTime / buildTime
    }

    init(type: EntityType) {
        self.type = type
    }
}

class Building {
    var type: BuildingType
    var team: Int = 1
    var x, y: Int
    var health: Double
    var construction: Construction?
    var placeholder: Building?

    init(type: BuildingType, coord: TileCoord) {
        self.type = type
        self.x = coord.x
        self.y = coord.y
        self.health = type.maxHealth
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
        type.avatarName
    }

    var maxHealth: Double {
        type.maxHealth
    }

    func update(timeStep: Double, in world: World) {
        if let construction = construction {
            construction.elapsedTime += timeStep
            guard construction.progress >= 1 else {
                return
            }
            construction.elapsedTime = construction.buildTime
            self.construction = nil
            switch construction.type {
            case let buildingType as BuildingType:
                guard let nearest = world.nearestFreeRect(
                    width: buildingType.width,
                    height: buildingType.height,
                    to: bounds
                ) else {
                    return // TODO: error
                }
                placeholder = Building(
                    type: buildingType,
                    coord: nearest
                )
            case let unitType as UnitType:
                guard let nearest = world.nearestFreeTile(to: bounds) else {
                    return // TODO: error
                }
                let unit = Unit(type: unitType, coord: nearest)
                let dx = unit.x + 0.5 - (Double(x) + Double(type.width) / 2)
                let dy = unit.y + 0.5 - (Double(y) + Double(type.height) / 2)
                unit.angle = Angle(x: dx, y: dy) ?? .zero
                world.units.append(unit)
            default:
                assertionFailure()
            }
        }
    }
}

extension World {
    var selectedBuilding: Building? {
        selectedEntity as? Building
    }

    var placeholder: Building? {
        get { selectedBuilding?.placeholder }
        set { selectedBuilding?.placeholder = nil }
    }

    func pickBuilding(at coord: TileCoord) -> Building? {
        for building in buildings where building.contains(coord) {
            return building
        }
        return nil
    }

    func nearestFreeTile(to bounds: Bounds) -> TileCoord? {
        let coords = bounds.coords
        var visited = Set(coords)
        var unvisited = coords
        while let next = unvisited.popLast() {
            visited.insert(next)
            for node in nodesAdjacentTo(next) where !visited.contains(node) {
                if tileIsPassable(at: node), !units.contains(where: {
                    $0.coord == node
                }) {
                    return node
                }
                unvisited.insert(node, at: 0)
            }
        }
        return nil
    }

    func nearestFreeRect(width: Int, height: Int, to bounds: Bounds) -> TileCoord? {
        let coords = bounds.coords
        var visited = Set(coords)
        var unvisited = coords
        var possible = [Node]()
        while let next = unvisited.popLast() {
            visited.insert(next)
            for node in nodesAdjacentTo(next) where !visited.contains(node) {
                let bounds = Bounds(
                    x: Double(node.x),
                    y: Double(node.y),
                    width: Double(width),
                    height: Double(height)
                )
                if isNextToBuilding(at: bounds) {
                    if isFreeSpace(at: bounds) {
                        return node
                    }
                    unvisited.insert(node, at: 0)
                    possible.append(node)
                }
            }
        }
        return possible.first
    }

    func nodesAdjacentTo(_ bounds: Bounds) -> Set<Node> {
        let coords = bounds.coords
        var visited = Set(coords)
        for coord in coords {
            for node in nodesAdjacentTo(coord) where !coords.contains(node) {
                visited.insert(node)
            }
        }
        return visited
    }

    func isFreeSpace(at bounds: Bounds) -> Bool {
        bounds.coords.allSatisfy({ coord in
            switch map.tile(at: coord) {
            case .stone:
                return !buildings.contains(where: { $0.contains(coord) })
                    && !units.contains(where: { $0.coord == coord })
            case .sand, .spice, .boulder:
                return false
            }
        })
    }

    func isNextToBuilding(at bounds: Bounds) -> Bool {
        let adjacentNodes = nodesAdjacentTo(bounds)
        return buildings.contains(where: { building in
            !adjacentNodes.isDisjoint(with: building.bounds.coords)
        })
    }

    func canPlaceBuilding(at bounds: Bounds) -> Bool {
        isFreeSpace(at: bounds) && isNextToBuilding(at: bounds)
    }
}
