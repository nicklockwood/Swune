//
//  Unit.swift
//  Swune
//
//  Created by Nick Lockwood on 14/02/2022.
//

import Foundation

enum UnitRole: String, Decodable {
    case `default`
    case harvester
}

struct UnitType: EntityType, Decodable {
    var id: EntityTypeID
    var name: String
    var speed: Double
    var turnSpeed: Double
    var health: Double
    var cost: Int
    var buildTime: Double
    var role: UnitRole?
    var idle: Animation
    var harvestingTime: Double?
    var spiceCapacity: Int?
    var attackCooldown: Double?

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
    var attackRange: Double = 5
    var health: Double
    var elapsedTime: Double
    var credits: Int
    var isHarvesting: Bool
    var lastFired: Double
    var lastSmoked: Double
    var path: [TileCoord] = []
    var target: EntityID?
    var onAssignment: Bool = false

    var coord: TileCoord {
        TileCoord(x: Int(x + 0.5), y: Int(y + 0.5))
    }

    var role: UnitRole {
        type.role ?? .default
    }

    init(id: EntityID, type: UnitType, team: Int, coord: TileCoord?) {
        self.id = id
        self.type = type
        self.team = team
        self.x = Double(coord?.x ?? 0)
        self.y = Double(coord?.y ?? 0)
        self.angle = .zero
        self.health = type.health
        self.elapsedTime = 0
        self.credits = 0
        self.isHarvesting = false
        self.lastFired = -.greatestFiniteMagnitude
        self.lastSmoked = -.greatestFiniteMagnitude
    }

    func canEnter(_ building: Building) -> Bool {
        switch building.role {
        case .refinery:
            return role == .harvester && building.team == team
        case .slab:
            return true
        case .default:
            return false
        }
    }

