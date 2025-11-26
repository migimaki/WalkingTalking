//
//  ViewModeToggleButton.swift
//  WalkingTalking
//
//  View mode toggle button for player view
//

import SwiftUI

struct ViewModeToggleButton: View {
    let viewMode: PlayerViewModel.ViewMode
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 4) {
                Text(icon)
                    .font(.system(size: 24))
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 60, height: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var icon: String {
        switch viewMode {
        case .original:
            return "📝"
        case .translation:
            return "🌐"
        case .shadowing:
            return "👤"
        }
    }

    private var label: String {
        switch viewMode {
        case .original:
            return "Original"
        case .translation:
            return "Translation"
        case .shadowing:
            return "Shadow"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ViewModeToggleButton(viewMode: .original) {}
        ViewModeToggleButton(viewMode: .translation) {}
        ViewModeToggleButton(viewMode: .shadowing) {}
    }
    .padding()
}
