//
//  UILable+Swune.swift
//  Swune
//
//  Created by Nick Lockwood on 13/03/2022.
//

import UIKit

extension UILabel {
    func configure(withSize size: Int) {
        font = .init(name: "Copperplate", size: CGFloat(size))
        textColor = .white
        let offset = size < 8 ? 0.32 : 0.64
        layer.shadowOffset = CGSize(width: offset, height: offset)
        layer.shadowOpacity = 1
        layer.shadowRadius = 0
        layer.magnificationFilter = .nearest
        transform = CGAffineTransform(scaleX: 8, y: 8)
    }
}
