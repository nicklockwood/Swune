//
//  Building.swift
//  Swune
//
//  Created by Nick Lockwood on 14/02/2022.
//

import Foundation

class Building {
    var x, y, width, height: Int

    init(x: Int, y: Int) {
        self.x = x
        self.y = y
        width = 3
        height = 2
    }

    func contains(_ coord: TileCoord) -> Bool {
        return coord.x >= x && coord.y >= y &&
            coord.x < x + width && coord.y < y + height
    }
}
