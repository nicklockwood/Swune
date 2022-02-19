//
//  Assets.swift
//  Swune
//
//  Created by Nick Lockwood on 18/02/2022.
//

enum AssetError: Error {
    case unknownUnitType(EntityTypeID)
    case unknownBuildingType(EntityTypeID)
    case unknownEntityType(EntityTypeID)
    case unknownEffect(AnimationID)
}

struct Assets {
    var unitTypes: [EntityTypeID: UnitType]
    var buildingTypes: [EntityTypeID: BuildingType]
    var effects: [AnimationID: Animation]

    init(
        unitTypes: [UnitType],
        buildingTypes: [BuildingType],
        effects: [Animation]
    ) {
        self.unitTypes = Dictionary(
            uniqueKeysWithValues: unitTypes.map { ($0.id, $0) }
        )
        self.buildingTypes = Dictionary(
            uniqueKeysWithValues: buildingTypes.map { ($0.id, $0) }
        )
        self.effects = Dictionary(
            uniqueKeysWithValues: effects.map { ($0.id!, $0) }
        )
    }
}

extension Assets {
    var explosion: Animation {
        effects[.explosion]!
    }

    var smoke: Animation {
        effects[.smoke]!
    }

    func entityType(for id: EntityTypeID) -> EntityType? {
        if let unitType = unitTypes[id] {
            return unitType
        }
        if let buildingType = buildingTypes[id] {
            return buildingType
        }
        assertionFailure()
        return nil
    }
}
