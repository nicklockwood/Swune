//
//  Particle.swift
//  Swune
//
//  Created by Nick Lockwood on 17/02/2022.
//

class Particle {
    var x, y: Double
    var animation: Animation
    var elapsedTime: Double = 0

    var bounds: Bounds {
        .init(x: x - 1, y: y - 1, width: 2, height: 2)
    }

    var imageName: String {
        animation.frame(angle: .zero, time: elapsedTime)
    }

    init(x: Double, y: Double, animation: Animation) {
        self.x = x
        self.y = y
        self.animation = animation
    }

    func update(timeStep: Double, in world: World) {
        elapsedTime += timeStep
        if elapsedTime > animation.duration {
            world.removeParticle(self)
        }
    }
}

extension World {
    func removeParticle(_ particle: Particle) {
        if let index = particles.firstIndex(where: { $0 === particle }) {
            particles.remove(at: index)
        }
    }
}
