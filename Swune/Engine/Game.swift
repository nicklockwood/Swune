//
//  Game.swift
//  Swune
//
//  Created by Nick Lockwood on 13/03/2022.
//

import Foundation

private func loadJSON<T: Decodable>(_ name: String) throws -> T {
    let url = Bundle.main.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "Data"
    )!
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(T.self, from: data)
}

let savedGameURL: URL = FileManager.default
    .urls(for: .documentDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("quicksave.json")

func loadAssets() -> Assets {
    try! Assets(
        unitTypes: loadJSON("Units"),
        buildingTypes: loadJSON("Buildings"),
        particleTypes: loadJSON("Particles")
    )
}

func loadLevel() -> Level {
    try! loadJSON("Level1")
}

func loadState() -> World.State? {
    if FileManager.default.fileExists(atPath: savedGameURL.path) {
        do {
            let data = try Data(contentsOf: savedGameURL)
            return try JSONDecoder().decode(World.State.self, from: data)
        } catch {
            print("Error restoring state: \(error)")
        }
    }
    return nil
}

func restoreState(_ state: World.State?, with assets: Assets) -> World? {
    if let state = state {
        do {
            return try .init(state: state, assets: assets)
        } catch {
            print("\(error)")
        }
    }
    return nil
}

func saveState(_ state: World.State?) {
    guard let state = state else {
        return
    }
    do {
        let data = try JSONEncoder().encode(state)
        try data.write(to: savedGameURL, options: .atomic)
    } catch {
        print("\(error)")
    }
}
