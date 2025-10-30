//
//  AudioRecordingService.swift
//  WalkingTalking
//
//  Created by KEISUKE YANAGISAWA on 2025/10/30.
//

import AVFoundation
import Foundation

protocol AudioRecordingServiceDelegate: AnyObject {
    func didReceiveAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime)
    func recordingDidFail(error: Error)
}

enum AudioRecordingError: Error {
    case permissionDenied
    case audioEngineNotRunning
    case inputNodeUnavailable
}

class AudioRecordingService {
    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    weak var delegate: AudioRecordingServiceDelegate?

    private(set) var isRecording = false

    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func startRecording() throws {
        guard !isRecording else { return }

        // Get input node
        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else {
            throw AudioRecordingError.inputNodeUnavailable
        }

        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Install tap on input node to receive audio buffers
        inputNode.installTap(
            onBus: 0,
            bufferSize: AudioConstants.audioBufferSize,
            format: inputFormat
        ) { [weak self] buffer, time in
            self?.delegate?.didReceiveAudioBuffer(buffer, time: time)
        }

        // Prepare and start the audio engine
        audioEngine.prepare()

        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            inputNode.removeTap(onBus: 0)
            throw error
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        // Remove tap and stop engine
        inputNode?.removeTap(onBus: 0)
        audioEngine.stop()

        isRecording = false
    }

    func cleanup() {
        if isRecording {
            stopRecording()
        }
    }

    deinit {
        cleanup()
    }
}
