//
//  ViewController.swift
//  Swune
//
//  Created by Nick Lockwood on 13/02/2022.
//

import UIKit

private let tileSize = CGSize(width: 48, height: 48)
private let maximumTimeStep: Double = 1 / 20
private let worldTimeStep: Double = 1 / 120
private let levelEndDelay: Double = 2

class GameViewController: UIViewController {
    private var displayLink: CADisplayLink?
    private var lastFrameTime = CACurrentMediaTime()
    private var scrollView = UIScrollView()
    private var tileViews = [UIImageView]()
    private var spriteViews = [UIImageView]()
    private var projectileViews = [UIView]()
    private let selectionView = UIImageView()
    private let placeholderView = UIView()
    private let avatarView = AvatarView()
    private let constructionView = AvatarView()
    private let spiceLabel = UILabel()
    private let messageLabel = UILabel()
    private let pauseButton = UIButton()
    private var isPaused = true
    private var levelEnded: TimeInterval?
    private var world: World

    init(world: World) {
        self.world = world
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            saveState(self?.world.state)
        }

        view.backgroundColor = .black

        scrollView.frame = view.bounds
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.delegate = self
        view.addSubview(scrollView)

        let gesture = UITapGestureRecognizer(
            target: self,
            action: #selector(didTap)
        )
        scrollView.addGestureRecognizer(gesture)

        let scrollPosition = CGPoint(x: world.scrollX, y: world.scrollY)
        scrollView.setContentOffset(scrollPosition, animated: true)

        let imageView = UIImageView()
        imageView.image = UIImage(sprite: "pause", team: nil)
        imageView.transform = CGAffineTransform(scaleX: 8, y: 8)
        imageView.contentMode = .scaleToFill
        imageView.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        imageView.layer.magnificationFilter = .nearest
        imageView.layer.shadowOffset = .zero
        imageView.layer.shadowOpacity = 0.25
        imageView.layer.shadowRadius = 0.32
        pauseButton.addSubview(imageView)
        pauseButton.sizeToFit()
        pauseButton.addAction(UIAction { [weak self] _ in
            self?.isPaused = true
            let alert = UIAlertController(
                title: "Paused",
                message: "",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(
                title: "Resume",
                style: .default
            ) { _ in
                self?.isPaused = false
            })
            alert.addAction(UIAlertAction(
                title: "Quit",
                style: .default
            ) { _ in
                self?.presentingViewController?.dismiss(animated: true)
            })
            self?.present(alert, animated: true)
        }, for: .touchUpInside)
        view.addSubview(pauseButton)

        spiceLabel.configure(withSize: 6)
        view.addSubview(spiceLabel)

        messageLabel.configure(withSize: 4)
        messageLabel.numberOfLines = 0
        view.addSubview(messageLabel)

        loadWorld(world)

        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        var objectives = [String]()
        if world.destroyAllBuildings {
            objectives.append("Destroy all enemy buildings")
        }
        if world.destroyAllUnits {
            objectives.append("Destroy all enemy units")
        }
        if world.spiceGoal > 0 {
            objectives.append("Gather \(world.spiceGoal) units of spice")
        }
        let alert = UIAlertController(
            title: "Mission:",
            message: objectives.joined(separator: "\n"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.isPaused = false
        })
        present(alert, animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isPaused = true
    }

    func loadTilemap(_ tilemap: Tilemap) {
        scrollView.contentSize = CGSize(
            width: tileSize.width * CGFloat(tilemap.width),
            height: tileSize.height * CGFloat(tilemap.height)
        )
        // Draw map
        for y in 0 ..< tilemap.height {
            for x in 0 ..< tilemap.width {
                let tileView = UIImageView(frame: CGRect(
                    x: tileSize.width * CGFloat(x),
                    y: tileSize.height * CGFloat(y),
                    width: tileSize.width,
                    height: tileSize.height
                ))
                let coord = TileCoord(x: x, y: y)
                let tile = tilemap.tile(at: coord)
                tileView.image = tile.image
                tileView.contentMode = .scaleToFill
                tileView.layer.magnificationFilter = .nearest
                tileViews.append(tileView)
                scrollView.addSubview(tileView)
            }
        }
    }

