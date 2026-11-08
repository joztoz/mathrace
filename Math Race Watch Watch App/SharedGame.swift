//
//  File.swift
//  Math Race
//
//  Created by Jozef Ziak on 1/18/26.
//

import Foundation

public struct SharedQuestion {
    public let a: Int
    public let b: Int
    public var answer: Int { a * b }
    public var text: String { "\(a)×\(b)" }
}

public func makeQuestion(maxFactor: Int) -> SharedQuestion {
    .init(a: Int.random(in: 1...maxFactor),
          b: Int.random(in: 1...maxFactor))
}

public func makeChoices(correct: Int, maxValue: Int) -> [Int] {
    var set: Set<Int> = [correct]
    while set.count < 3 {
        let delta = Int.random(in: -8...8)
        let candidate = min(maxValue, max(0, correct + (delta == 0 ? 3 : delta)))
        set.insert(candidate)
    }
    return Array(set).shuffled()
}
