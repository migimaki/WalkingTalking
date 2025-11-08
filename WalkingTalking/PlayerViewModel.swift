//
//  PlayerViewModel.swift
//  WalkingTalking
//
//  Created by KEISUKE YANAGISAWA on 2025/10/30.
//
//  Manages playback, recording, and speech recognition for language practice.
//
//  Flow:
//  1. Audio plays from Supabase
//  2. Recording + Speech recognition start IMMEDIATELY (shadowing practice)
//  3. User can speak along with audio or wait until it finishes
//  4. After ~1.5 seconds of silence, auto-advance to next sentence
//
//  Note: Requires headphones to prevent audio from being picked up by mic
//

import Foundation
import SwiftData
import AVFoundation
import UIKit

@Observable
class PlayerViewModel {
    // Dependencies
    private let audioPlayerService: AudioPlayerService
    private let audioCacheService: AudioCacheService
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
    var isLoadingAudio: Bool = false

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

    var isCompleted: Bool {
        !isPlaying && currentSentenceIndex >= totalSentences - 1 && totalSentences > 0
    }

    // MARK: - Mic Level Info (for UI indicator)

    var currentMicLevelDB: Float {
        silenceDetector.currentAudioLevelDB
    }

    var micThresholdDB: Float {
        silenceDetector.currentThresholdDB
    }

    // MARK: - Audio Device Info

    var currentInputDevice: String {
        audioSessionManager.getCurrentInputDevice()
    }

    var currentOutputDevice: String {
        audioSessionManager.getCurrentOutputDevice()
    }

    var availableInputDevices: [String] {
        audioSessionManager.getAvailableInputDevices()
    }

    init(lesson: Lesson,
         audioPlayerService: AudioPlayerService = AudioPlayerService(),
         audioCacheService: AudioCacheService = AudioCacheService.shared,
         recordingService: AudioRecordingService = AudioRecordingService(),
         silenceDetector: SilenceDetectionService = SilenceDetectionService(),
         speechRecognitionService: SpeechRecognitionService = SpeechRecognitionService(),
         audioSessionManager: AudioSessionManager = AudioSessionManager.shared) {
        self.lesson = lesson
        self.audioPlayerService = audioPlayerService
        self.audioCacheService = audioCacheService
        self.recordingService = recordingService
        self.silenceDetector = silenceDetector
        self.speechRecognitionService = speechRecognitionService
        self.audioSessionManager = audioSessionManager

        setupDelegates()
    }

    private func setupDelegates() {
        audioPlayerService.delegate = self
        recordingService.delegate = self
        silenceDetector.delegate = self
        speechRecognitionService.delegate = self
        audioSessionManager.delegate = self
    }

    // MARK: - Lifecycle

    func setup() {
        requestMicrophonePermission()
        requestSpeechRecognitionPermission()
        // Always start from the first sentence
        currentSentenceIndex = 0
    }

    func cleanup() {
        stop()
        speechRecognitionService.stopRecognition()
        audioSessionManager.deactivate()

        // Re-enable screen auto-lock (in case user navigates away while playing)
        UIApplication.shared.isIdleTimerDisabled = false

        // Reset to beginning for next time
        currentSentenceIndex = 0
        recognizedText = ""
        recognizedTextBySentence.removeAll()
    }

    func handleBackground() {
        // App went to background - ensure audio session and recording stays active
        print("[PlayerViewModel] Handling background transition, isRecording: \(isRecording), isPlaying: \(isPlaying)")

        // Don't reconfigure anything - just let background audio mode handle it
        // The audio session is already configured for playAndRecord with background support
        print("[PlayerViewModel] Audio session already configured for background, no action needed")
    }

    func handleForeground() {
        // App returned to foreground
        print("[PlayerViewModel] Handling foreground transition, isRecording: \(isRecording), isPlaying: \(isPlaying)")
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

    // Progress tracking disabled - always start from beginning

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

        // Keep screen on during practice (dims but doesn't lock)
        UIApplication.shared.isIdleTimerDisabled = true
        print("[PlayerViewModel] 🔆 Screen will stay on during practice")

        isPlaying = true
        playCurrentSentence()
    }

