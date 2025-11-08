//
//  Channel.swift
//  WalkingTalking
//
//  Created by Claude Code on 2025/11/01.
//

import Foundation
import SwiftData

@Model
final class Channel {
    var id: UUID
    var name: String
    var channelDescription: String
    var iconName: String

    @Relationship(deleteRule: .cascade)
    var lessons: [Lesson]

    init(id: UUID = UUID(), name: String, description: String, iconName: String = "globe") {
        self.id = id
        self.name = name
        self.channelDescription = description
        self.iconName = iconName
        self.lessons = []
    }

    // Static hardcoded channel for Euro News
    static var euroNews: Channel {
        Channel(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Euro News",
            description: "Daily English learning content from Euronews",
            iconName: "globe.europe.africa.fill"
        )
    }
}
