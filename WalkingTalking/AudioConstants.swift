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
    static let requiredSilentFrames: Int = 30  // ~1.5 seconds at 20 fps

    // TTS Configuration
    static let defaultSpeechRate: Float = AVSpeechUtteranceDefaultSpeechRate
    static let defaultLanguage = "en-US"

    // Audio Session
    static let audioSessionCategory: AVAudioSession.Category = .playAndRecord
    static let audioSessionMode: AVAudioSession.Mode = .default
    static let audioSessionOptions: AVAudioSession.CategoryOptions = [.defaultToSpeaker]

    // UI
    static let minProgressBarHeight: CGFloat = 4.0
    static let controlButtonSize: CGFloat = 60.0
    static let smallControlButtonSize: CGFloat = 44.0
}
