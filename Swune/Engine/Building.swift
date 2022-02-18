//
//  Building.swift
//  Swune
//
//  Created by Nick Lockwood on 14/02/2022.
//

import Foundation

enum BuildingRole: String, Decodable {
    case slab
}

struct BuildingType: EntityType, Decodable {
    var id: EntityTypeID
    var width: Int
    var height: Int
    var health: Double
    var role: BuildingRole?
    var idle: Animation

    var avatarName: String? {
        idle.frame(angle: .zero, time: 0)
    }
}

class Construction {
    var type: EntityType
    var buildTime: Double = 5
    var elapsedTime: Double

    var progress: Double {
        elapsedTime / buildTime
    }

    init(type: EntityType) {
        self.type = type
        self.elapsedTime = 0
    }

    // MARK: Serialization

    struct State {
        var type: EntityTypeID
        var elapsedTime: Double
    }

    var state: State {
        .init(type: type.id, elapsedTime: elapsedTime)
    }

    init(state: State, assets: Assets) throws {
        guard let type = assets.entityType(for: state.type) else {
            throw AssetError.unknownEntityType(state.type)
        }
        self.type = type
        self.elapsedTime = state.elapsedTime
    }
}

class Building {
    let id: EntityID
    var type: BuildingType
    var team: Int
    var x, y: Int
    var health: Double
    var construction: Construction?
    var placeholder: Building?

    init(id: EntityID, type: BuildingType, team: Int, coord: TileCoord) {
        self.id = id
        self.type = type
        self.team = team
        self.x = coord.x
        self.y = coord.y
        self.health = type.health
    }

    // MARK: Serialization

    struct State: Codable {
        var id: EntityID
        var type: EntityTypeID
        var team: Int
        var x, y: Int
        var health: Double
    }

    var state: State {
        .init(
            id: id,
            type: type.id,
            team: team,
            x: x,
            y: y,
            health: health
        )
    }

    init(state: State, assets: Assets) throws {
        guard let type = assets.buildingTypes[state.type] else {
            throw AssetError.unknownBuildingType(state.type)
        }
        self.id = state.id
        self.type = type
        self.team = state.team
        self.x = state.x
        self.y = state.y
        self.health = state.health
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

    var imageName: String? {
        type.idle.frame(angle: .zero, time: 0)
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
            let coords = bounds.coords
            for (i, coord) in coords.enumerated().shuffled() {
                let explosion = Particle(
                    x: Double(coord.x) + 0.5,
                    y: Double(coord.y) + 0.5,
                    animation: world.assets.explosion
                )
                explosion.elapsedTime = -(Double(i) / Double(coords.count)) * 0.5
                world.particles.append(explosion)
                world.screenShake += 2
            }
            construction = nil
            placeholder = nil
            return
        }
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
                placeholder = world.create { id in
                    Building(id: id, type: buildingType, team: team, coord: nearest)
                }
            case let unitType as UnitType:
                guard let nearest = world.nearestFreeTile(to: bounds) else {
                    return // TODO: error
                }
                let unit = world.create { id in
                    Unit(id: id, type: unitType, team: team, coord: nearest)
                }
                let dx = unit.x + 0.5 - (Double(x) + Double(type.width) / 2)
                let dy = unit.y + 0.5 - (Double(y) + Double(type.height) / 2)
                unit.angle = Angle(x: dx, y: dy) ?? .zero
                world.add(unit)
            default:
                assertionFailure()
            }
        }
    }
}

extension World {
    var buildings: [Building] {
        entities.compactMap { $0 as? Building }
    }

    var selectedBuilding: Building? {
        selectedEntity as? Building
    }

    var placeholder: Building? {
        get { selectedBuilding?.placeholder }
        set { selectedBuilding?.placeholder = nil }
    }

    func pickBuilding(at coord: TileCoord) -> Building? {
        pickEntity(at: coord) as? Building
    }

    func canPlaceBuilding(_ building: Building) -> Bool {
        canPlaceBuilding(building, at: building.bounds)
    }

    func canPlaceBuilding(_ building: Building, at bounds: Bounds) -> Bool {
        switch building.type.role {
        case .slab:
            return canPlaceSlab(at: bounds)
        default:
            return canPlaceBuilding(at: bounds)
        }
    }

    func placeBuilding(_ building: Building) -> Bool {
        guard canPlaceBuilding(building) else {
            return false
        }
        if building.type.role == .slab {
            for coord in building.bounds.coords {
                if map.tile(at: coord) == .stone {
                    map.setTile(.slab, at: coord)
                }
            }
        } else {
            if building.bounds.coords.contains(where: {
                map.tile(at: $0) != .slab
            }) {
                // Apply 50% damage for not placing on slab
                building.health /= 2
            }
            add(building)
        }
        return true
    }
}

private extension World {
    func nearestFreeTile(to bounds: Bounds) -> TileCoord? {
        let coords = bounds.coords
        var visited = Set(coords)
        var unvisited = coords
        while let next = unvisited.popLast() {
            visited.insert(next)
            for node in nodesAdjacentTo(next) where !visited.contains(node) {
                if map.tile(at: node).isPassable, pickEntity(at: node) == nil {
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
                    if isBuildableSpace(at: bounds) {
                        return node
                    }
                    unvisited.insert(node, at: 0)
                    possible.append(node)
                }
            }
        }
        return possible.first
    }

    func isBuildableSpace(at bounds: Bounds) -> Bool {
        bounds.coords.allSatisfy { coord in
            switch map.tile(at: coord) {
            case .stone, .slab:
                return pickEntity(at: coord) == nil
            case .sand, .spice, .boulder:
                return false
            }
        }
    }

    func isNextToBuilding(at bounds: Bounds) -> Bool {
        let adjacentNodes = nodesAdjacentTo(bounds)
        return buildings.contains(where: { building in
            !adjacentNodes.isDisjoint(with: building.bounds.coords)
        })
    }

    func canPlaceBuilding(at bounds: Bounds) -> Bool {
        isBuildableSpace(at: bounds) && isNextToBuilding(at: bounds)
    }

    func canPlaceSlab(at bounds: Bounds) -> Bool {
        bounds.coords.contains(where: { coord in
            switch map.tile(at: coord) {
            case .stone:
                return pickBuilding(at: coord) == nil
            case .slab, .sand, .spice, .boulder:
                return false
            }
        })
    }
}
