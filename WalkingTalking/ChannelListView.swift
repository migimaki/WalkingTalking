//
//  ChannelListView.swift
//  WalkingTalking
//
//  Created by Claude Code on 2025/11/01.
//

import SwiftUI
import SwiftData

struct ChannelListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var channels: [Channel]

    var body: some View {
        NavigationStack {
            ZStack {
                if channels.isEmpty {
                    // Empty state
                    ContentUnavailableView {
                        Label("No Channels", systemImage: "antenna.radiowaves.left.and.right.slash")
                    } description: {
                        Text("Channels will appear here")
                    }
                } else {
                    List {
                        ForEach(channels) { channel in
                            NavigationLink {
                                LessonListView(channel: channel)
                            } label: {
                                ChannelRow(channel: channel)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Channels")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: initializeChannels) {
                        Label("Initialize", systemImage: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                // Initialize default channel if needed
                if channels.isEmpty {
                    initializeChannels()
                }
            }
        }
    }

    private func initializeChannels() {
        // Add Euro News channel if it doesn't exist
        let euroNewsId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let descriptor = FetchDescriptor<Channel>(
            predicate: #Predicate { $0.id == euroNewsId }
        )

        if let existingChannels = try? modelContext.fetch(descriptor),
           existingChannels.isEmpty {
            let euroNews = Channel.euroNews
            modelContext.insert(euroNews)
            try? modelContext.save()
        }
    }
}

// MARK: - Channel Row

struct ChannelRow: View {
    let channel: Channel

    var body: some View {
        HStack(spacing: 16) {
            // Channel icon
            Image(systemName: channel.iconName)
                .font(.title)
                .foregroundStyle(.blue)
                .frame(width: 50, height: 50)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(channel.name)
                    .font(.headline)

                Text(channel.channelDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if !channel.lessons.isEmpty {
                    Text("\(channel.lessons.count) lessons")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ChannelListView()
        .modelContainer(for: [Channel.self, Lesson.self, Sentence.self], inMemory: true)
}
