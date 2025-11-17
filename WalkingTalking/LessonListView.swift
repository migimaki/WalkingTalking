//
//  LessonListView.swift
//  WalkingTalking
//
//  Created by Claude Code on 2025/11/01.
//

import SwiftUI
import SwiftData

struct LessonListView: View {
    @Environment(\.modelContext) private var modelContext
    let channel: Channel

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    // Query lessons for this specific channel
    private var lessons: [Lesson] {
        channel.lessons.sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack {
            if lessons.isEmpty && !isLoading {
                emptyStateView
            } else {
                lessonListView
            }

            if isLoading {
                ProgressView("Loading lessons...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
        .navigationTitle(channel.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: fetchLessonsFromSupabase) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Unknown error occurred")
        }
        .onAppear {
            // Auto-fetch if no lessons
            if lessons.isEmpty {
                fetchLessonsFromSupabase()
            }
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
        .refreshable {
            await fetchLessonsAsync()
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Lessons", systemImage: "book.closed")
        } description: {
            Text("Pull down to refresh or tap the refresh button to load lessons from \(channel.name)")
        } actions: {
            Button("Refresh") {
                fetchLessonsFromSupabase()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Actions

    private func fetchLessonsFromSupabase() {
        Task {
            await fetchLessonsAsync()
        }
    }

    private func fetchLessonsAsync() async {
        isLoading = true
        errorMessage = nil

        do {
            let repository = LessonRepository()

            // Fetch lessons for this specific channel
            let lessonDTOs = try await repository.fetchLessons(for: channel.id)

            // Fetch sentences for each lesson
            var sentencesDict: [UUID: [SentenceDTO]] = [:]
            for lessonDTO in lessonDTOs {
                let sentences = try await repository.fetchSentences(for: lessonDTO.id)
                sentencesDict[lessonDTO.id] = sentences
            }

            // Save to SwiftData
            try repository.saveLessonsToSwiftData(
                lessonDTOs,
                sentences: sentencesDict,
                modelContext: modelContext,
                channel: channel
            )

            print("✅ Successfully fetched \(lessonDTOs.count) lessons for channel '\(channel.name)' from Supabase")

        } catch {
            errorMessage = "Failed to fetch lessons: \(error.localizedDescription)"
            showError = true
            print("❌ Error fetching lessons: \(error)")
        }

        isLoading = false
    }

    private func deleteLessons(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(lessons[index])
            }
            try? modelContext.save()
        }
    }
}

// MARK: - Lesson Row View

struct LessonRowView: View {
    let lesson: Lesson

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(lesson.title)
                .font(.headline)
                .lineLimit(2)

            // Date
            HStack {
                Image(systemName: "calendar")
                Text(lesson.formattedDate)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Metadata
            HStack(spacing: 16) {
                Label("\(lesson.totalSentences) sentences", systemImage: "text.alignleft")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if lesson.estimatedTotalDuration > 0 {
                    Label(formatDuration(lesson.estimatedTotalDuration), systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let progress = lesson.progress, progress.currentSentenceIndex > 0 {
                    Text("\(progress.currentSentenceIndex)/\(lesson.totalSentences)")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    @Previewable @State var channel = Channel.euroNews

    NavigationStack {
        LessonListView(channel: channel)
    }
    .modelContainer(for: [Channel.self, Lesson.self], inMemory: true)
}
