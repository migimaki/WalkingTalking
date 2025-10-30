//
//  Sentence.swift
//  WalkingTalking
//
//  Created by KEISUKE YANAGISAWA on 2025/10/30.
//

import Foundation
import SwiftData

@Model
final class Sentence {
    var id: UUID
    var text: String
    var order: Int
    var estimatedDuration: TimeInterval

    @Relationship(inverse: \Lesson.sentences)
    var lesson: Lesson?

    init(id: UUID = UUID(), text: String, order: Int, estimatedDuration: TimeInterval = 5.0) {
        self.id = id
        self.text = text
        self.order = order
        self.estimatedDuration = estimatedDuration
    }

    // Estimate duration based on word count
    static func estimateDuration(for text: String) -> TimeInterval {
        // Average: ~150 words per minute = 2.5 words per second
        let wordCount = text.split(separator: " ").count
        let estimatedDuration = Double(wordCount) / 2.5
        return max(estimatedDuration, 2.0) // Minimum 2 seconds
    }
}
