//
//  LessonProgress.swift
//  WalkingTalking
//
//  Created by KEISUKE YANAGISAWA on 2025/10/30.
//

import Foundation
import SwiftData

@Model
final class LessonProgress {
    var id: UUID
    var currentSentenceIndex: Int
    var completedSentences: Int
    var lastPlayedDate: Date
    var totalPracticeTime: TimeInterval

    @Relationship(inverse: \Lesson.progress)
    var lesson: Lesson?

    init(id: UUID = UUID(), currentSentenceIndex: Int = 0) {
        self.id = id
        self.currentSentenceIndex = currentSentenceIndex
        self.completedSentences = 0
        self.lastPlayedDate = Date()
        self.totalPracticeTime = 0
    }

    func updateProgress(currentIndex: Int) {
        self.currentSentenceIndex = currentIndex
        self.lastPlayedDate = Date()
    }

    func markSentenceCompleted() {
        self.completedSentences += 1
    }

    func reset() {
        self.currentSentenceIndex = 0
        self.completedSentences = 0
        self.lastPlayedDate = Date()
    }
}
