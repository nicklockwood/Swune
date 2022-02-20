//
//  Animation.swift
//  Swune
//
//  Created by Nick Lockwood on 16/02/2022.
//

typealias Sprite = String

struct Animation: Decodable {
    var duration: Double
    var framesByAngle: [[Sprite]]
    var loopCount: Int?

    func frame(angle: Angle, time: Double) -> Sprite? {
        guard time >= 0 else {
            return nil
        }
        var angleIndex = Int((
            angle.radians / (2 * .pi) * Double(framesByAngle.count)
        ).rounded(.toNearestOrAwayFromZero))
        angleIndex = angleIndex % framesByAngle.count
        let frames = framesByAngle[angleIndex]
        var frameIndex = (duration > 0) ?
            Int(time / duration * Double(frames.count)) : 0
        if let loopCount = loopCount, loopCount > 0 {
            frameIndex = min(loopCount * frames.count - 1, frameIndex)
        }
        frameIndex = frameIndex % frames.count
        return frames[frameIndex]
    }
}
