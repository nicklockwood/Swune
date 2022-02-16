//
//  Angle.swift
//  Swune
//
//  Created by Nick Lockwood on 16/02/2022.
//

import Foundation

struct Angle: Hashable {
    var radians: Double {
        didSet { normalize() }
    }

    static let zero = Angle(radians: 0)

    init(radians: Double) {
        self.radians = radians
    }

    init?(x: Double, y: Double) {
        guard x != 0 || y != 0 else {
            return nil
        }
        radians = atan2(x, -y)
        normalize()
    }

    private mutating func normalize() {
        while radians < 0 {
            radians += .pi * 2
        }
        while radians > .pi * 2 {
            radians -= .pi * 2
        }
    }
}
