//
//  AvatarView.swift
//  Swune
//
//  Created by Nick Lockwood on 17/02/2022.
//

import Foundation
import UIKit

private let borderWidth: CGFloat = 4
private let barHeight: CGFloat = 8

class AvatarView: UIButton {
    private let avatarView = UIImageView()
    private let progressView = UIView()

    var image: UIImage? {
        didSet { avatarView.image = image }
    }

    var progress: Double = 0 {
        didSet {
            progressView.frame.size.width = avatarView.frame.width * progress
        }
    }

    var barColor: UIColor = .green {
        didSet {
            progressView.backgroundColor = barColor
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        avatarView.frame = bounds.inset(by: UIEdgeInsets(
            top: borderWidth,
            left: borderWidth,
            bottom: borderWidth * 2 + barHeight,
            right: borderWidth
        ))
        avatarView.backgroundColor = .gray
        avatarView.clipsToBounds = true
        avatarView.contentMode = .scaleAspectFill
        avatarView.layer.magnificationFilter = .nearest
        avatarView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(avatarView)
        progressView.frame = CGRect(
            x: avatarView.frame.minX,
            y: avatarView.frame.maxY + borderWidth,
            width: 0,
            height: barHeight
        )
        progressView.autoresizingMask = [.flexibleTopMargin, .flexibleWidth]
        addSubview(progressView)
        showsMenuAsPrimaryAction = true
    }

    convenience init() {
        self.init(frame: CGRect(
            x: 0,
            y: 0,
            width: 96 + borderWidth * 2,
            height: 96 + borderWidth * 3 + barHeight
        ))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
