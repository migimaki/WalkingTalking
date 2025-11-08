//
//  AudioConstants.swift
//  WalkingTalking
//
//  Created by KEISUKE YANAGISAWA on 2025/10/30.
//

import AVFoundation
import SwiftUI

enum AudioConstants {
    // Silence Detection
    static let silenceThresholdDB: Float = -40.0
    static let silenceDuration: TimeInterval = 1.5  // seconds
    static let audioBufferSize: AVAudioFrameCount = 1024
    // At 48kHz (Bluetooth) with 1024 buffer: 1024/48000 = 21.3ms per buffer
    // For ~1 second: 1000ms / 21.3ms = ~47 frames (compromise for responsiveness)
    static let requiredSilentFrames: Int = 47  // ~1 second of silence

    // TTS Configuration
    static let defaultSpeechRate: Float = AVSpeechUtteranceDefaultSpeechRate
    static let defaultLanguage = "en-US"

    // Audio Session
    static let audioSessionCategory: AVAudioSession.Category = .playAndRecord
    static let audioSessionMode: AVAudioSession.Mode = .voiceChat
    static let audioSessionOptions: AVAudioSession.CategoryOptions = [.allowBluetooth]

    // UI
    static let minProgressBarHeight: CGFloat = 4.0
    static let controlButtonSize: CGFloat = 60.0
    static let smallControlButtonSize: CGFloat = 44.0
}
