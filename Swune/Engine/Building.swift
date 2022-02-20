//
//  Building.swift
//  Swune
//
//  Created by Nick Lockwood on 14/02/2022.
//

import Foundation

enum BuildingRole: String, Decodable {
    case `default`
    case slab
    case refinery
}

struct BuildingType: EntityType, Decodable {
    var id: EntityTypeID
    var width: Int
    var height: Int
    var health: Double
    var role: BuildingRole?
    var idle: Animation
    var active: Animation?
    var unit: EntityTypeID?

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

    struct State: Codable {
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
    var lastSmoked: Double
    var elapsedTime: Double
    var construction: Construction?
    var building: Building?
    var unit: Unit? {
        didSet { elapsedTime = 0 }
    }

    var role: BuildingRole {
        type.role ?? .default
    }

    init(id: EntityID, type: BuildingType, team: Int, coord: TileCoord) {
        self.id = id
        self.type = type
        self.team = team
        self.x = coord.x
        self.y = coord.y
        self.health = type.health
        self.lastSmoked = -.greatestFiniteMagnitude
        self.elapsedTime = 0
        self.building = nil
        self.unit = nil
    }

    // MARK: Serialization

    struct State: Codable {
        var id: EntityID
        var type: EntityTypeID
        var team: Int
        var x, y: Int
        var health: Double
        var lastSmoked: Double
        var elapsedTime: Double
        var construction: Construction.State?
        var buildings: [Building.State]
        var units: [Unit.State]
    }

