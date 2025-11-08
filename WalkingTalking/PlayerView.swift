//
//  PlayerView.swift
//  WalkingTalking
//
//  Created by KEISUKE YANAGISAWA on 2025/10/30.
//

import SwiftUI
import SwiftData

struct PlayerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PlayerViewModel
    @State private var showDebugMenu = false

    init(lesson: Lesson) {
        _viewModel = State(initialValue: PlayerViewModel(lesson: lesson))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Lesson description (if available)
            if !viewModel.lesson.lessonDescription.isEmpty {
                Text(viewModel.lesson.lessonDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGroupedBackground))
            }

            // All sentences in scrollable panel with inline recognized text
            if !viewModel.lesson.sentences.isEmpty {
                SentencesScrollView(
                    sentences: viewModel.lesson.sentences.sorted(by: { $0.order < $1.order }),
                    currentIndex: viewModel.currentSentenceIndex,
                    isPlaying: viewModel.isPlaying,
                    recognizedTextBySentence: viewModel.recognizedTextBySentence,
                    currentRecognizedText: viewModel.recognizedText
                )
                .background(Color(.systemBackground))
            } else {
                Spacer()
                Text("No sentences available")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Spacer()
            }

            // Bottom controls area
            VStack(spacing: 0) {
                // Mic level indicator bar
                MicLevelBar(
                    currentLevelDB: viewModel.currentMicLevelDB,
                    thresholdDB: viewModel.micThresholdDB,
                    isRecording: viewModel.isRecording
                )

                // Discrete border
                Divider()
                    .background(Color.gray.opacity(0.3))

                VStack(spacing: 12) {
                    // Player controls
                    PlayerControlsView(
                        isPlaying: viewModel.isPlaying,
                        canGoBack: viewModel.canGoToPrevious,
                        canGoForward: viewModel.canGoToNext,
                        onPlayPause: { viewModel.togglePlayPause() },
                        onRewind: { viewModel.goToPreviousSentence() },
                        onForward: { viewModel.goToNextSentence() }
                    )
                }
                .padding(.vertical, 12)
            }
        }
        .navigationTitle(viewModel.lesson.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showDebugMenu = true
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
        .sheet(isPresented: $showDebugMenu) {
            AudioDeviceDebugView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.setup()
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
}

// MARK: - Audio Device Debug View

struct AudioDeviceDebugView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: PlayerViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Current Audio Devices") {
                    LabeledContent("Speaker/Output") {
                        Text(viewModel.currentOutputDevice)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)
                    }

                    LabeledContent("Microphone/Input") {
                        Text(viewModel.currentInputDevice)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }

                Section("Available Input Devices") {
                    if viewModel.availableInputDevices.isEmpty {
                        Text("No input devices found")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.availableInputDevices, id: \.self) { device in
                            HStack {
                                Text(device)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                if device == viewModel.currentInputDevice {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }

                Section("Debug Info") {
                    LabeledContent("Mic Permission") {
                        Text(viewModel.hasMicrophonePermission ? "✓ Granted" : "✗ Denied")
                            .foregroundColor(viewModel.hasMicrophonePermission ? .green : .red)
                    }

                    LabeledContent("Speech Recognition") {
                        Text(viewModel.hasSpeechRecognitionPermission ? "✓ Granted" : "✗ Denied")
                            .foregroundColor(viewModel.hasSpeechRecognitionPermission ? .green : .red)
                    }

                    LabeledContent("Recording Status") {
                        Text(viewModel.isRecording ? "🔴 Recording" : "⚫️ Not Recording")
                    }

                    LabeledContent("Playback Status") {
                        Text(viewModel.isPlaying ? "▶️ Playing" : "⏸️ Paused")
                    }
                }
            }
            .navigationTitle("Audio Device Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Lesson.self, configurations: config)

    // Create sample lesson
    let lesson = Lesson(
        title: "6 Minute English",
        description: "AI and Art"
    )

    let sentences = [
        "Today, we're diving into a fascinating question: Can AI really create art?",
        "Yeah, that's a big one.",
        "Over the past few years, we've seen AI models generating art.",
        "Some pieces have sold for thousands of dollars."
    ]

    for (index, text) in sentences.enumerated() {
        let sentence = Sentence(text: text, order: index)
        lesson.sentences.append(sentence)
    }

    container.mainContext.insert(lesson)

    return NavigationStack {
        PlayerView(lesson: lesson)
    }
    .modelContainer(container)
}
