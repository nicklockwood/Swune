//
//  Particle.swift
//  Swune
//
//  Created by Nick Lockwood on 17/02/2022.
//

class Particle {
    var x, y: Double
    var dx, dy: Double
    var animation: Animation
    var elapsedTime: Double

    var bounds: Bounds {
        .init(x: x - 1, y: y - 1, width: 2, height: 2)
    }

    var imageName: String? {
        animation.frame(angle: .zero, time: elapsedTime)
    }

    init(
        x: Double,
        y: Double,
        dx: Double = 0,
        dy: Double = 0,
        animation: Animation
    ) {
        self.x = x
        self.y = y
        self.dx = 0
        self.dy = 0
        self.animation = animation
        self.elapsedTime = 0
    }

    func update(timeStep: Double, in world: World) {
        elapsedTime += timeStep
        x += dx * timeStep
        y += dy * timeStep
        if elapsedTime > animation.duration {
            world.removeParticle(self)
        }
    }

    // MARK: Serialization

    struct State: Codable {
        var x, y: Double
        var dx, dy: Double
        var effect: AnimationID
        var elapsedTime: Double = 0
    }

    var state: State {
        .init(
            x: x,
            y: y,
            dx: dx,
            dy: dy,
            effect: animation.id!,
            elapsedTime: elapsedTime
        )
    }

    init(state: State, assets: Assets) throws {
        guard let animation = assets.effects[state.effect] else {
            throw AssetError.unknownEffect(state.effect)
        }
        self.x = state.x
        self.y = state.y
        self.dx = state.dx
        self.dy = state.dy
        self.elapsedTime = state.elapsedTime
        self.animation = animation
    }
}

extension World {
    func removeParticle(_ particle: Particle) {
        if let index = particles.firstIndex(where: { $0 === particle }) {
            particles.remove(at: index)
        }
    }
}
