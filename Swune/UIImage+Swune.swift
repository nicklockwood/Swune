//
//  UIImage+Swune.swift
//  Swune
//
//  Created by Nick Lockwood on 20/02/2022.
//

import UIKit

extension UIImage {
    private static var cache: [Sprite: CGImage] = [:]

    convenience init?(sprite: Sprite, team: Int? = nil) {
        var name = sprite
        switch team {
        case 1:
            name += "-blue"
        case 2:
            name += "-red"
        default:
            break
        }
        if let cgImage = Self.cache[sprite] {
            self.init(cgImage: cgImage)
            return
        }
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "Graphics"
        ) else {
            guard team != nil else {
                return nil
            }
            self.init(sprite: sprite)
            return
        }
        self.init(contentsOfFile: url.path)
        Self.cache[name] = cgImage
    }
}
