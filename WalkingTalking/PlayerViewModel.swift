//
//  PlayerViewModel.swift
//  WalkingTalking
//
//  Created by KEISUKE YANAGISAWA on 2025/10/30.
//
//  Manages playback, recording, and speech recognition for language practice.
//
//  Flow:
//  1. TTS speaks sentence
//  2. Recording + Speech recognition start IMMEDIATELY (shadowing practice)
//  3. User can speak along with TTS or wait until it finishes
//  4. After ~1.5 seconds of silence, auto-advance to next sentence
//
//  Note: Requires headphones to prevent TTS audio from being picked up by mic
//

import Foundation
import SwiftData
import AVFoundation

@Observable
class PlayerViewModel {
    // Dependencies
    private let ttsService: TextToSpeechService
    private let recordingService: AudioRecordingService
    private let silenceDetector: SilenceDetectionService
    private let speechRecognitionService: SpeechRecognitionService
    private let audioSessionManager: AudioSessionManager

    // State
    var lesson: Lesson
    var currentSentenceIndex: Int = 0
    var isPlaying: Bool = false
    var isRecording: Bool = false
    var playbackState: PlaybackState = .idle
    var hasMicrophonePermission: Bool = false
    var hasSpeechRecognitionPermission: Bool = false
    var recognizedText: String = ""
    var recognizedTextBySentence: [Int: String] = [:] // Store recognized text per sentence index
    var errorMessage: String?

    enum PlaybackState {
        case idle
        case speaking
        case waitingForUser
        case listeningToUser
        case processingTransition
    }

    // Computed properties
    var currentSentence: Sentence? {
        guard currentSentenceIndex < lesson.sentences.count else { return nil }
        return lesson.sentences.sorted(by: { $0.order < $1.order })[currentSentenceIndex]
    }

    var totalSentences: Int {
        lesson.sentences.count
    }

    var currentProgress: Double {
        guard totalSentences > 0 else { return 0 }
        return Double(currentSentenceIndex) / Double(totalSentences)
    }

    var canGoToPrevious: Bool {
        currentSentenceIndex > 0
    }

    var canGoToNext: Bool {
        currentSentenceIndex < totalSentences - 1
    }

    var isVoiceActive: Bool {
        silenceDetector.isVoiceActive
    }

    init(lesson: Lesson,
         ttsService: TextToSpeechService = TextToSpeechService(),
         recordingService: AudioRecordingService = AudioRecordingService(),
         silenceDetector: SilenceDetectionService = SilenceDetectionService(),
         speechRecognitionService: SpeechRecognitionService = SpeechRecognitionService(),
         audioSessionManager: AudioSessionManager = AudioSessionManager.shared) {
        self.lesson = lesson
        self.ttsService = ttsService
        self.recordingService = recordingService
        self.silenceDetector = silenceDetector
        self.speechRecognitionService = speechRecognitionService
        self.audioSessionManager = audioSessionManager

        setupDelegates()
    }

    private func setupDelegates() {
        ttsService.delegate = self
        recordingService.delegate = self
        silenceDetector.delegate = self
        speechRecognitionService.delegate = self
        audioSessionManager.delegate = self
    }

    // MARK: - Lifecycle

    func setup() {
        requestMicrophonePermission()
        requestSpeechRecognitionPermission()
        restoreProgress()
    }

    func cleanup() {
        stop()
        speechRecognitionService.stopRecognition()
        audioSessionManager.deactivate()

        // Reset to beginning for next time
        currentSentenceIndex = 0
        recognizedText = ""
        recognizedTextBySentence.removeAll()
        saveProgress()
    }

    private func requestMicrophonePermission() {
        recordingService.requestMicrophonePermission { [weak self] granted in
            self?.hasMicrophonePermission = granted
            if !granted {
                self?.errorMessage = "Microphone access is required to practice speaking"
            }
        }
    }

    private func requestSpeechRecognitionPermission() {
        speechRecognitionService.requestAuthorization { [weak self] granted in
            self?.hasSpeechRecognitionPermission = granted
            // Speech recognition is optional - no error if denied
        }
    }

    private func restoreProgress() {
        if let progress = lesson.progress {
            currentSentenceIndex = progress.currentSentenceIndex
        }
    }

    private func saveProgress() {
        if lesson.progress == nil {
            lesson.progress = LessonProgress()
        }
        lesson.progress?.updateProgress(currentIndex: currentSentenceIndex)
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        guard !isPlaying else { return }
        guard hasMicrophonePermission else {
            errorMessage = "Please grant microphone permission to continue"
            return
        }
        guard currentSentence != nil else { return }

        isPlaying = true
        playCurrentSentence()
    }

    func pause() {
        guard isPlaying else { return }

        isPlaying = false
        playbackState = .idle

        if ttsService.isSpeaking {
            ttsService.stop()
        }

        if recordingService.isRecording {
            recordingService.stopRecording()
            isRecording = false
            silenceDetector.resetSession()
        }

        if speechRecognitionService.isRecognizing {
            speechRecognitionService.stopRecognition()
        }

        saveProgress()
    }