    var state: State {
        .init(
            id: id,
            type: type.id,
            team: team,
            x: x,
            y: y,
            health: health,
            lastSmoked: lastSmoked,
            elapsedTime: elapsedTime,
            construction: construction?.state,
            buildings: building.map { [$0.state] } ?? [],
            units: unit.map { [$0.state] } ?? []
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
        self.lastSmoked = state.lastSmoked
        self.elapsedTime = state.elapsedTime
        self.construction = try state.construction.flatMap {
            try Construction(state: $0, assets: assets)
        }
        self.building = try state.buildings.last.map {
            try Building(state: $0, assets: assets)
        }
        self.unit = try state.units.last.map {
            try Unit(state: $0, assets: assets)
        }
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
        if unit != nil, let active = type.active {
            return active.frame(angle: .zero, time: elapsedTime)
        }
        return type.idle.frame(angle: .zero, time: elapsedTime)
    }

    var avatarName: String? {
        type.avatarName
    }

    var maxHealth: Double {
        type.health
    }

    func update(timeStep: Double, in world: World) {
        elapsedTime += timeStep
        // Handle damage
        if health <= 0 {
            world.remove(self)
            let coords = bounds.coords
            for (i, coord) in coords.enumerated().shuffled() {
                let x = Double(coord.x) + 0.5, y = Double(coord.y) + 0.5
                let explosion = world.emitExplosion(at: x, y)
                explosion.elapsedTime = -(Double(i) / Double(coords.count)) * 0.5
            }
            construction = nil
            building = nil
            return
        } else if health < 0.5 * maxHealth {
            let cooldown = health / maxHealth / 2
            if world.elapsedTime - lastSmoked > cooldown {
                let w = bounds.width / 2, h = bounds.height / 2
                let x = bounds.x + w + .random(in: -w * 0.75 ... w * 0.75)
                let y = bounds.y + h + .random(in: -h * 0.75 ... h * 0.5)
                world.emitSmoke(from: x, y)
                lastSmoked = world.elapsedTime
            }
        }
        // Handle construction
        if let construction = construction {
            construction.elapsedTime += timeStep
            guard construction.progress >= 1 else {
                return
            }
            self.construction = nil
            switch construction.type {
            case let buildingType as BuildingType:
                building = world.create { id in
                    let building = Building(
                        id: id,
                        type: buildingType,
                        team: team,
                        coord: self.bounds.coords[0]
                    )
                    if let nearest = world.nearestFreeRect(
                        to: bounds,
                        for: building
                    ) {
                        building.x = nearest.x
                        building.y = nearest.y
                    } else {
                        assertionFailure()
                    }
                    if let typeID = building.type.unit {
                        if let unitType = world.assets.unitTypes[typeID] {
                            building.unit = world.create { id in
                                Unit(id: id, type: unitType, team: team, coord: nil)
                            }
                        } else {
                            assertionFailure()
                        }
                    }
                    return building
                }
            case let unitType as UnitType:
                let unit = world.create { id in
                    Unit(id: id, type: unitType, team: team, coord: nil)
                }
                world.spawnUnit(unit, from: bounds)
            default:
                assertionFailure()
            }
        }
        // Role-specific logic
        if let unit = unit {
            switch unit.role {
            case .harvester:
                unit.path = []
                let unloadingTimeStep = type.active?.duration ?? 1
                if elapsedTime >= unloadingTimeStep {
                    unit.spice -= 1
                    elapsedTime -= unloadingTimeStep
                }
                if unit.spice <= 0 {
                    unit.spice = 0
                    world.spawnUnit(unit, from: bounds)
                    self.unit = nil
                }
            case .default:
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

    var building: Building? {
        selectedBuilding?.building
    }

    func spawnUnit(_ unit: Unit, from bounds: Bounds) {
        guard let nearest = nearestFreeTile(to: bounds) else {
            return // TODO: error
        }
        unit.x = Double(nearest.x)
        unit.y = Double(nearest.y)
        let dx = unit.x + 0.5 - (bounds.x + bounds.width / 2)
        let dy = unit.y + 0.5 - (bounds.y + bounds.height / 2)
        unit.angle = Angle(x: dx, y: dy) ?? .zero
        add(unit)
    }

    func pickBuilding(at coord: TileCoord) -> Building? {
        for case let building as Building in entities
            where building.bounds.contains(coord)
        {
            return building
        }
        return nil
    }

    func canPlaceBuilding(_ building: Building) -> Bool {
        canPlaceBuilding(building, at: building.bounds)
    }

    func canPlaceBuilding(_ building: Building, at bounds: Bounds) -> Bool {
        guard isBuildableSpace(at: bounds, for: building.role) else {
            return false
        }
        switch building.role {
        case .slab:
            return true
        case .refinery, .default:
            return isNextToBuilding(at: bounds, team: building.team)
        }
    }

    func placeBuilding(_ building: Building) -> Bool {
        guard canPlaceBuilding(building) else {
            return false
        }
        switch building.role {
        case .slab:
            for coord in building.bounds.coords {
                if map.tile(at: coord) == .stone {
                    map.setTile(.slab, at: coord)
                }
            }
        case .refinery, .default:
            if building.bounds.coords.contains(where: {
                map.tile(at: $0) != .slab
            }) {
                // Apply 50% damage for not placing on slab
                building.health /= 2
            }
            add(building)
        }
        if let selectedBuilding = selectedBuilding,
           selectedBuilding.building === building
        {
            selectedBuilding.building = nil
            selectedBuilding.construction = nil
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

    func nearestFreeRect(
        to bounds: Bounds,
        for building: Building
    ) -> TileCoord? {
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
                    width: Double(building.type.width),
                    height: Double(building.type.height)
                )
                if isNextToBuilding(at: bounds, team: building.team) {
                    if isBuildableSpace(at: bounds, for: building.role) {
                        return node
                    }
                    unvisited.insert(node, at: 0)
                    possible.append(node)
                }
            }
        }
        return possible.first
    }

    func isBuildableSpace(at bounds: Bounds, for role: BuildingRole) -> Bool {
        switch role {
        case .slab:
            return bounds.coords.contains(where: { coord in
                switch map.tile(at: coord) {
                case .stone:
                    return true
                case .slab, .sand, .spice, .heavySpice, .boulder:
                    return false
                }
            })
        case .refinery, .default:
            return bounds.coords.allSatisfy { coord in
                switch map.tile(at: coord) {
                case .stone, .slab:
                    return pickEntity(at: coord) == nil
                case .sand, .spice, .heavySpice, .boulder:
                    return false
                }
            }
        }
    }

    func isNextToBuilding(at bounds: Bounds, team: Int) -> Bool {
        let adjacentNodes = nodesAdjacentTo(bounds)
        return buildings.contains(where: {
            $0.team == team && !adjacentNodes.isDisjoint(with: $0.bounds.coords)
        })
    }
}
