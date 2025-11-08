//
//  WalkingTalkingApp.swift
//  WalkingTalking
//
//  Created by KEISUKE YANAGISAWA on 2025/10/30.
//

import SwiftUI
import SwiftData

@main
struct WalkingTalkingApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Channel.self,
            Lesson.self,
            Sentence.self,
            LessonProgress.self,
        ])

        // Enable schema migration for new properties
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If migration fails, delete old database and start fresh
            print("ModelContainer creation failed: \(error)")
            print("Attempting to delete old database and create fresh container...")

            // Delete the old database file
            let url = modelConfiguration.url
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("sqlite-shm"))
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("sqlite-wal"))

            // Try creating container again with fresh database
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer even after cleanup: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ChannelListView()
        }
        .modelContainer(sharedModelContainer)
    }
}
