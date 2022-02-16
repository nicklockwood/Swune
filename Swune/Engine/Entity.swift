//
//  Entity.swift
//  Swune
//
//  Created by Nick Lockwood on 16/02/2022.
//

struct Bounds {
    var x, y, width, height: Double
}

protocol Entity {
    var team: Int { get }
    var bounds: Bounds { get }
}