    func findPath(to end: TileCoord, in world: World) -> [TileCoord] {
        var end = end
        while !world.unit(self, canMoveTo: end) {
            guard let next = world.nearestCoord(from: end, to: coord) else {
                return []
            }
            end = next
        }
        switch role {
        case .harvester:
            return world.findPath(
                from: coord,
                to: end,
                maxDistance: .infinity
            ) { coord in
                world.unit(self, canMoveTo: coord)
            }
        case .default:
            return world.findPath(from: coord, to: end, maxDistance: .infinity)
        }
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
        var onAssignment: Bool
        var elapsedTime: Double
        var credits: Int
        var isHarvesting: Bool
        var lastFired: Double
        var lastSmoked: Double
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
            target: target,
            onAssignment: onAssignment,
            elapsedTime: elapsedTime,
            credits: credits,
            isHarvesting: isHarvesting,
            lastFired: lastFired,
            lastSmoked: lastSmoked
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
        self.onAssignment = state.onAssignment
        self.elapsedTime = state.elapsedTime
        self.credits = state.credits
        self.isHarvesting = state.isHarvesting
        self.lastFired = state.lastFired
        self.lastSmoked = state.lastSmoked
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

    func canAttack(_ target: Entity) -> Bool {
        role != .harvester && target.team != team
    }

    func direction(of coord: TileCoord) -> Angle? {
        Angle(x: Double(coord.x) - x, y: Double(coord.y) - y)
    }

    func update(timeStep: Double, in world: World) {
        elapsedTime += timeStep
        // Handle damage
        if health <= 0 {
            world.remove(self)
            world.emitExplosion(at: (x + 0.5, y + 0.5))
            return
        } else if health < 0.5 * maxHealth {
            let cooldown = health / maxHealth / 2
            if world.elapsedTime - lastSmoked > cooldown {
                let x = x + 0.5 + .random(in: -0.25 ... 0.25)
                let y = y + 0.5 + .random(in: -0.25 ... 0)
                world.emitSmoke(from: (x, y))
                lastSmoked = world.elapsedTime
            }
        }
        // Attack target
        var targetDirection: Angle?
        attack: if target != nil {
            guard let target = world.get(target), target.health > 0 else {
                self.target = nil
                self.onAssignment = false
                break attack
            }
            if canAttack(target), distance(from: target) < attackRange {
                path = path.first.map { [$0] } ?? []
                targetDirection = direction(of: target.nearestCoord(to: coord))
                // Attack
                if world.elapsedTime - lastFired > type.attackCooldown ?? 3,
                   let direction = targetDirection,
                   angle.delta(from: direction) < 0.1
                {
                    world.fireProjectile(from: coord, at: target)
                    lastFired = world.elapsedTime
                }
            } else if onAssignment {
                if path.isEmpty, let destination = world.nearestCoord(
                    in: target.bounds,
                    to: coord
                ) {
                    // Recalculate path
                    path = findPath(to: destination, in: world)
                }
            } else {
                self.target = nil
            }
        }
        // Follow path
        if let next = path.first {
            guard world.unit(self, canMoveTo: next) else {
                if let unit = world.pickUnit(at: next),
                   unit.team == team,
                   world.moveUnitAside(unit)
                {
                    return
                } else {
                    path = [coord]
                }
                return
            }

            let dx = Double(next.x) - x, dy = Double(next.y) - y
            let distance = (dx * dx + dy * dy).squareRoot()
            let step = timeStep * type.speed
            if distance < step {
                path.removeFirst()
                x = Double(next.x)
                y = Double(next.y)
            } else {
                targetDirection = Angle(x: dx, y: dy)
                if let direction = targetDirection,
                   angle.delta(from: direction) < 0.001
                {
                    x += (dx / distance) * step
                    y += (dy / distance) * step
                }
            }
        }
        // Turn towards target
        if let direction = targetDirection {
            let da = angle.delta(from: direction)
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
        // Role-specific logic
        switch role {
        case .harvester:
            // Enter refinery
            if let building = world.get(target) as? Building,
               building.bounds.contains(coord)
            {
                assert(building.team == team)
                assert(building.unit == nil)
                building.unit = self
                target = nil
                onAssignment = false
                world.remove(self)
            }
            guard path.isEmpty else {
                return
            }
            let capacity = type.spiceCapacity ?? 5
            if credits < capacity {
                if world.map.tile(at: coord).isSpice {
                    // Harvest
                    if !isHarvesting {
                        elapsedTime = 0
                        isHarvesting = true
                    }
                    if elapsedTime >= type.harvestingTime ?? 5 {
                        elapsedTime = 0
                        var tile = world.map.tile(at: coord)
                        credits += tile.harvest()
                        world.map.setTile(tile, at: coord)
                    }
                } else {
                    isHarvesting = false
                    // Seek spice
                    if world.map.tiles.enumerated().contains(where: { i, tile in
                        tile.isSpice && world.pickUnit(at: world.map.coord(at: i)) == nil
                    }) {
                        path = world.findPath(from: coord, to: { coord in
                            world.map.tile(at: coord).isSpice &&
                                world.unit(self, canMoveTo: coord)
                        }, maxDistance: .infinity)
                    }
                }
            } else {
                isHarvesting = false
            }
            if path.isEmpty, !isHarvesting, credits > 0 {
                // Return to refinery
                isHarvesting = false
                credits = capacity
                target = world.nearestEntity(to: coord, matching: {
                    $0.team == team && ($0 as? Building)?.role == .refinery
                })?.id
                onAssignment = (target != nil)
            }
        case .default:
            guard !onAssignment, path.isEmpty else {
                break
            }
            // Attack nearest unit in range
            target = world.nearestEntity(to: coord, matching: {
                $0.team != team &&
                ($0.team == playerTeam || team == playerTeam) &&
                distance(from: $0) < attackRange
            })?.id
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
        for case let unit as Unit in entities
            where unit.bounds.contains(coord)
        {
            return unit
        }
        return nil
    }

    func nearestEntity(
        to coord: TileCoord,
        matching: (Entity) -> Bool
    ) -> Entity? {
        var nearest: Entity?
        var distance = Double.infinity
        for entity in entities.compactMap({ $0 }) where matching(entity) {
            let d = entity.distance(from: coord)
            if d < distance {
                nearest = entity
                distance = d
            }
        }
        return nearest
    }

    func moveUnit(_ unit: Unit, to coord: TileCoord) {
        let path = unit.findPath(to: coord, in: self)
        unit.path = (unit.path.first.map { [$0] } ?? []) + path
    }

    func moveUnitAside(_ unit: Unit) -> Bool {
        if unit.isHarvesting {
            return false
        }
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
        guard map.tile(at: coord).isPassable else {
            return false
        }
        guard let building = pickBuilding(at: coord) else {
            if let hit = pickUnit(at: coord), hit !== unit {
                return false
            }
            return true
        }
        return unit.canEnter(building) && building.unit == nil
    }
}

extension Tile {
    var isSpice: Bool {
        switch self {
        case .spice, .heavySpice:
            return true
        case .slab, .boulder, .sand, .stone:
            return false
        }
    }

    mutating func harvest() -> Int {
        switch self {
        case .heavySpice:
            self = .spice
            return 1
        case .spice:
            self = .sand
            return 1
        case .slab, .boulder, .sand, .stone:
            assertionFailure()
            return 0
        }
    }
}
