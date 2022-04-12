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

class ViewController: UIViewController {
    private var displayLink: CADisplayLink?
    private var lastFrameTime = CACurrentMediaTime()
    private var scrollView = UIScrollView()
    private var buildingViews = [UIView]()
    private var unitViews = [UIView]()
    private var projectileViews = [UIView]()
    private var world: World = {
        let url = Bundle.main.url(
            forResource: "Level1",
            withExtension: "json",
            subdirectory: "Levels"
        )!
        let data = try! Data(contentsOf: url)
        let level = try! JSONDecoder().decode(Level.self, from: data)
        return World(level: level)
    }()

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
                let tileView = UIView(frame: CGRect(
                    x: tileSize.width * CGFloat(x),
                    y: tileSize.height * CGFloat(y),
                    width: tileSize.width,
                    height: tileSize.height
                ))
                let coord = TileCoord(x: x, y: y)
                tileView.backgroundColor = tilemap.tile(at: coord).color
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
            let unitView = UIView(frame: CGRect(
                x: tileSize.width * CGFloat(unit.x),
                y: tileSize.height * CGFloat(unit.y),
                width: tileSize.width,
                height: tileSize.height
            ))
            unitViews.append(unitView)
            unitView.backgroundColor = unit.teamColor
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
            view.backgroundColor = unit.health <= 0 ? .black :
                (world.selectedUnit === unit) ?
                    unit.selectedColor : unit.teamColor
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
}

extension Unit {
    var teamColor: UIColor {
        team == 1 ? .blue : .red
    }

    var selectedColor: UIColor {
        team == 1 ? .cyan : .orange
    }
}

