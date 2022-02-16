//
//  Level.swift
//  Swune
//
//  Created by Nick Lockwood on 15/02/2022.
//

import Foundation

struct Level: Codable {
    struct Building: Codable {
        var type: String
        var team: Int
        var x: Int
        var y: Int
    }

    struct Unit: Codable {
        var type: String
        var team: Int
        var x: Int
        var y: Int
    }

    var tiles: [String]
    var buildings: [Building]
    var units: [Unit]
}
