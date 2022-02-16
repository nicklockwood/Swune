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

func loadJSON<T: Decodable>(_ name: String) -> T {
    let url = Bundle.main.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "Levels"
    )!
    let data = try! Data(contentsOf: url)
    return try! JSONDecoder().decode(T.self, from: data)
}

class ViewController: UIViewController {
    private var displayLink: CADisplayLink?
    private var lastFrameTime = CACurrentMediaTime()
    private var scrollView = UIScrollView()
    private var buildingViews = [UIView]()
    private var unitViews = [UIImageView]()
    private var projectileViews = [UIView]()
    private var world: World = .init(
        level: loadJSON("Level1"),
        unitTypes: loadJSON("Units")
    )

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        scrollView.frame = view.bounds
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scrollView)

        let gesture = UITapGestureRecognizer(
            target: self,
            action: #selector(didTap)
        )
        scrollView.addGestureRecognizer(gesture)

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
                tileView.backgroundColor = tile.color
                tileView.image = tile.image
                tileView.contentMode = .scaleToFill
                tileView.layer.magnificationFilter = .nearest
                scrollView.addSubview(tileView)
            }
        }
    }

    func loadWorld(_ world: World) {
        loadTilemap(world.map)
        // Draw buildings
        for building in world.buildings {
            let buildingView = UIView(frame: CGRect(
                x: tileSize.width * CGFloat(building.x),
                y: tileSize.height * CGFloat(building.y),
                width: tileSize.width * CGFloat(building.width),
                height: tileSize.height * CGFloat(building.height)
            ))
            buildingViews.append(buildingView)
            buildingView.backgroundColor = .cyan
            scrollView.addSubview(buildingView)
        }
        // Draw units
        for unit in world.units {
            let unitView = UIImageView(frame: CGRect(
                x: tileSize.width * CGFloat(unit.x),
                y: tileSize.height * CGFloat(unit.y),
                width: tileSize.width,
                height: tileSize.height
            ))
            unitView.contentMode = .scaleToFill
            unitView.layer.magnificationFilter = .nearest
            unitViews.append(unitView)
            scrollView.addSubview(unitView)
        }
    }

    @objc func update(_ displayLink: CADisplayLink) {
        let timeStep = min(maximumTimeStep, displayLink.timestamp - lastFrameTime)
        lastFrameTime = displayLink.timestamp

        let worldSteps = (timeStep / worldTimeStep).rounded(.up)
        for _ in 0 ..< Int(worldSteps) {
            world.update(timeStep: timeStep / worldSteps)
        }

        updateViews()
    }

    func updateViews() {
        for (i, unit) in world.units.enumerated() {
            let view = unitViews[i]
            view.frame.origin = CGPoint(
                x: tileSize.width * CGFloat(unit.x),
                y: tileSize.height * CGFloat(unit.y)
            )
            view.image = UIImage(named: unit.imageName)
            view.backgroundColor = unit.health <= 0 ? .black :
                (world.selectedUnit === unit) ? unit.selectedColor : .clear
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
        if let unit = world.pickUnit(at: coord) {
            if let current = world.selectedUnit,
               current.team == playerTeam,
               unit.team != playerTeam
            {
                world.moveUnit(current, to: unit.coord)
                current.target = unit
            } else {
                world.selectedUnit = unit
            }
            updateViews()
        } else if let unit = world.selectedUnit, unit.team == playerTeam {
            world.moveUnit(unit, to: coord)
            unit.target = nil
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

    }
}

extension ViewController: UIScrollViewDelegate {
//    func scrollViewDidScroll(_ scrollView: UIScrollView) {
//        updateTileViews
//    }
}

extension Tile {
    var color: UIColor {
        switch self {
        case .sand: return .yellow
        case .stone: return .gray
        case .spice: return .orange
        case .boulder: return .brown
        }
    }

    var imageName: String {
        switch self {
        case .sand: return "sand"
        case .stone: return "stone"
        case .spice: return "heavy-spice"
        case .boulder: return ""
        }
    }

    var image: UIImage? {
        .init(named: imageName)
    }
}

extension Unit {
    var selectedColor: UIColor {
        team == 1 ? .cyan : .orange
    }
}

