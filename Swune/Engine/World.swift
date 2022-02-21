//
//  World.swift
//  Swune
//
//  Created by Nick Lockwood on 13/02/2022.
//

struct TeamState: Codable {
    var team: Int
    var spice: Int = 1000
}

class World {
    private(set) var version: Int
    private(set) var entities: [Entity?] = []
    private var indexByID: [EntityID: Int] = [:]
    private var nextID: Int = 0
    private(set) var assets: Assets
    var map: Tilemap
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
    }

    // MARK: Serialization

    struct State: Codable {
        var map: Tilemap
        var version: Int
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
