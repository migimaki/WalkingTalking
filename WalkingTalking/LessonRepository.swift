//
//  LessonRepository.swift
//  WalkingTalking
//
//  Created by Claude Code on 2025/11/01.
//

import Foundation
import Supabase
import SwiftData

/// Repository for fetching lesson data from Supabase
class LessonRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientManager.shared.client) {
        self.client = client
    }

    /// Fetch all lessons from Supabase
    func fetchAllLessons() async throws -> [LessonDTO] {
        let response: [LessonDTO] = try await client.database
            .from("lessons")
            .select()
            .order("date", ascending: false)
            .execute()
            .value

        return response
    }

    /// Fetch lessons for a specific date
    func fetchLessons(for date: Date) async throws -> [LessonDTO] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        let response: [LessonDTO] = try await client.database
            .from("lessons")
            .select()
            .eq("date", value: dateString)
            .execute()
            .value

        return response
    }

    /// Fetch a single lesson by ID
    func fetchLesson(id: UUID) async throws -> LessonDTO {
        let response: [LessonDTO] = try await client.database
            .from("lessons")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        guard let lesson = response.first else {
            throw RepositoryError.lessonNotFound
        }

        return lesson
    }

    /// Fetch all sentences for a specific lesson
    func fetchSentences(for lessonId: UUID) async throws -> [SentenceDTO] {
        let response: [SentenceDTO] = try await client.database
            .from("sentences")
            .select()
            .eq("lesson_id", value: lessonId.uuidString)
            .order("order_index", ascending: true)
            .execute()
            .value

        return response
    }

    /// Fetch lesson with all its sentences
    func fetchLessonWithSentences(id: UUID) async throws -> (lesson: LessonDTO, sentences: [SentenceDTO]) {
        async let lessonTask = fetchLesson(id: id)
        async let sentencesTask = fetchSentences(for: id)

        let lesson = try await lessonTask
        let sentences = try await sentencesTask

        return (lesson, sentences)
    }

    /// Save lessons and sentences to SwiftData
    func saveLessonsToSwiftData(_ lessonDTOs: [LessonDTO], sentences: [UUID: [SentenceDTO]], modelContext: ModelContext, channel: Channel) throws {
        for lessonDTO in lessonDTOs {
            // Check if lesson already exists
            let descriptor = FetchDescriptor<Lesson>(
                predicate: #Predicate { $0.id == lessonDTO.id }
            )

            let existingLessons = try modelContext.fetch(descriptor)

            if existingLessons.isEmpty {
                // Create new lesson
                let lesson = Lesson(
                    id: lessonDTO.id,
                    title: lessonDTO.title,
                    description: "", // No description in Supabase yet
                    date: lessonDTO.parsedDate,
                    sourceURL: lessonDTO.source_url
                )
                lesson.channel = channel

                // Add sentences
                if let sentenceDTOs = sentences[lessonDTO.id] {
                    for sentenceDTO in sentenceDTOs {
                        let sentence = Sentence(
                            id: sentenceDTO.id,
                            text: sentenceDTO.text,
                            order: sentenceDTO.order_index,
                            estimatedDuration: sentenceDTO.durationInSeconds,
                            audioURL: sentenceDTO.audio_url
                        )
                        lesson.sentences.append(sentence)
                    }
                }

                modelContext.insert(lesson)
            }
        }

        try modelContext.save()
    }
}

// MARK: - Repository Errors

enum RepositoryError: Error, LocalizedError {
    case lessonNotFound
    case networkError(String)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .lessonNotFound:
            return "Lesson not found"
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        }
    }
}