    func loadWorld(_ world: World) {
        loadTilemap(world.map)

        // Draw reticle
        if let reticleImage = UIImage(sprite: "reticle") {
            let scale = tileSize.width / reticleImage.size.width
            selectionView.transform = CGAffineTransform(scaleX: scale, y: scale)
            selectionView.image = reticleImage.stretchableImage(
                withLeftCapWidth: Int(reticleImage.size.width / 2),
                topCapHeight: Int(reticleImage.size.height / 2)
            )
        }
        selectionView.contentMode = .scaleToFill
        selectionView.layer.magnificationFilter = .nearest
        selectionView.isHidden = true
        scrollView.addSubview(selectionView)

        // Draw placeholder
        placeholderView.isHidden = true
        placeholderView.layer.borderWidth = 4
        placeholderView.layer.borderColor = UIColor.white.cgColor
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(didDrag))
        placeholderView.addGestureRecognizer(gesture)
        scrollView.addSubview(placeholderView)

        // Draw avatar
        avatarView.isHidden = true
        view.addSubview(avatarView)

        // Draw construction
        constructionView.isHidden = true
        view.addSubview(constructionView)
    }

    @objc func update(_ displayLink: CADisplayLink) {
        if isPaused {
            updateViews()
            return
        }

        let timeStep = min(maximumTimeStep, displayLink.timestamp - lastFrameTime)
        lastFrameTime = displayLink.timestamp

        let worldSteps = (timeStep / worldTimeStep).rounded(.up)
        for _ in 0 ..< Int(worldSteps) {
            world.update(timeStep: timeStep / worldSteps)
        }

        let intensity = world.screenShake
        if intensity > 0 {
            let shakeX = Double.random(in: -intensity ... intensity)
            let shakeY = Double.random(in: -intensity ... intensity)
            view.window?.transform = CGAffineTransform(translationX: shakeX, y: shakeY)
        } else if view.window?.transform != .identity {
            view.window?.transform = .identity
        }

        if let levelEnded = levelEnded {
            if lastFrameTime - levelEnded >= levelEndDelay {
                isPaused = true
                let alert = UIAlertController(
                    title: "Mission Complete!",
                    message: nil,
                    preferredStyle: .alert
                )
                present(alert, animated: true)
                alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    let level = loadLevel()
                    self.world = .init(level: level, assets: self.world.assets)
                    self.levelEnded = nil
                    self.isPaused = false
                })
            }
        } else if world.isLevelComplete {
            levelEnded = lastFrameTime
        }

        updateViews()
    }

    func addSprite(_ name: String?, team: Int?, frame: CGRect, index: Int) {
        let spriteView: UIImageView
        if index >= spriteViews.count {
            spriteView = UIImageView(frame: frame)
            spriteView.isUserInteractionEnabled = false
            spriteView.contentMode = .scaleToFill
            spriteView.layer.magnificationFilter = .nearest
            spriteViews.append(spriteView)
            scrollView.insertSubview(spriteView, belowSubview: selectionView)
        } else {
            spriteView = spriteViews[index]
            spriteView.frame = frame
            spriteView.isHidden = false
        }
        spriteView.image = name.flatMap { UIImage(sprite: $0, team: team) }
    }

    func updateViews() {
        var i = 0

        // Draw map
        let tilemap = world.map
        for y in 0 ..< tilemap.height {
            for x in 0 ..< tilemap.width {
                let tileView = tileViews[y * tilemap.width + x]
                let tile = tilemap.tile(at: TileCoord(x: x, y: y))
                tileView.image = tile.image
            }
        }

        // Draw buildings
        for building in world.buildings {
            addSprite(
                building.imageName,
                team: building.team,
                frame: CGRect(building.bounds),
                index: i
            )
            i += 1
        }

        // Draw units
        for unit in world.units {
            addSprite(
                unit.imageName,
                team: unit.team,
                frame: CGRect(unit.bounds),
                index: i
            )
            i += 1
        }

        // Draw projectiles
//        for (i, projectile) in world.projectiles.enumerated() {
//            let projectileView: UIView
//            if i >= projectileViews.count {
//                projectileView = UIView(frame: .zero)
//                projectileView.backgroundColor = .yellow
//                projectileViews.append(projectileView)
//                scrollView.addSubview(projectileView)
//            } else {
//                projectileView = projectileViews[i]
//            }
//            projectileView.frame = CGRect(
//                x: tileSize.width * CGFloat(projectile.x),
//                y: tileSize.height * CGFloat(projectile.y),
//                width: tileSize.width,
//                height: tileSize.height
//            )
//        }
//        while projectileViews.count > world.projectiles.count {
//            projectileViews.last?.removeFromSuperview()
//            projectileViews.removeLast()
//        }

        // Draw particles
        for particle in world.particles {
            addSprite(
                particle.imageName,
                team: nil,
                frame: CGRect(particle.bounds),
                index: i
            )
            i += 1
        }

        // Draw target
        if let entity = world.selectedEntity {
            var center: Point?
            if entity.team == playerTeam, let unit = entity as? Unit {
                if let target = world.get(unit.target) {
                    center = target.bounds.center
                } else if let coord = unit.path.last {
                    center = coord.center
                }
            } else if world.units.contains(where: {
                $0.team == playerTeam && $0.target == entity.id
            }) {
                center = entity.bounds.center
            }
            if let center = center {
                let bounds = Bounds(
                    x: center.x - 0.5,
                    y: center.y - 0.5,
                    width: 1,
                    height: 1
                )
                addSprite("target", team: nil, frame: CGRect(bounds), index: i)
                i += 1
            }
        }

        // Clear unused sprites
        for j in i ..< spriteViews.count {
            spriteViews[j].isHidden = true
        }

        // Draw reticle
        if let entity = world.selectedEntity {
            selectionView.frame = CGRect(entity.bounds).inset(by: UIEdgeInsets(
                top: -8,
                left: -8,
                bottom: -8,
                right: -8
            ))
            selectionView.isHidden = false
        } else {
            selectionView.isHidden = true
        }

        // Draw placeholder
        if let building = world.selectedBuilding?.building {
            var bounds = building.bounds
            bounds.x += placeholderDelta.dx
            bounds.y += placeholderDelta.dy
            placeholderView.frame = CGRect(bounds)
            if world.canPlaceBuilding(building, at: bounds) {
                placeholderView.backgroundColor = .green.withAlphaComponent(0.5)
            } else {
                placeholderView.backgroundColor = .red.withAlphaComponent(0.5)
            }
            placeholderView.isHidden = false
        } else {
            placeholderView.isHidden = true
        }

        // Draw avatar
        if let selectedEntity = world.selectedEntity {
            avatarView.image = selectedEntity.avatarName.flatMap {
                UIImage(sprite: $0, team: selectedEntity.team)
            }
            let health = selectedEntity.health / selectedEntity.maxHealth
            avatarView.progress = health
            switch health {
            case 0 ..< 0.3:
                avatarView.barColor = .red
            case 0.3 ..< 0.6:
                avatarView.barColor = .yellow
            default:
                avatarView.barColor = .green
            }
            avatarView.isHidden = false
        } else {
            avatarView.menu = nil
            avatarView.isHidden = true
        }

        // Draw build progress
        if let building = world.selectedBuilding,
           let construction = building.construction
        {
            constructionView.image = construction.type.avatarName.flatMap {
                UIImage(sprite: $0, team: building.team)
            }
            constructionView.progress = construction.progress
            constructionView.barColor = .cyan
            constructionView.isHidden = false
        } else {
            constructionView.isHidden = true
        }

        // Draw credits
        if let state = world.teams[playerTeam] {
            spiceLabel.text = "$\(state.spice)"
            spiceLabel.sizeToFit()
        }

        // Draw message
        
        messageLabel.text = world.message ?? world.selectedEntityDescription
        if !avatarView.isHidden {
            messageLabel.frame.size = CGSize(
                width: avatarView.frame.minX - messageLabel.frame.minX - 16,
                height: 100
            )
        } else {
            messageLabel.frame.size = CGSize(
                width: view.bounds.width  - messageLabel.frame.minX - 16,
                height: 100
            )
        }
        messageLabel.sizeToFit()

        // Update menu
        if let building = world.selectedBuilding {
            if building.team != playerTeam {
                avatarView.menu = nil
            } else if building.building != nil || building.construction != nil {
                avatarView.menu = UIMenu(children: [
                    UIAction(title: "Cancel") { [weak building] _ in
                        building?.construction = nil
                        building?.building = nil
                    }
                ])
            } else {
                let assets = world.assets
                var buildActions: [UIAction] = []
                for typeID in building.type.constructions ?? [] {
                    guard let type = assets.entityType(for: typeID) else {
                        assertionFailure()
                        continue
                    }
                    buildActions.append(UIAction(
                        title: "Build \(type.name) ($\(type.cost))",
                        image: type.avatarName.flatMap {
                            UIImage(sprite: $0, team: building.team)
                        }
                    ) { [weak building] _ in
                        building?.construction = Construction(type: type)
                    })
                }
                if buildActions.isEmpty {
                    avatarView.menu = nil
                } else {
                    avatarView.menu = UIMenu(children: buildActions)
                }
            }
        } else if let unit = world.selectedUnit {
            avatarView.menu = nil
        }
    }

    func tileCoordinate(at location: CGPoint) -> TileCoord {
        TileCoord(
            x: Int(location.x / tileSize.width),
            y: Int(location.y / tileSize.height)
        )
    }

    @objc private func didTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: scrollView)
        let coord = tileCoordinate(at: location)
        if let building = world.selectedBuilding?.building,
           building.bounds.contains(coord)
        {
            _ = world.placeBuilding(building)
        } else if let unit = world.pickUnit(at: coord) {
            if unit === world.selectedEntity {
                world.selectedEntity = nil
            } else {
                if let current = world.selectedEntity as? Unit,
                   current.team == playerTeam,
                   current.canAttack(unit)
                {
                    current.target = unit.id
                    current.onAssignment = true
                }
                world.selectedEntity = unit
            }
            updateViews()
        } else if let building = world.pickBuilding(at: coord) {
            if building === world.selectedEntity {
                world.selectedEntity = nil
            } else {
                if let current = world.selectedEntity as? Unit,
                   current.team == playerTeam,
                   current.canAttack(building) || current.canEnter(building)
                {
                    current.target = building.id
                    current.onAssignment = true
                }
                world.selectedEntity = building
            }
            updateViews()
        } else if let unit = world.selectedEntity as? Unit, unit.team == playerTeam {
            world.moveUnit(unit, to: coord)
            unit.target = nil
            unit.onAssignment = false
        } else {
            world.selectedEntity = nil
            updateViews()
        }
    }

    private var lastDragLocation: CGPoint = .zero
    private var placeholderDelta: CGVector = .zero
    @objc private func didDrag(_ gesture: UIPanGestureRecognizer) {
        guard let building = world.selectedBuilding?.building else { return }
        let location = gesture.location(in: scrollView)
        switch gesture.state {
        case .began:
            lastDragLocation = location
        case .changed:
            placeholderDelta.dx = (location.x - lastDragLocation.x) / tileSize.width
            placeholderDelta.dy = (location.y - lastDragLocation.y) / tileSize.height
        case .ended:
            building.x += Int(round((location.x - lastDragLocation.x) / tileSize.width))
            building.y += Int(round((location.y - lastDragLocation.y) / tileSize.height))
            placeholderDelta = .zero
        case .cancelled, .failed, .possible:
            break
        @unknown default:
            break
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        avatarView.frame.origin = CGPoint(
            x: view.frame.width - avatarView.frame.width - view.safeAreaInsets.right - 16,
            y: view.safeAreaInsets.top + 16
        )
        constructionView.frame.origin = CGPoint(
            x: avatarView.frame.minX,
            y: avatarView.frame.maxY + 16
        )
        pauseButton.frame.origin = CGPoint(
            x: view.safeAreaInsets.left + 16,
            y: avatarView.frame.minY
        )
        spiceLabel.frame.origin = CGPoint(
            x: pauseButton.frame.maxX + 16,
            y: avatarView.frame.minY - 10
        )
        messageLabel.frame.origin = CGPoint(
            x: pauseButton.frame.minX,
            y: spiceLabel.frame.maxY + 4
        )
    }
}

extension GameViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        world.scrollX = scrollView.contentOffset.x
        world.scrollY = scrollView.contentOffset.y
    }
}

extension CGRect {
    init(_ bounds: Bounds) {
        self.init(
            x: bounds.x * tileSize.width,
            y: bounds.y * tileSize.height,
            width: bounds.width * tileSize.width,
            height: bounds.height * tileSize.width
        )
    }
}

extension Tile {
    var imageName: String? {
        switch self {
        case .sand: return "sand"
        case .slab: return "slab"
        case .stone: return "stone"
        case .crater: return "crater"
        case .spice: return "spice"
        case .heavySpice: return "heavy-spice"
        case .boulder: return nil
        }
    }

    var image: UIImage? {
        imageName.flatMap { UIImage(sprite: $0) }
    }
}
