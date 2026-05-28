//
//  ReadingActivityAttributes.swift
//  AidokuWidget
//

import ActivityKit
import Foundation

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
