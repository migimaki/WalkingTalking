//
//  Lesson.swift
//  WalkingTalking
//
//  Created by KEISUKE YANAGISAWA on 2025/10/30.
//

import Foundation
import SwiftData

@Model
final class Lesson {
    var id: UUID
    var title: String
    var lessonDescription: String
    var createdDate: Date

    @Relationship(deleteRule: .cascade)
    var sentences: [Sentence]

    @Relationship(deleteRule: .cascade)
    var progress: LessonProgress?

    init(id: UUID = UUID(), title: String, description: String) {
        self.id = id
        self.title = title
        self.lessonDescription = description
        self.createdDate = Date()
        self.sentences = []
    }

    var totalSentences: Int {
        sentences.count
    }

    var estimatedTotalDuration: TimeInterval {
        sentences.reduce(0.0) { $0 + $1.estimatedDuration }
    }
}
