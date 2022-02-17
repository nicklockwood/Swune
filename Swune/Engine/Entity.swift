//
//  Entity.swift
//  Swune
//
//  Created by Nick Lockwood on 16/02/2022.
//

struct Bounds {
    var x, y, width, height: Double
}

protocol Entity: AnyObject {
    var team: Int { get }
    var health: Double { get }
    var maxHealth: Double { get }
    var bounds: Bounds { get }
    var avatarName: String { get }
}
