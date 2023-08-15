//import Foundation
//import GameplayKit
//
//func calculateWatchPosition(parentSize: CGSize) -> (CGFloat, CGFloat) {
//    var seed = UInt64(Date().timeIntervalSince1970)
//    let seedData = Data(bytes: &seed, count: MemoryLayout<UInt64>.size)
//    let generator = GKARC4RandomSource(seed: seedData)
//
//    let x = CGFloat(generator.nextUniform()) * (parentSize.width * 0.8 - parentSize.width * 0.2) + parentSize.width * 0.2
//    let y = CGFloat(generator.nextUniform()) * (parentSize.height * 0.8 - parentSize.height * 0.2) + parentSize.height * 0.2
//
//    return (x, y)
//}

import Foundation
import GameplayKit

func calculateDigitalWatchPosition(parentSize: CGSize) -> (CGFloat, CGFloat) {
    iPrint("calculateDigitalWatchPosition: parentSize: \(parentSize)")
    var seed = UInt64(Date().timeIntervalSince1970)
    let seedData = Data(bytes: &seed, count: MemoryLayout<UInt64>.size)
    let generator = GKARC4RandomSource(seed: seedData)

    let lowerBuffer = CGFloat(0.1) // 10% of size
    let upperBuffer = CGFloat(0.2) // 20% of size

    let x: CGFloat
    let y: CGFloat

    let randomValue = lowerBuffer + CGFloat(generator.nextUniform()) * (upperBuffer - lowerBuffer)

    switch true {
        case generator.nextBool():
            // 50% chance to pick position between 10% to 20% from the left edge
            x = parentSize.width * randomValue
        default:
            // 50% chance to pick position between 10% to 20% from the right edge
            x = parentSize.width * (1 - randomValue)
    }

    switch true {
        case generator.nextBool():
            // 50% chance to pick position between 10% to 20% from the top edge
            y = parentSize.height * randomValue
        default:        // 50% chance to pick position between 10% to 20% from the bottom edge
            y = parentSize.height * (1 - randomValue)
    }

    return (x, y)
}
