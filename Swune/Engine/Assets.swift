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
}

struct Assets {
    var unitTypes: [EntityTypeID: UnitType]
    var buildingTypes: [EntityTypeID: BuildingType]
    var explosion: Animation

    init(
        unitTypes: [UnitType],
        buildingTypes: [BuildingType],
        explosion: Animation
    ) {
        self.unitTypes = Dictionary(
            uniqueKeysWithValues: unitTypes.map { ($0.id, $0) }
        )
        self.buildingTypes = Dictionary(
            uniqueKeysWithValues: buildingTypes.map { ($0.id, $0) }
        )
        self.explosion = explosion
    }
}

extension Assets {
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