    func stop() {
        pause()
        currentSentenceIndex = 0
        saveProgress()
    }

    func goToPreviousSentence() {
        guard canGoToPrevious else { return }

        let wasPlaying = isPlaying
        pause()

        currentSentenceIndex -= 1
        saveProgress()

        if wasPlaying {
            play()
        }
    }

    func goToNextSentence() {
        guard canGoToNext else { return }

        let wasPlaying = isPlaying
        pause()

        currentSentenceIndex += 1
        saveProgress()

        if wasPlaying {
            play()
        }
    }

    // MARK: - Playback Flow

    private func playCurrentSentence() {
        guard let sentence = currentSentence else {
            pause()
            return
        }

        playbackState = .speaking

        // Configure for recording (playAndRecord allows both TTS and mic simultaneously)
        do {
            try audioSessionManager.configureForRecording()
        } catch {
            errorMessage = "Failed to configure audio: \(error.localizedDescription)"
            pause()
            return
        }

        // Reset recognized text for new recording
        recognizedText = ""
        speechRecognitionService.resetText()

        // Start recording and speech recognition immediately (for shadowing practice)
        do {
            silenceDetector.resetSession()
            // Disable silence counting during TTS playback
            silenceDetector.isEnabled = false

            try recordingService.startRecording()
            isRecording = true

            // Start speech recognition if permission granted
            if hasSpeechRecognitionPermission {
                try? speechRecognitionService.startRecognition()
            }
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }

        // Speak sentence (recording already running for shadowing)
        ttsService.speak(sentence.text)
    }

    private func startListeningForUser() {
        // Transition to listening state
        // Recording is already running from TTS start, so no need to start it again
        playbackState = .listeningToUser
    }

    private func stopListening() {
        if recordingService.isRecording {
            recordingService.stopRecording()
            isRecording = false
        }

        if speechRecognitionService.isRecognizing {
            speechRecognitionService.stopRecognition()
        }
    }

    private func advanceToNextSentence() {
        playbackState = .processingTransition

        // Save recognized text for current sentence before moving
        if !recognizedText.isEmpty {
            recognizedTextBySentence[currentSentenceIndex] = recognizedText
        }

        stopListening()

        // Mark sentence as completed
        lesson.progress?.markSentenceCompleted()

        // Check if we've reached the end
        if currentSentenceIndex >= totalSentences - 1 {
            // Lesson complete
            pause()
            currentSentenceIndex = totalSentences - 1
            saveProgress()
        } else {
            // Move to next sentence
            currentSentenceIndex += 1
            saveProgress()

            if isPlaying {
                // Continue playing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.playCurrentSentence()
                }
            }
        }
    }
}

// MARK: - TextToSpeechServiceDelegate

extension PlayerViewModel: TextToSpeechServiceDelegate {
    func speechDidStart() {
        // Speech started
    }

    func speechDidFinish() {
        guard isPlaying else { return }

        playbackState = .waitingForUser

        // Enable silence counting now that TTS finished
        silenceDetector.isEnabled = true

        // Transition to listening state (recording already running for shadowing)
        startListeningForUser()
    }

    func speechDidCancel() {
        // Speech was cancelled
    }
}

// MARK: - AudioRecordingServiceDelegate

extension PlayerViewModel: AudioRecordingServiceDelegate {
    func didReceiveAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Process buffer for silence detection
        silenceDetector.processAudioBuffer(buffer)

        // Process buffer for speech recognition
        if speechRecognitionService.isRecognizing {
            speechRecognitionService.processAudioBuffer(buffer)
        }
    }

    func recordingDidFail(error: Error) {
        errorMessage = "Recording failed: \(error.localizedDescription)"
        pause()
    }
}

// MARK: - SilenceDetectionDelegate

extension PlayerViewModel: SilenceDetectionDelegate {
    func silenceDetected() {
        guard isPlaying && playbackState == .listeningToUser else { return }

        // User finished speaking, advance to next sentence
        DispatchQueue.main.async { [weak self] in
            self?.advanceToNextSentence()
        }
    }

    func voiceActivityDetected() {
        // Voice activity detected (for UI feedback)
    }
}

// MARK: - SpeechRecognitionServiceDelegate

extension PlayerViewModel: SpeechRecognitionServiceDelegate {
    func didRecognizeText(_ text: String) {
        recognizedText = text
    }

    func recognitionDidFail(error: Error) {
        // Speech recognition failure is non-critical - just log it
        print("Speech recognition failed: \(error.localizedDescription)")
    }
}

// MARK: - AudioSessionManagerDelegate

extension PlayerViewModel: AudioSessionManagerDelegate {
    func audioSessionInterrupted() {
        pause()
    }

    func audioSessionResumed() {
        // Optionally auto-resume, but for now just pause
    }
}
