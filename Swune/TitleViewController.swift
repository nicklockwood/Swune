//
//  TitleViewController.swift
//  Swune
//
//  Created by Nick Lockwood on 13/03/2022.
//

import UIKit

class TitleViewController: UIViewController {
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private var buttons = [UIButton]()

    override func viewDidLoad() {
        super.viewDidLoad()

        let imageURL = Bundle.main.url(
            forResource: "title",
            withExtension: "png",
            subdirectory: "Graphics"
        )
        imageView.image = (imageURL?.path).map(UIImage.init)
        imageView.contentMode = .scaleAspectFill
        imageView.center = view.center
        imageView.layer.magnificationFilter = .nearest
        imageView.frame = view.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(imageView)

        titleLabel.configure(withSize: 10)
        titleLabel.text = "Swune II"
        titleLabel.sizeToFit()
        view.addSubview(titleLabel)

        let assets = loadAssets()

        if let state = loadState() {
            addButton("Continue") { [weak self] in
                guard let world = restoreState(state, with: assets) else {
                    let alert = UIAlertController(
                        title: "Error",
                        message: "Unable to restore saved games",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(
                        title: "OK",
                        style: .default
                    ) { _ in })
                    self?.present(alert, animated: true)
                    return
                }
                let gameController = GameViewController(world: world)
                gameController.modalTransitionStyle = .crossDissolve
                gameController.modalPresentationStyle = .fullScreen
                self?.present(gameController, animated: true)
            }
        }

        addButton("New Game") { [weak self] in
            let level = loadLevel()
            let world = World(level: level, assets: assets)
            let gameController = GameViewController(world: world)
            gameController.modalTransitionStyle = .crossDissolve
            gameController.modalPresentationStyle = .fullScreen
            self?.present(gameController, animated: true)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        titleLabel.center = CGPoint(
            x: view.bounds.midX,
            y: view.bounds.height * 0.2)

        var start = CGPoint(
            x: titleLabel.center.x,
            y: view.bounds.height - view.bounds.height * 0.6
        )
        for button in buttons {
            start.y += 64
            button.center = start
        }
    }
}

private extension TitleViewController {
    func addButton(_ text: String, action: @escaping () -> Void) {
        let label = UILabel()
        label.configure(withSize: 6)
        label.text = text
        label.sizeToFit()
        let inset: CGFloat = 12
        let button = UIButton(frame: CGRect(
            origin: .zero,
            size: label.frame.size
        ).inset(by: .init(
            top: -inset,
            left: -inset,
            bottom: -inset,
            right: -inset
        )))
        label.frame.origin = CGPoint(x: inset, y: inset)
        button.addSubview(label)
        button.addAction(UIAction(handler: { _ in
            action()
        }), for: .touchUpInside)
        view.addSubview(button)
        buttons.append(button)
    }
}
