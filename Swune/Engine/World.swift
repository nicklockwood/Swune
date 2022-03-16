//
//  World.swift
//  Swune
//
//  Created by Nick Lockwood on 13/02/2022.
//

let playerTeam = 1

struct TeamState: Codable {
    var team: Int
    var spice: Int = 1000
    var hasFoundPlayer: Bool = false
}

class World {
    private(set) var version: Int
    private(set) var entities: [Entity?] = []
    private var indexByID: [EntityID: Int] = [:]
    private var nextID: Int = 0
    private(set) var assets: Assets
    var map: Tilemap
    var goal: Goal?
    var elapsedTime: Double
    var screenShake: Double
    var scrollX: Double
    var scrollY: Double
    var teams: [Int: TeamState]
    var particles: [Particle]
    var projectiles: [Projectile]

    private(set) lazy var tileIsPassable: (TileCoord) -> Bool =
        { [weak self] coord in
            guard let self = self else { return false }
            return self.map.tile(at: coord).isPassable &&
                self.pickBuilding(at: coord) == nil
        }

    private var selectedEntityID: EntityID?
    var selectedEntity: Entity? {
        get { get(selectedEntityID) }
        set { selectedEntityID = newValue?.id }
    }

    init(level: Level, assets: Assets) {
        self.assets = assets
        self.version = level.version
        self.map = Tilemap(level: level)
        self.goal = level.goal
        self.elapsedTime = 0
        self.screenShake = 0
        self.scrollX = 0
        self.scrollY = 0
        self.particles = []
        self.projectiles = []
        self.teams = [:]
        level.buildings.forEach {
            guard let type = assets.buildingTypes[$0.type] else {
                assertionFailure()
                return
            }
            let team = $0.team
            if teams[team] == nil {
                teams[team] = TeamState(team: team)
            }
            let coord = TileCoord(x: $0.x, y: $0.y)
            add(create { id in
                Building(id: id, type: type, team: team, coord: coord)
            })
        }
        level.units.forEach {
            guard let type = assets.unitTypes[$0.type] else {
                assertionFailure()
                return
            }
            let team = $0.team
            if teams[team] == nil {
                teams[team] = TeamState(team: team)
            }
            let coord = TileCoord(x: $0.x, y: $0.y)
            add(create { id in
                Unit(id: id, type: type, team: team, coord: coord)
            })
        }
    }

    func nearestCoord(in bounds: Bounds, to coord: TileCoord) -> TileCoord? {
        bounds.coords.min(by: {
            $0.distance(from: coord) < $1.distance(from: coord)
        })
    }

    func nearestCoord(from bounds: Bounds, to coord: TileCoord) -> TileCoord? {
        nodesAdjacentTo(bounds).min(by: {
            $0.distance(from: coord) < $1.distance(from: coord)
        })
    }

    func nearestCoord(from start: TileCoord, to end: TileCoord) -> TileCoord? {
        nodesAdjacentTo(start).min(by: {
            $0.distance(from: end) < $1.distance(from: end)
        })
    }

