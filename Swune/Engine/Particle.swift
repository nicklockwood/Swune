//
//  Particle.swift
//  Swune
//
//  Created by Nick Lockwood on 17/02/2022.
//

enum ParticleTypeID: String, Hashable, Codable {
    case explosion
    case smoke
}

struct ParticleType: Decodable {
    var id: ParticleTypeID
    var width: Double
    var height: Double
    var animation: Animation
}

class Particle {
    var type: ParticleType
    var x, y: Double
    var dx, dy: Double
    var elapsedTime: Double

    var bounds: Bounds {
        .init(
            x: x - type.width / 2,
            y: y - type.height / 2,
            width: type.width,
            height: type.height
        )
    }

    var imageName: String? {
        type.animation.frame(angle: .zero, time: elapsedTime)
    }

    init(
        type: ParticleType,
        x: Double,
        y: Double,
        dx: Double = 0,
        dy: Double = 0
    ) {
        self.type = type
        self.x = x
        self.y = y
        self.dx = dx
        self.dy = dy
        self.elapsedTime = 0
    }

    func update(timeStep: Double, in world: World) {
        elapsedTime += timeStep
        x += dx * timeStep
        y += dy * timeStep
        if elapsedTime > type.animation.duration {
            world.removeParticle(self)
        }
    }

    // MARK: Serialization

    struct State: Codable {
        var type: ParticleTypeID
        var x, y: Double
        var dx, dy: Double
        var elapsedTime: Double = 0
    }

    var state: State {
        .init(
            type: type.id,
            x: x,
            y: y,
            dx: dx,
            dy: dy,
            elapsedTime: elapsedTime
        )
    }

    init(state: State, assets: Assets) throws {
        guard let type = assets.particleTypes[state.type] else {
            throw AssetError.unknownParticleType(state.type)
        }
        self.type = type
        self.x = state.x
        self.y = state.y
        self.dx = state.dx
        self.dy = state.dy
        self.elapsedTime = state.elapsedTime
    }
}

extension World {
    func removeParticle(_ particle: Particle) {
        if let index = particles.firstIndex(where: { $0 === particle }) {
            particles.remove(at: index)
        }
    }

    @discardableResult
    func emitExplosion(at x: Double, _ y: Double) -> Particle {
        let explosion = Particle(
            type: assets.particleTypes[.explosion]!,
            x: x,
            y: y
        )
        particles.append(explosion)
        for _ in 0 ..< 5 {
            let x = x + .random(in: -0.5 ... 0.5)
            let y = y + .random(in: -0.5 ... 0.5)
            emitSmoke(from: x, y)
        }
        screenShake += 3
        return explosion
    }

    @discardableResult
    func emitSmoke(from x: Double, _ y: Double) -> Particle {
        let smoke = Particle(
            type: assets.particleTypes[.smoke]!,
            x: x,
            y: y,
            dx: 1,
            dy: -1
        )
        particles.append(smoke)
        return smoke
    }
}
