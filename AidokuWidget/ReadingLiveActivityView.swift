//
//  ReadingLiveActivityView.swift
//  AidokuWidget
//

import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Cover image helper (loads from App Group shared file)

private struct CoverView: View {
    let url: String
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    /// Prefer the locally cached file (file://) so no network is needed.
    /// Falls back to the remote URL if the file doesn't exist yet.
    private var resolvedURL: URL? {
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.aidoku.Aidoku"
        ) {
            let fileURL = containerURL.appendingPathComponent("widget_cover.jpg")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }
        return URL(string: url)
    }

    var body: some View {
        AsyncImage(url: resolvedURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                Image(systemName: "book.closed.fill")
                    .font(.system(size: cornerRadius * 3))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Lock Screen / StandBy View

struct ReadingLockScreenLiveActivityView: View {
    let context: ActivityViewContext<ReadingActivityAttributes>

    private var progress: Double {
        guard context.state.totalPages > 0 else { return 0 }
        return Double(context.state.currentPage) / Double(context.state.totalPages)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Cover thumbnail — uses local file:// URL for reliable color rendering
            CoverView(url: context.attributes.coverURL, width: 52, height: 72, cornerRadius: 6)

            // Text + progress
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(context.attributes.mangaTitle)
                        .font(.headline)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    if context.state.totalPages > 0 {
                        Text("\(Int(progress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                if !context.state.chapterTitle.isEmpty {
                    Text(context.state.chapterTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if context.state.totalPages > 0 {
                    ProgressView(value: progress)
                        .tint(.accentColor)
                    Text("Página \(context.state.currentPage) de \(context.state.totalPages)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Carregando capítulo…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .widgetURL(URL(string: context.attributes.deepLinkURL))
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Widget Configuration (Live Activity)

struct ReadingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingActivityAttributes.self) { context in
            ReadingLockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view – shown when the user presses the Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        CoverView(url: context.attributes.coverURL, width: 28, height: 38, cornerRadius: 4)

                        Text(context.attributes.mangaTitle)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.totalPages > 0 {
                        Text("\(context.state.currentPage)/\(context.state.totalPages)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        if !context.state.chapterTitle.isEmpty {
                            Text(context.state.chapterTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if context.state.totalPages > 0 {
                            ProgressView(
                                value: Double(context.state.currentPage),
                                total: Double(context.state.totalPages)
                            )
                            .tint(.accentColor)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "book.fill")
            } compactTrailing: {
                if context.state.totalPages > 0 {
                    Text("\(context.state.currentPage)/\(context.state.totalPages)")
                        .font(.caption2.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Image(systemName: "ellipsis")
                        .font(.caption2)
                }
            } minimal: {
                Image(systemName: "book.fill")
            }
            .widgetURL(URL(string: context.attributes.deepLinkURL))
        }
    }
}

// MARK: - Preview

#Preview("Lock Screen", as: .content, using: ReadingActivityAttributes(
    mangaTitle: "One Piece",
    deepLinkURL: "aidoku://op/1",
    coverURL: "https://uploads.mangadex.org/covers/a1c7c817-4e59-43b7-9365-09675a149a6f/f6d5ad27-5985-4b74-8fbe-4dc2ab8fa8d5.jpg"
)) {
    ReadingLiveActivity()
} contentStates: {
    ReadingActivityAttributes.ContentState(currentPage: 45, totalPages: 120, chapterTitle: "Capítulo 1234")
    ReadingActivityAttributes.ContentState(currentPage: 0, totalPages: 0, chapterTitle: "Capítulo 1235")
}
