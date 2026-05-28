//
//  LiveActivityManager.swift
//  Aidoku (iOS)
//
//  Manages the "Now Reading" Live Activity shown on the lock screen
//  and Dynamic Island while the user is reading a manga chapter.
//
//  NOTE: ReadingActivityAttributes is intentionally mirrored here and in
//  AidokuWidget/ReadingActivityAttributes.swift so both the app target and
//  the widget extension share the same type name — ActivityKit uses the
//  type name to link the two sides of a Live Activity.
//

import ActivityKit
import Foundation

// MARK: - Activity Attributes (mirrors AidokuWidget/ReadingActivityAttributes.swift)

struct ReadingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var currentPage: Int
        var totalPages: Int
        var chapterTitle: String
    }
    var mangaTitle: String
    var deepLinkURL: String
    var coverURL: String
}

// MARK: - Manager

@available(iOS 16.2, *)
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var currentActivity: Activity<ReadingActivityAttributes>?
    private init() {}

    /// Starts a new Live Activity for the given manga/chapter, ending any previous one first.
    func startReading(
        mangaTitle: String,
        coverURL: String,
        deepLinkURL: String,
        chapterTitle: String,
        currentPage: Int,
        totalPages: Int
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Silently end any existing activity before starting a new one
        if let existing = currentActivity {
            let old = existing
            currentActivity = nil
            Task { await old.end(nil, dismissalPolicy: .immediate) }
        }

        let attributes = ReadingActivityAttributes(
            mangaTitle: mangaTitle,
            deepLinkURL: deepLinkURL,
            coverURL: coverURL
        )
        let state = ReadingActivityAttributes.ContentState(
            currentPage: max(1, currentPage),
            totalPages: max(0, totalPages),
            chapterTitle: chapterTitle
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            // Live Activities unavailable (limit reached, feature off, simulator, etc.)
        }
    }

    /// Updates the current page progress and/or chapter title.
    func update(currentPage: Int, totalPages: Int, chapterTitle: String) {
        guard let activity = currentActivity else { return }
        let state = ReadingActivityAttributes.ContentState(
            currentPage: max(1, currentPage),
            totalPages: max(0, totalPages),
            chapterTitle: chapterTitle
        )
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    /// Ends the Live Activity, keeping it visible on the lock screen for ~3 seconds.
    func end() {
        guard let activity = currentActivity else { return }
        currentActivity = nil
        Task {
            await activity.end(nil, dismissalPolicy: .after(.now + 3))
        }
    }
}
