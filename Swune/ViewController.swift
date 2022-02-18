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

let playerTeam = 1

func loadJSON<T: Decodable>(_ name: String) throws -> T {
    let url = Bundle.main.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "Levels"
    )!
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(T.self, from: data)
}

let savedGameURL: URL = FileManager.default
    .urls(for: .documentDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("quicksave.json")

class ViewController: UIViewController {
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
    private var scrollPosition: CGPoint?
    private var world: World!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.restoreState()
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.saveState()
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

        if let scrollPosition = scrollPosition {
            scrollView.setContentOffset(scrollPosition, animated: true)
            self.scrollPosition = nil
        }

        loadWorld(world)

        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common)
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
        if let reticleImage = UIImage(named: "reticle") {
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
        updateViews()
    }

    func addSprite(_ name: String?, frame: CGRect, index: Int) {
        let spriteView: UIImageView
        if index >= spriteViews.count {
            spriteView = UIImageView(frame: frame)
            spriteView.contentMode = .scaleToFill
            spriteView.layer.magnificationFilter = .nearest
            spriteViews.append(spriteView)
            scrollView.insertSubview(spriteView, belowSubview: selectionView)
        } else {
            spriteView = spriteViews[index]
            spriteView.frame = frame
            spriteView.isHidden = false
        }
        spriteView.image = name.flatMap { UIImage(named: $0) }
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
                frame: CGRect(building.bounds),
                index: i
            )
            i += 1
        }

        // Draw units
        for unit in world.units {
            addSprite(
                unit.imageName,
                frame: CGRect(unit.bounds),
                index: i
            )
            i += 1
        }

        // Draw projectiles
        for (i, projectile) in world.projectiles.enumerated() {
            let projectileView: UIView
            if i >= projectileViews.count {
                projectileView = UIView(frame: .zero)
                projectileView.backgroundColor = .yellow
                projectileViews.append(projectileView)
                scrollView.addSubview(projectileView)
            } else {
                projectileView = projectileViews[i]
            }
            projectileView.frame = CGRect(
                x: tileSize.width * CGFloat(projectile.x),
                y: tileSize.height * CGFloat(projectile.y),
                width: tileSize.width,
                height: tileSize.height
            )
        }
        while projectileViews.count > world.projectiles.count {
            projectileViews.last?.removeFromSuperview()
            projectileViews.removeLast()
        }

        // Draw particles
        for particle in world.particles {
            addSprite(
                particle.imageName,
                frame: CGRect(particle.bounds),
                index: i
            )
            i += 1
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
        if let placeholder = world.placeholder {
            var bounds = placeholder.bounds
            bounds.x += placeholderDelta.x
            bounds.y += placeholderDelta.y
            placeholderView.frame = CGRect(bounds)
            if world.canPlaceBuilding(placeholder, at: bounds) {
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
            avatarView.imageName = selectedEntity.avatarName
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
            constructionView.imageName = construction.type.avatarName
            constructionView.progress = construction.progress
            constructionView.barColor = .cyan
            constructionView.isHidden = false
        } else {
            constructionView.isHidden = true
        }

        // Update menu
        if let building = world.selectedBuilding {
            if building.placeholder != nil || building.construction != nil {
                avatarView.menu = UIMenu(children: [
                    UIAction(title: "Cancel") { [weak building] _ in
                        building?.construction = nil
                        building?.placeholder = nil
                    }
                ])
            } else {
                let assets = world.assets
                let slabType = assets.buildingTypes["slab"]!
                let largeSlabType = assets.buildingTypes["largeSlab"]!
                let vehicleFactoryType = assets.buildingTypes["vehicleFactory"]!
                let harvesterType = assets.unitTypes["blue-harvester"]!
                avatarView.menu = UIMenu(children: [
                    UIAction(
                        title: "Build Slab",
                        image: slabType.avatarName.flatMap { UIImage(named: $0) }
                    ) { [weak building] _ in
                        building?.construction = Construction(type: slabType)
                    },
                    UIAction(
                        title: "Build Large Slab",
                        image: largeSlabType.avatarName.flatMap { UIImage(named: $0) }
                    ) { [weak building] _ in
                        building?.construction = Construction(type: largeSlabType)
                    },
                    UIAction(
                        title: "Build Vehicle Factory",
                        image: vehicleFactoryType.avatarName.flatMap { UIImage(named: $0) }
                    ) { [weak building] _ in
                        building?.construction = Construction(type: vehicleFactoryType)
                    },
                    UIAction(
                        title: "Build Harvester",
                        image: harvesterType.avatarName.flatMap { UIImage(named: $0) }
                    ) { [weak building] _ in
                        building?.construction = Construction(type: harvesterType)
                    }
                ])
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
        if let building = world.placeholder, building.bounds.contains(coord) {
            _ = world.placeBuilding(building)
        } else if let unit = world.pickUnit(at: coord) {
            if let current = world.selectedEntity as? Unit,
               current.team == playerTeam,
               unit.team != playerTeam
            {
                world.moveUnit(current, to: unit.coord)
                current.target = unit.id
            }
            world.selectedEntity = unit
            updateViews()
        } else if let building = world.pickBuilding(at: coord) {
            if let current = world.selectedEntity as? Unit,
               current.team == playerTeam,
               building.team != playerTeam
            {
                let coord = TileCoord(x: building.x, y: building.y)
                world.moveUnit(current, to: coord)
                current.target = building.id
            }
            world.selectedEntity = building
            updateViews()
        } else if let unit = world.selectedEntity as? Unit, unit.team == playerTeam {
            world.moveUnit(unit, to: coord)
            unit.target = nil
        } else {
            world.selectedEntity = nil
            updateViews()
        }
    }

    private var lastDragLocation: CGPoint = .zero
    private var placeholderDelta: (x: Double, y: Double) = (0, 0)
    @objc private func didDrag(_ gesture: UIPanGestureRecognizer) {
        guard let placeholder = world.placeholder else { return }
        let location = gesture.location(in: scrollView)
        switch gesture.state {
        case .began:
            lastDragLocation = location
        case .changed:
            placeholderDelta.x = (location.x - lastDragLocation.x) / tileSize.width
            placeholderDelta.y = (location.y - lastDragLocation.y) / tileSize.height
        case .ended:
            placeholder.x += Int(round((location.x - lastDragLocation.x) / tileSize.width))
            placeholder.y += Int(round((location.y - lastDragLocation.y) / tileSize.height))
            placeholderDelta = (0, 0)
        case .cancelled, .failed, .possible:
            break
        @unknown default:
            break
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        avatarView.frame.origin = CGPoint(
            x: view.frame.width - avatarView.frame.width - 16,
            y: view.safeAreaInsets.top + 16
        )
        constructionView.frame.origin = CGPoint(
            x: view.frame.width - constructionView.frame.width - 16,
            y: avatarView.frame.maxY + 16
        )
    }

    // MARK: Serialization

    func saveState() {
        do {
            let data = try JSONEncoder().encode(world.state)
            try data.write(to: savedGameURL, options: .atomic)
        } catch {
            print("\(error)")
        }
    }

    func restoreState() {
        let assets = try! Assets(
            unitTypes: loadJSON("Units"),
            buildingTypes: loadJSON("Buildings"),
            explosion: loadJSON("Explosion")
        )
        if FileManager.default.fileExists(atPath: savedGameURL.path) {
            do {
                let data = try Data(contentsOf: savedGameURL)
                let state = try JSONDecoder().decode(World.State.self, from: data)
                world = try .init(state: state, assets: assets)
                scrollPosition = CGPoint(x: world.scrollX, y: world.scrollY)
            } catch {
                print("\(error)")
            }
        }
        if world == nil {
            world = .init(level: try! loadJSON("Level1"), assets: assets)
        }
    }
}

extension ViewController: UIScrollViewDelegate {
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
        case .spice: return "heavy-spice"
        case .boulder: return nil
        }
    }

    var image: UIImage? {
        imageName.flatMap { UIImage(named: $0) }
    }
}
