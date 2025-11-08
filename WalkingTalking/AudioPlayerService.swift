//
//  AudioPlayerService.swift
//  WalkingTalking
//
//  Created by Claude Code on 2025/11/01.
//

import Foundation
import AVFoundation

protocol AudioPlayerServiceDelegate: AnyObject {
    func audioDidStart()
    func audioDidFinish()
    func audioDidFail(error: Error)
}

/// Service for playing audio files from Supabase Storage
class AudioPlayerService: NSObject {
    weak var delegate: AudioPlayerServiceDelegate?

    private var audioPlayer: AVAudioPlayer?
    private(set) var isPlaying: Bool = false

    /// Play audio from a local file URL
    func play(from localURL: URL) throws {
        // Stop any current playback
        stop()

        // Create audio player
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: localURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()

            // Start playback
            guard audioPlayer?.play() == true else {
                throw AudioPlayerError.playbackFailed
            }

            isPlaying = true
            delegate?.audioDidStart()
            print("🔊 Playing audio: \(localURL.lastPathComponent)")

        } catch {
            throw AudioPlayerError.initializationFailed(error.localizedDescription)
        }
    }

    /// Stop current playback
    func stop() {
        if let player = audioPlayer, player.isPlaying {
            player.stop()
            isPlaying = false
        }
        audioPlayer = nil
    }

    /// Pause current playback
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }

    /// Resume playback
    func resume() {
        audioPlayer?.play()
        isPlaying = true
    }

    /// Get current playback time
    var currentTime: TimeInterval {
        audioPlayer?.currentTime ?? 0
    }

    /// Get total duration
    var duration: TimeInterval {
        audioPlayer?.duration ?? 0
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false

        if flag {
            print("✅ Audio finished playing")
            delegate?.audioDidFinish()
        } else {
            print("❌ Audio playback interrupted")
            delegate?.audioDidFail(error: AudioPlayerError.playbackInterrupted)
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        isPlaying = false
        let error = error ?? AudioPlayerError.decodingError
        print("❌ Audio decode error: \(error.localizedDescription)")
        delegate?.audioDidFail(error: error)
    }

    func audioPlayerBeginInterruption(_ player: AVAudioPlayer) {
        print("[AudioPlayerService] ⚠️ Audio playback interrupted (begin)")
        isPlaying = false
    }

    func audioPlayerEndInterruption(_ player: AVAudioPlayer, withOptions flags: Int) {
        print("[AudioPlayerService] 🔄 Audio interruption ended, flags: \(flags)")
        // Flags: 1 = should resume
        if flags == 1 {
            print("[AudioPlayerService] Resuming playback after interruption")
            player.play()
            isPlaying = true
        }
    }
}

// MARK: - Errors

enum AudioPlayerError: Error, LocalizedError {
    case initializationFailed(String)
    case playbackFailed
    case playbackInterrupted
    case decodingError

    var errorDescription: String? {
        switch self {
        case .initializationFailed(let reason):
            return "Failed to initialize audio player: \(reason)"
        case .playbackFailed:
            return "Failed to start playback"
        case .playbackInterrupted:
            return "Playback was interrupted"
        case .decodingError:
            return "Failed to decode audio file"
        }
    }
}
