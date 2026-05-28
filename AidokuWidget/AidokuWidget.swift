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

// MARK: - Lock Screen Widget View (Continuar Lendo)

struct LockScreenWidgetView: View {
    var entry: LastReadProvider.Entry

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "book.fill")
                .font(.system(size: 22, weight: .semibold))
                .widgetAccentable()

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title.isEmpty ? "Aidoku" : entry.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("Continuar lendo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .widgetURL(entry.deepLinkURL)
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Lock Screen Widget Configuration (Continuar Lendo)

struct AidokuLockScreenWidget: Widget {
    let kind: String = "AidokuLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LastReadProvider()) { entry in
            LockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("Continuar Lendo")
        .description("Abre o último manga lido direto da tela de bloqueio.")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - App Launch Provider

struct AppLaunchEntry: TimelineEntry {
    let date: Date = .init()
}

struct AppLaunchProvider: TimelineProvider {
    func placeholder(in context: Context) -> AppLaunchEntry { AppLaunchEntry() }
    func getSnapshot(in context: Context, completion: @escaping (AppLaunchEntry) -> Void) {
        completion(AppLaunchEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<AppLaunchEntry>) -> Void) {
        completion(Timeline(entries: [AppLaunchEntry()], policy: .never))
    }
}

// MARK: - App Launch Widget View

struct AppLaunchWidgetView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 22, weight: .semibold))
                .widgetAccentable()

            VStack(alignment: .leading, spacing: 2) {
                Text("Aidoku")
                    .font(.headline)
                Text("Abrir app")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .widgetURL(URL(string: "aidoku://"))
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - App Launch Widget Configuration

struct AidokuAppLaunchWidget: Widget {
    let kind: String = "AidokuAppLaunchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AppLaunchProvider()) { _ in
            AppLaunchWidgetView()
        }
        .configurationDisplayName("Abrir Aidoku")
        .description("Abre o Aidoku direto da tela de bloqueio.")
        .supportedFamilies([.accessoryRectangular])
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

#Preview(as: .accessoryRectangular) {
    AidokuLockScreenWidget()
} timeline: {
    LastReadEntry(date: .now, title: "One Piece", coverImage: nil, deepLinkURL: nil)
}

#Preview(as: .accessoryRectangular) {
    AidokuAppLaunchWidget()
} timeline: {
    AppLaunchEntry()
}
