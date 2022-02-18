//
//  World.swift
//  Swune
//
//  Created by Nick Lockwood on 13/02/2022.
//

struct Assets {
    var unitTypes: UnitTypes
    var buildingTypes: BuildingTypes
    var explosion: Animation
}

typealias UnitTypes = [String: UnitType]
typealias BuildingTypes = [String: BuildingType]

class World {
    private(set) var entities: [Entity?] = []
    private var indexByID: [EntityID: Int] = [:]
    private var nextID: Int = 0
    private(set) var assets: Assets
    var map: Tilemap
    var elapsedTime: Double = 0
    var screenShake: Double = 0
    var projectiles: [Projectile] = []
    var particles: [Particle] = []

    private var selectedEntityID: EntityID?
    var selectedEntity: Entity? {
        get { get(selectedEntityID) }
        set { selectedEntityID = newValue?.id }
    }

    init(level: Level, assets: Assets) {
        self.assets = assets
        map = Tilemap(level: level)
        level.buildings.forEach {
            guard let type = assets.buildingTypes[$0.type] else {
                assertionFailure()
                return
            }
            let coord = TileCoord(x: $0.x, y: $0.y)
            let building = create { id in
                Building(id: id, type: type, coord: coord)
            }
            building.team = $0.team
            add(building)
        }
        level.units.forEach {
            guard let type = assets.unitTypes[$0.type] else {
                assertionFailure()
                return
            }
            let coord = TileCoord(x: $0.x, y: $0.y)
            let unit = create { id in
                Unit(id: id, type: type, coord: coord)
            }
            unit.team = $0.team
            add(unit)
        }
    }

    func nearestCoord(from bounds: Bounds, to coord: TileCoord) -> TileCoord? {
        nodesAdjacentTo(bounds).min(by: {
            $0.distance(from: coord) < $1.distance(from: coord)
        })
    }
    
    func tileIsPassable(at coord: TileCoord) -> Bool {
        map.tile(at: coord).isPassable && pickBuilding(at: coord) == nil
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
}

extension World {
    func create<T: Entity>(_ constructor: (EntityID) -> T) -> T {
        let entity = constructor(EntityID(rawValue: nextID))
        nextID += 1
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
            tileIsPassable(at: $0) &&
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
