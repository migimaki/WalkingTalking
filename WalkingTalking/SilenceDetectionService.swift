//
//  SilenceDetectionService.swift
//  WalkingTalking
//
//  Created by KEISUKE YANAGISAWA on 2025/10/30.
//
//  Detects silence in audio input.
//
//  Behavior:
//  - Can be enabled/disabled via isEnabled flag
//  - When enabled, counts silence frames
//  - If user speaks, resets the silence counter
//  - After ~1.5 seconds of silence, triggers silenceDetected()
//  - Disabled during TTS playback to prevent premature triggering
//

import AVFoundation
import Foundation

protocol SilenceDetectionDelegate: AnyObject {
    func silenceDetected()
    func voiceActivityDetected()
}

class SilenceDetectionService {
    weak var delegate: SilenceDetectionDelegate?

    // Configuration
    var silenceThreshold: Float = AudioConstants.silenceThresholdDB
    var requiredSilentFrames: Int = AudioConstants.requiredSilentFrames
    var isEnabled: Bool = true  // Can pause/resume silence counting

    // State tracking
    private var baselineNoiseLevel: Float = -60.0
    private var adaptiveSilenceThreshold: Float = AudioConstants.silenceThresholdDB
    private var voiceDetectedInSession = false
    private var consecutiveSilentFrames = 0

    var isVoiceActive: Bool {
        voiceDetectedInSession && consecutiveSilentFrames < 5
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        autoreleasepool {
            let rms = calculateRMS(buffer)
            let dB = 20 * log10(max(rms, 1e-10)) // Avoid log(0)

            // Calibrate baseline noise (only at the beginning)
            if !voiceDetectedInSession && consecutiveSilentFrames < 10 {
                if dB < baselineNoiseLevel {
                    baselineNoiseLevel = dB
                    adaptiveSilenceThreshold = baselineNoiseLevel + 15.0 // 15dB above noise
                }
            }

            // Voice activity detection
            if dB > adaptiveSilenceThreshold {
                // Voice detected - reset silence counter
                if !voiceDetectedInSession {
                    voiceDetectedInSession = true
                }
                consecutiveSilentFrames = 0
                delegate?.voiceActivityDetected()
            } else if isEnabled {
                // Silence detected - count silent frames only if enabled
                // This prevents counting silence during TTS playback
                consecutiveSilentFrames += 1

                if consecutiveSilentFrames >= requiredSilentFrames {
                    // Silence threshold reached - advance to next sentence
                    delegate?.silenceDetected()
                    resetSession()
                }
            }
        }
    }

    func resetSession() {
        voiceDetectedInSession = false
        consecutiveSilentFrames = 0
        baselineNoiseLevel = -60.0
        adaptiveSilenceThreshold = AudioConstants.silenceThresholdDB
    }

    private func calculateRMS(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)

        guard frameLength > 0 else { return 0 }

        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelDataValue[i]
            sum += sample * sample
        }

        return sqrt(sum / Float(frameLength))
    }
}