    func pause() {
        guard isPlaying else { return }

        isPlaying = false
        playbackState = .idle

        // Re-enable screen auto-lock
        UIApplication.shared.isIdleTimerDisabled = false
        print("[PlayerViewModel] 🌙 Screen auto-lock re-enabled")

        if audioPlayerService.isPlaying {
            audioPlayerService.stop()
        }

        if recordingService.isRecording {
            recordingService.stopRecording()
            isRecording = false
            silenceDetector.resetSession()
        }

        if speechRecognitionService.isRecognizing {
            speechRecognitionService.stopRecognition()
        }
    }

    func stop() {
        pause()
        currentSentenceIndex = 0
    }

    func restart() {
        pause()
        currentSentenceIndex = 0
        recognizedText = ""
        recognizedTextBySentence.removeAll()
        play()
    }

    func goToPreviousSentence() {
        guard canGoToPrevious else { return }

        let wasPlaying = isPlaying
        pause()

        currentSentenceIndex -= 1

        if wasPlaying {
            play()
        }
    }

    func goToNextSentence() {
        guard canGoToNext else { return }

        let wasPlaying = isPlaying
        pause()

        currentSentenceIndex += 1

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

        // Download audio file if needed (async)
        Task {
            do {
                isLoadingAudio = true

                // Get audio file from cache or download from Supabase
                let localAudioURL = try await audioCacheService.getAudioFile(from: sentence.audioURL)

                // Configure for recording (playAndRecord allows both audio playback and mic simultaneously)
                try audioSessionManager.configureForRecording()

                // Reset recognized text for new recording
                recognizedText = ""
                speechRecognitionService.resetText()

                // Start recording and speech recognition immediately (for shadowing practice)
                do {
                    silenceDetector.resetSession()
                    // Disable silence counting during audio playback
                    silenceDetector.isEnabled = false
                    print("[PlayerViewModel] Starting recording, silence detection disabled")

                    try recordingService.startRecording()
                    isRecording = true

                    // Start speech recognition if permission granted
                    if hasSpeechRecognitionPermission {
                        try? speechRecognitionService.startRecognition()
                    }
                } catch {
                    errorMessage = "Failed to start recording: \(error.localizedDescription)"
                }

                // Play audio file (recording already running for shadowing)
                try audioPlayerService.play(from: localAudioURL)
                isLoadingAudio = false

            } catch {
                isLoadingAudio = false
                errorMessage = "Failed to load audio: \(error.localizedDescription)"
                pause()
            }
        }
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
        } else {
            // Move to next sentence
            currentSentenceIndex += 1

            if isPlaying {
                // Continue playing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.playCurrentSentence()
                }
            }
        }
    }
}

// MARK: - AudioPlayerServiceDelegate

extension PlayerViewModel: AudioPlayerServiceDelegate {
    func audioDidStart() {
        // Audio playback started
    }

    func audioDidFinish() {
        guard isPlaying else { return }

        print("[PlayerViewModel] Audio finished, enabling silence detection")
        playbackState = .waitingForUser

        // Enable silence counting now that audio finished
        silenceDetector.isEnabled = true

        // Transition to listening state (recording already running for shadowing)
        startListeningForUser()
    }

    func audioDidFail(error: Error) {
        errorMessage = "Audio playback failed: \(error.localizedDescription)"
        pause()
    }
}

// MARK: - AudioRecordingServiceDelegate

extension PlayerViewModel: AudioRecordingServiceDelegate {
    private static var bufferCount = 0

    func didReceiveAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Log every 50th buffer to avoid spam
        Self.bufferCount += 1
        if Self.bufferCount % 50 == 0 {
            print("[PlayerViewModel] Processing audio buffers, silence detection enabled: \(silenceDetector.isEnabled)")
        }

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
        print("[PlayerViewModel] Silence detected, isPlaying: \(isPlaying), playbackState: \(playbackState)")
        guard isPlaying && playbackState == .listeningToUser else {
            print("[PlayerViewModel] Not advancing: isPlaying=\(isPlaying), playbackState=\(playbackState)")
            return
        }

        // User finished speaking, advance to next sentence
        print("[PlayerViewModel] Advancing to next sentence")
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

    func audioRouteChanged() {
        // Audio route changed (e.g., Bluetooth headphones connected, or background transition)
        print("[PlayerViewModel] Audio route changed to: \(audioSessionManager.getCurrentOutputDevice()), isRecording: \(isRecording), isPlaying: \(isPlaying)")

        // For background transitions, just log the change
        // Don't restart anything - let iOS handle the route change naturally
        // The background audio mode and audio session category should keep everything running
        print("[PlayerViewModel] Route change detected, audio should continue automatically")
    }
}
