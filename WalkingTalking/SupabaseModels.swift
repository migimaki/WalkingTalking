//
//  SupabaseModels.swift
//  WalkingTalking
//
//  Created by Claude Code on 2025/11/01.
//

import Foundation

// MARK: - DTOs for Supabase API responses

/// Channel data from Supabase
struct ChannelDTO: Codable {
    let id: UUID
    let name: String
    let description: String
    let icon_name: String
    let language: String
    let created_at: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, language, created_at
        case icon_name
    }
}

/// Lesson data from Supabase
struct LessonDTO: Codable {
    let id: UUID
    let title: String
    let source_url: String
    let date: String // "YYYY-MM-DD" format
    let language: String
    let channel_id: UUID
    let created_at: String?

    enum CodingKeys: String, CodingKey {
        case id, title, date, language, created_at
        case source_url
        case channel_id
    }

    var parsedDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date) ?? Date()
    }
}

/// Sentence data from Supabase
struct SentenceDTO: Codable {
    let id: UUID
    let lesson_id: UUID
    let order_index: Int
    let text: String
    let audio_url: String
    let duration: Int // Duration in seconds

    enum CodingKeys: String, CodingKey {
        case id, text, duration
        case lesson_id
        case order_index
        case audio_url
    }

    var durationInSeconds: TimeInterval {
        TimeInterval(duration)
    }
}

/// Combined lesson with sentences
struct LessonWithSentences: Codable {
    let lesson: LessonDTO
    let sentences: [SentenceDTO]
}
