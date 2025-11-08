//
//  MicLevelBar.swift
//  WalkingTalking
//
//  Created by KEISUKE YANAGISAWA on 2025/11/08.
//
//  Simple mic level indicator bar showing current level and mute detection threshold
//

import SwiftUI

struct MicLevelBar: View {
    let currentLevelDB: Float
    let thresholdDB: Float
    let isRecording: Bool

    // Visual range: -80 dB (silence) to -20 dB (loud)
    private let minDB: Float = -80.0
    private let maxDB: Float = -20.0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.gray.opacity(0.2))

                // Current level bar
                if isRecording {
                    Rectangle()
                        .fill(levelColor)
                        .frame(width: levelWidth(in: geometry.size.width))

                    // Threshold marker (vertical line)
                    Rectangle()
                        .fill(Color.red.opacity(0.7))
                        .frame(width: 2)
                        .offset(x: thresholdPosition(in: geometry.size.width))
                }
            }
        }
        .frame(height: 4)
    }

    private func normalizedValue(for dB: Float) -> Float {
        let normalized = (dB - minDB) / (maxDB - minDB)
        return max(0, min(1, normalized))
    }

    private func levelWidth(in width: CGFloat) -> CGFloat {
        let normalized = normalizedValue(for: currentLevelDB)
        return CGFloat(normalized) * width
    }

    private func thresholdPosition(in width: CGFloat) -> CGFloat {
        let normalized = normalizedValue(for: thresholdDB)
        return CGFloat(normalized) * width
    }

    private var levelColor: Color {
        if currentLevelDB > thresholdDB {
            return .green
        } else {
            return .yellow.opacity(0.6)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Low level (below threshold)
        MicLevelBar(
            currentLevelDB: -55,
            thresholdDB: -40,
            isRecording: true
        )

        // High level (above threshold - voice detected)
        MicLevelBar(
            currentLevelDB: -30,
            thresholdDB: -40,
            isRecording: true
        )

        // Not recording
        MicLevelBar(
            currentLevelDB: -70,
            thresholdDB: -40,
            isRecording: false
        )
    }
    .padding()
}
