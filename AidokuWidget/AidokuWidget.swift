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
        Task { completion(await loadEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LastReadEntry>) -> Void) {
        Task {
            let entry = await loadEntry()
            // No automatic refresh — the app triggers a reload when the user reads
            let timeline = Timeline(entries: [entry], policy: .never)
            completion(timeline)
        }
    }

    private func loadEntry() async -> LastReadEntry {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        let title = defaults?.string(forKey: "Widget.mangaTitle") ?? ""
        let sourceId = defaults?.string(forKey: "Widget.sourceId") ?? ""
        let mangaId = defaults?.string(forKey: "Widget.mangaId") ?? ""
        let coverUrlString = defaults?.string(forKey: "Widget.coverUrl") ?? ""

        // Build deep link: aidoku://{sourceId}/{encodedMangaId}
        // Use a character set that encodes '/' so that manga keys containing
        // slashes (e.g. "/series/abc/title" for sources like weebcentral) are
        // treated as a single opaque path component, avoiding double-slash
        // ambiguity and incorrect path splitting in handleUrl.
        let deepLinkURL: URL?
        if !sourceId.isEmpty, !mangaId.isEmpty {
            var pathComponentChars = CharacterSet.urlPathAllowed
            pathComponentChars.remove(charactersIn: "/")
            let encodedMangaId = mangaId.addingPercentEncoding(withAllowedCharacters: pathComponentChars) ?? mangaId
            deepLinkURL = URL(string: "aidoku://\(sourceId)/\(encodedMangaId)")
        } else {
            deepLinkURL = URL(string: "aidoku://")
        }

        // 1. Try to load the cover from the App Group shared file (fastest path)
        var coverImage: UIImage?
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {
            let coverFileURL = containerURL.appendingPathComponent("widget_cover.jpg")
            if let data = try? Data(contentsOf: coverFileURL) {
                coverImage = UIImage(data: data)
            }
        }

        // 2. Fallback: download directly from the URL stored in UserDefaults.
        //    This handles sideloaded builds where the App Group container is
        //    inaccessible but shared UserDefaults still works.
        if coverImage == nil, !coverUrlString.isEmpty, let coverUrl = URL(string: coverUrlString) {
            if let (data, _) = try? await URLSession.shared.data(from: coverUrl) {
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    AidokuWidget()
} timeline: {
    LastReadEntry(date: .now, title: "One Piece", coverImage: nil, deepLinkURL: nil)
}

#Preview(as: .systemExtraLarge) {
    AidokuWidget()
} timeline: {
    LastReadEntry(date: .now, title: "One Piece", coverImage: nil, deepLinkURL: nil)
}