    func update(timeStep: Double) {
        elapsedTime += timeStep
        // Update entities
        for entity in entities {
            entity?.update(timeStep: timeStep, in: self)
        }
        // Update projectiles
        for projectile in projectiles {
            projectile.update(timeStep: timeStep, in: self)
        }
        // Update particles
        for particle in particles {
            particle.update(timeStep: timeStep, in: self)
        }
        // Update shake
        screenShake *= (1 - timeStep)
        if screenShake < 0.3 {
            screenShake = 0
        }
        // Update AI
        let sightRange: Double = 10
        for (team, state) in teams where team != playerTeam {
            var state = state
            // Check for attack
            let buildingUnderAttack = buildings.first(where: { building in
                building.team == team &&
                building.health < building.maxHealth &&
                units.contains(where: {
                    $0.team != team && $0.target == building.id
                })
            })
            // Update units
            for unit in units where unit.team == team {
                // Find player
                if !state.hasFoundPlayer, buildings.contains(where: {
                    $0.team == playerTeam &&
                    unit.distance(from: $0) < sightRange
                }) {
                    state.hasFoundPlayer = true
                }
                // Run away to nearest building if nearly dead
                if unit.health <= 0.25 * unit.maxHealth, units.contains(where: {
                    $0.team == playerTeam && $0.target == unit.id
                }), unit.path.isEmpty, let building = nearestEntity(
                    to: unit.coord,
                    matching: { $0.team == team && $0 is Building }
                ), let destination = nearestCoord(
                    from: building.bounds,
                    to: unit.coord
                ) {
                    moveUnit(unit, to: destination)
                    unit.target = nil
                    unit.onAssignment = false
                }
                // Ignore if busy
                guard unit.role != .harvester, !unit.onAssignment,
                      unit.path.isEmpty
                else {
                    continue
                }
                // Protect base
                if let building = buildingUnderAttack, let coord = nearestCoord(
                    from: building.bounds,
                    to: unit.coord
                ) {
                    moveUnit(unit, to: coord)
                    unit.onAssignment = false
                    continue
                }
                // Attack enemy base
                if state.hasFoundPlayer, let nearestBuilding = nearestEntity(
                    to: unit.coord,
                    matching: { $0.team == playerTeam && $0 is Building })
                {
                    unit.target = nearestBuilding.id
                    unit.onAssignment = true
                }
                // Attack nearest unit in range
                if !unit.onAssignment, let target = nearestEntity(
                    to: unit.coord, matching: {
                        $0.team != team &&
                        ($0.team == playerTeam || team == playerTeam) &&
                        unit.distance(from: $0) < sightRange
                    }
                ) {
                    unit.target = target.id
                    unit.onAssignment = true
                }
            }
            // Build buildings
            if let yard = buildings.first(where: {
                $0.team == team && constructionTypes(for: $0.type)
                    .contains(where: { $0 is BuildingType })
            }) {
                if let building = yard.building {
                    // Deploy building
                    _ = placeBuilding(building)
                    yard.construction = nil
                    yard.building = nil
                }
                if yard.construction == nil {
                    let buildingTypes = constructionTypes(for: yard.type)
                        .compactMap({ $0 as? BuildingType })
                    // Refinery
                    if !buildings.contains(where: {
                        $0.team == team && $0.role == .refinery
                    }), let refineryType = buildingTypes.first(where: {
                        $0.role == .refinery
                    }) {
                        yard.construction = Construction(type: refineryType)
                    }
                    // Factory
                    if !buildings.contains(where: {
                        $0.team == team && constructionTypes(for: $0.type)
                            .contains(where: { $0 is UnitType })
                    }), let factoryType = buildingTypes.first(where: {
                        constructionTypes(for: $0)
                            .compactMap({ $0 as? UnitType })
                            .contains(where: { $0.role != .harvester })
                    }) {
                        yard.construction = Construction(type: factoryType)
                    }
                }
            }
            // Build vehicles
            var harvesterCount = 0
            var vehicleCount = 0
            for unit in units where unit.team == team {
                if unit.role == .harvester {
                    harvesterCount += 1
                } else {
                    vehicleCount += 1
                }
            }
            for factory in buildings.filter({
                $0.team == team && constructionTypes(for: $0.type)
                    .contains(where: { $0 is UnitType })
            }) {
                if let construction = factory.construction {
                    if let unitType = construction.type as? UnitType {
                        if unitType.role == .harvester {
                            harvesterCount += 1
                        } else {
                            vehicleCount += 1
                        }
                    }
                    continue
                }
                let unitTypes = constructionTypes(for: factory.type)
                    .compactMap({ $0 as? UnitType })
                if harvesterCount < 1,
                   let harvesterType = unitTypes.first(where: {
                       $0.role == .harvester
                   })
                {
                    // Harvester
                    factory.construction = Construction(type: harvesterType)
                } else if vehicleCount < 5,
                          let vehicleType = unitTypes.first(where: {
                              $0.role != .harvester
                          })
                {
                    // Combat vehicle
                    factory.construction = Construction(type: vehicleType)
                }
            }
            // Update state
            teams[team] = state
        }
    }

    // MARK: Serialization

    struct State: Codable {
        var map: Tilemap
        var version: Int
        var goal: Goal?
        var elapsedTime: Double
        var screenShake: Double
        var scrollX: Double
        var scrollY: Double
        var selectedEntity: EntityID?
        var teams: [TeamState]
        var buildings: [Building.State]
        var units: [Unit.State] = []
        var particles: [Particle.State]
        var projectiles: [Projectile.State]
    }

