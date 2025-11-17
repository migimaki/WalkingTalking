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
    @AppStorage("learningLanguage") private var learningLanguage: String = "en"
    @State private var showSettings = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let repository = LessonRepository()
    private var settings: UserSettings { UserSettings.shared }

    // Computed property to get filtered channels based on learning language
    private var channels: [Channel] {
        let descriptor = FetchDescriptor<Channel>(
            predicate: #Predicate { channel in
                channel.language == learningLanguage
            },
            sortBy: [SortDescriptor(\Channel.name)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView("Loading channels...")
                } else if channels.isEmpty {
                    // Empty state
                    ContentUnavailableView {
                        Label("No Channels", systemImage: "antenna.radiowaves.left.and.right.slash")
                    } description: {
                        Text("No channels available for \(settings.language(for: learningLanguage)?.displayName ?? ""). Tap the refresh button to load channels from Supabase.")
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
            .navigationTitle("Channels - \(settings.language(for: learningLanguage)?.nativeName ?? "")")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await fetchChannelsFromSupabase()
                        }
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                // Fetch channels from Supabase if needed
                if channels.isEmpty {
                    Task {
                        await fetchChannelsFromSupabase()
                    }
                }
            }
            .onChange(of: learningLanguage) { oldValue, newValue in
                // Automatically fetch channels when learning language changes
                Task {
                    await fetchChannelsFromSupabase()
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private func fetchChannelsFromSupabase() async {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch channels for the selected learning language from Supabase
            let channelDTOs = try await repository.fetchChannels(for: learningLanguage)

            // Save to SwiftData
            try repository.saveChannelsToSwiftData(channelDTOs, modelContext: modelContext)

            print("Successfully fetched and saved \(channelDTOs.count) channels for \(learningLanguage) from Supabase")
        } catch {
            errorMessage = "Failed to fetch channels: \(error.localizedDescription)"
            print("Error fetching channels: \(error)")
        }

        isLoading = false
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
