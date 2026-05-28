//
//  AidokuWidget.swift
//  AidokuWidget
//

import WidgetKit
import SwiftUI

private let appGroupIdentifier = "group.app.aidoku.Aidoku"

// MARK: - Timeline Entry

struct LastReadEntry: TimelineEntry {
    let date: Date
    let title: String
    let coverImage: UIImage?
    let deepLinkURL: URL?
}

// MARK: - Timeline Provider

struct LastReadProvider: TimelineProvider {

    func placeholder(in context: Context) -> LastReadEntry {
        LastReadEntry(date: Date(), title: "Manga Title", coverImage: nil, deepLinkURL: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (LastReadEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LastReadEntry>) -> Void) {
        let entry = loadEntry()
        // No automatic refresh — the app triggers a reload when the user reads
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }

    private func loadEntry() -> LastReadEntry {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        let title = defaults?.string(forKey: "Widget.mangaTitle") ?? ""
        let sourceId = defaults?.string(forKey: "Widget.sourceId") ?? ""
        let mangaId = defaults?.string(forKey: "Widget.mangaId") ?? ""

        // Build deep link: aidoku://{sourceId}/{encodedMangaId}
        let deepLinkURL: URL?
        if !sourceId.isEmpty, !mangaId.isEmpty,
           let encodedMangaId = mangaId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
            deepLinkURL = URL(string: "aidoku://\(sourceId)/\(encodedMangaId)")
        } else {
            deepLinkURL = URL(string: "aidoku://")
        }

        var coverImage: UIImage?
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {
            let coverFileURL = containerURL.appendingPathComponent("widget_cover.jpg")
            if let data = try? Data(contentsOf: coverFileURL) {
                coverImage = UIImage(data: data)
            }
        }

        return LastReadEntry(date: Date(), title: title, coverImage: coverImage, deepLinkURL: deepLinkURL)
    }
}

// MARK: - Widget View

struct LastReadWidgetView: View {
    var entry: LastReadProvider.Entry

    var body: some View {
        Color.clear // transparent so containerBackground shows through
            .widgetURL(entry.deepLinkURL)
            .containerBackground(for: .widget) {
                if let image = entry.coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(.systemGray5)
                        .overlay {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                        }
                }
            }
    }
}

// MARK: - Widget Configuration

struct AidokuWidget: Widget {
    let kind: String = "AidokuLastReadWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LastReadProvider()) { entry in
            LastReadWidgetView(entry: entry)
        }
        .configurationDisplayName("Último Manga Lido")
        .description("Mostra a capa do último manga que você leu. Toque para abrir os detalhes no Aidoku.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    AidokuWidget()
} timeline: {
    LastReadEntry(date: .now, title: "One Piece", coverImage: nil, deepLinkURL: nil)
}