    var state: State {
        .init(
            map: map,
            version: version,
            goal: goal,
            elapsedTime: elapsedTime,
            screenShake: screenShake,
            scrollX: scrollX,
            scrollY: scrollY,
            selectedEntity: selectedEntityID,
            teams: Array(teams.values),
            buildings: buildings.map { $0.state },
            units: units.map { $0.state },
            particles: particles.map { $0.state },
            projectiles: projectiles.map { $0.state }
        )
    }

    init(state: State, assets: Assets) throws {
        self.assets = assets
        self.version = state.version
        self.goal = state.goal
        self.map = state.map
        self.elapsedTime = state.elapsedTime
        self.screenShake = state.screenShake
        self.scrollX = state.scrollX
        self.scrollY = state.scrollY
        self.selectedEntityID = state.selectedEntity
        self.teams = Dictionary(uniqueKeysWithValues: state.teams.map {
            ($0.team, $0)
        })
        self.particles = try state.particles.map {
            try Particle(state: $0, assets: assets)
        }
        self.projectiles = state.projectiles.map {
            Projectile(state: $0)
        }
        try state.buildings.forEach {
            try add(Building(state: $0, assets: assets))
        }
        try state.units.forEach {
            try add(Unit(state: $0, assets: assets))
        }
    }
}

extension World {
    func create<T: Entity>(_ constructor: (EntityID) throws -> T) rethrows -> T {
        nextID += 1 // Do this first to avoid problems with reentrancy
        let entity = try constructor(EntityID(rawValue: nextID))
        return entity
    }

    func get(_ id: EntityID?) -> Entity? {
        id.flatMap { indexByID[$0] }.flatMap { entities[$0] }
    }

    func add(_ entity: Entity) {
        assert(indexByID[entity.id] == nil)
        nextID = max(nextID, entity.id.rawValue + 1)
        if let index = entities.firstIndex(where: { $0 == nil }) {
            indexByID[entity.id] = index
            entities[index] = entity
        } else {
            indexByID[entity.id] = entities.count
            entities.append(entity)
        }
    }

    func remove(_ entity: Entity) {
        guard let index = indexByID[entity.id] else {
            assertionFailure()
            return
        }
        entities[index] = nil
        indexByID[entity.id] = nil
    }

    func pickEntity(at coord: TileCoord) -> Entity? {
        for case let entity? in entities where entity.bounds.contains(coord) {
            return entity
        }
        return nil
    }
}

extension World: Graph {
    typealias Node = TileCoord

    func findPath(
        from start: Node,
        to end: Node,
        maxDistance: Double,
        canPass: @escaping (TileCoord) -> Bool
    ) -> [Node] {
        let oldFn = tileIsPassable
        tileIsPassable = canPass
        defer { tileIsPassable = oldFn }
        return findPath(from: start, to: end, maxDistance: maxDistance)
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

    func nodesAdjacentTo(_ node: TileCoord) -> [TileCoord] {
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
            $0.x >= 0 && $0.x < map.width && $0.y >= 0 && $0.y < map.height
        }
    }

    func nodesConnectedTo(_ node: TileCoord) -> [TileCoord] {
        nodesAdjacentTo(node).filter {
            tileIsPassable($0) &&
                tileIsPassable(Node(x: $0.x, y: node.y)) &&
                tileIsPassable(Node(x: node.x, y: $0.y))
        }
    }

    func estimatedDistance(from a: Node, to b: Node) -> Double {
        return abs(Double(b.x - a.x)) + abs(Double(b.y - a.y))
    }

    func stepDistance(from a: Node, to b: Node) -> Double {
        return 1
    }
}

extension World {
    var spiceGoal: Int {
        goal?.spice ?? 0
    }

    var destroyAllBuildings: Bool {
        goal?.destroyAllBuildings ?? (spiceGoal == 0)
    }

    var destroyAllUnits: Bool {
        goal?.destroyAllUnits ?? false
    }

    var isLevelComplete: Bool {
        return (!destroyAllBuildings || !buildings.contains(where: {
            $0.team != playerTeam
        })) && (!destroyAllUnits || !units.contains(where: {
            $0.team != playerTeam
        })) && teams[playerTeam]?.spice ?? 0 >= spiceGoal
    }

    func spiceCapacity(for team: Int) -> Int {
        return buildings.reduce(1000) {
            $0 + ($1.type.spiceCapacity ?? 0)
        }
    }
}
