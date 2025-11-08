//
//  ContentView.swift
//  WalkingTalking
//
//  Created by KEISUKE YANAGISAWA on 2025/10/30.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Lesson.createdDate, order: .reverse) private var lessons: [Lesson]

    var body: some View {
        NavigationStack {
            if lessons.isEmpty {
                emptyStateView
            } else {
                lessonListView
            }
        }
        .onAppear {
            loadSampleDataIfNeeded()
        }
    }

    private var lessonListView: some View {
        List {
            ForEach(lessons) { lesson in
                NavigationLink {
                    PlayerView(lesson: lesson)
                } label: {
                    LessonRowView(lesson: lesson)
                }
            }
            .onDelete(perform: deleteLessons)
        }
        .navigationTitle("Lessons")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Lessons Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Sample lesson will be loaded automatically")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .navigationTitle("Lessons")
    }

    private func loadSampleDataIfNeeded() {
        if lessons.isEmpty {
            LessonDataService.initializeSampleData(context: modelContext)
        }
    }

    private func deleteLessons(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(lessons[index])
            }
        }
    }
}

// LessonRowView moved to LessonListView.swift

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Lesson.self, configurations: config)

    // Create sample lesson
    let lesson = Lesson(
        title: "6 Minute English",
        description: "AI and Art - Today, we're diving into a fascinating question"
    )

    for i in 0..<12 {
        let sentence = Sentence(
            text: "Sample sentence \(i + 1)",
            order: i
        )
        lesson.sentences.append(sentence)
    }

    container.mainContext.insert(lesson)

    return ContentView()
        .modelContainer(container)
}
