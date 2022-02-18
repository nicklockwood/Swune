//
//  Angle.swift
//  Swune
//
//  Created by Nick Lockwood on 16/02/2022.
//

import Foundation

struct Angle: RawRepresentable, Hashable, Codable {
    var rawValue: Double {
        didSet { normalize() }
    }

    init(rawValue: Double) {
        self.rawValue = rawValue
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

extension Angle {
    var radians: Double {
        get { rawValue }
        set { rawValue = newValue }
    }

    static let zero = Angle(radians: 0)

    init(radians: Double) {
        self.init(rawValue: radians)
    }

    init?(x: Double, y: Double) {
        guard x != 0 || y != 0 else {
            return nil
        }
        self.init(radians: atan2(x, -y))
    }
}
