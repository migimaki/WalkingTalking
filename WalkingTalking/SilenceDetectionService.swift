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
    private let minimumThresholdDB: Float = -50.0  // Never go below this threshold
    private let maximumThresholdDB: Float = -30.0  // Never go above this threshold

    // Mic level info (for UI indicator)
    private(set) var currentAudioLevelDB: Float = -80.0
    private(set) var currentThresholdDB: Float = AudioConstants.silenceThresholdDB

    var isVoiceActive: Bool {
        voiceDetectedInSession && consecutiveSilentFrames < 5
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        autoreleasepool {
            let rms = calculateRMS(buffer)
            let dB = 20 * log10(max(rms, 1e-10)) // Avoid log(0)

            // Calibrate baseline noise (only at the beginning)
            if !voiceDetectedInSession && consecutiveSilentFrames < 10 {
                // Only calibrate if we get a reasonable noise level (not too low)
                if dB < baselineNoiseLevel && dB > -80.0 {
                    baselineNoiseLevel = dB
                    // Use more lenient threshold for Bluetooth headphones
                    let calculatedThreshold = baselineNoiseLevel + 12.0
                    // Clamp threshold to reasonable bounds
                    adaptiveSilenceThreshold = max(minimumThresholdDB, min(maximumThresholdDB, calculatedThreshold))
                    print("[SilenceDetection] Calibrated threshold: \(adaptiveSilenceThreshold) dB (baseline: \(baselineNoiseLevel) dB)")
                }
            }

            // Update current values for UI indicator
            currentAudioLevelDB = dB
            currentThresholdDB = adaptiveSilenceThreshold

            // Voice activity detection
            if dB > adaptiveSilenceThreshold {
                // Voice detected - reset silence counter
                if !voiceDetectedInSession {
                    voiceDetectedInSession = true
                    print("[SilenceDetection] Voice detected: \(dB) dB > threshold: \(adaptiveSilenceThreshold) dB")
                }
                if consecutiveSilentFrames > 0 {
                    print("[SilenceDetection] Voice interrupted silence after \(consecutiveSilentFrames) frames")
                }
                consecutiveSilentFrames = 0
                delegate?.voiceActivityDetected()
            } else if isEnabled {
                // Silence detected - count silent frames only if enabled
                // This prevents counting silence during TTS playback
                consecutiveSilentFrames += 1

                if consecutiveSilentFrames == 1 {
                    print("[SilenceDetection] Silence started, current level: \(dB) dB <= threshold: \(adaptiveSilenceThreshold) dB")
                }

                // Log progress every 10 frames
                if consecutiveSilentFrames % 10 == 0 {
                    print("[SilenceDetection] Silence continues: \(consecutiveSilentFrames)/\(requiredSilentFrames) frames")
                }

                if consecutiveSilentFrames >= requiredSilentFrames {
                    // Silence threshold reached - advance to next sentence
                    print("[SilenceDetection] ✅ Silence detected after \(consecutiveSilentFrames) frames, advancing to next sentence")
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
        // Use a reasonable default threshold
        adaptiveSilenceThreshold = minimumThresholdDB
        currentAudioLevelDB = -80.0
        currentThresholdDB = minimumThresholdDB
        print("[SilenceDetection] Session reset, threshold: \(adaptiveSilenceThreshold) dB")
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
