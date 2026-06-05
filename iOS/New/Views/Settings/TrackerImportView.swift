//
//  TrackerImportView.swift
//  Aidoku
//

import AidokuRunner
import NukeUI
import SwiftUI

// MARK: - Data Models

fileprivate struct TrackerImportItem: Identifiable {
    let id = UUID()
    let trackerId: String
    let trackerName: String
    let trackerIcon: UIImage?
    let item: TrackSearchItem
}

fileprivate struct TrackerImportResult: Identifiable {
    let id = UUID()
    let source: TrackerImportItem

    enum State {
        case searching
        case found(AidokuRunner.Manga)
        case notFound
    }

    var state: State = .searching
}

// MARK: - Main View

struct TrackerImportView: View {

    // MARK: Loading phase

    fileprivate enum LoadingState {
        case loading
        case ready([TrackerImportItem])
        case error(String)
    }

    @State private var loadingState: LoadingState = .loading
    @State private var selectedIds: Set<UUID> = []
    @State private var showSourcePicker = false

    // MARK: Results phase

    @State private var showResults = false
    @State private var selectedSources: [AidokuRunner.Source] = []
    @State private var results: [TrackerImportResult] = []

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch loadingState {
                case .loading:
                    loadingView
                case .ready(let items):
                    if items.isEmpty {
                        emptyView
                    } else {
                        mangaListView(items: items)
                    }
                case .error(let message):
                    ContentUnavailableView(
                        "Erro",
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                }
            }
            .navigationTitle("Importar da Lista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showResults) {
                if !results.isEmpty {
                    TrackerImportResultsView(
                        results: $results,
                        sources: selectedSources,
                        onComplete: { dismiss() }
                    )
                }
            }
            .sheet(isPresented: $showSourcePicker) {
                TrackerImportSourcePickerView(selectedSources: $selectedSources) {
                    startSearch()
                    showSourcePicker = false
                    showResults = true
                }
            }
        }
        .task {
            await loadTrackerItems()
        }
    }

    // MARK: Sub-views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Buscando mangas nos rastreadores…")
                .foregroundStyle(.secondary)
        }
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "Tudo em dia!",
            systemImage: "checkmark.circle",
            description: Text("Todos os mangas dos seus rastreadores já estão na sua biblioteca.")
        )
    }

    @ViewBuilder
    private func mangaListView(items: [TrackerImportItem]) -> some View {
        List {
            let grouped = Dictionary(grouping: items, by: \.trackerId)
            let trackerOrder = TrackerManager.trackers
                .filter { !($0 is EnhancedTracker) }
                .map(\.id)

            ForEach(trackerOrder, id: \.self) { trackerId in
                if let group = grouped[trackerId], !group.isEmpty {
                    Section(group[0].trackerName) {
                        ForEach(group) { importItem in
                            TrackerImportItemRow(
                                item: importItem,
                                isSelected: selectedIds.contains(importItem.id)
                            ) {
                                if selectedIds.contains(importItem.id) {
                                    selectedIds.remove(importItem.id)
                                } else {
                                    selectedIds.insert(importItem.id)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            bottomBar(items: items)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(selectedIds.count == items.count ? "Desmarcar Todos" : "Selecionar Todos") {
                    if selectedIds.count == items.count {
                        selectedIds.removeAll()
                    } else {
                        selectedIds = Set(items.map(\.id))
                    }
                }
            }
        }
        .onAppear {
            // pre-select all
            if selectedIds.isEmpty {
                selectedIds = Set(items.map(\.id))
            }
        }
    }

    @ViewBuilder
    private func bottomBar(items: [TrackerImportItem]) -> some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                showSourcePicker = true
            } label: {
                Text("Continuar (\(selectedIds.count) selecionado\(selectedIds.count == 1 ? "" : "s"))")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
            }
            .disabled(selectedIds.isEmpty)
        }
        .background(.bar)
    }

    // MARK: Actions

    private func loadTrackerItems() async {
        let activeTrackers = TrackerManager.trackers.filter {
            !($0 is EnhancedTracker) && $0.isLoggedIn
        }

        guard !activeTrackers.isEmpty else {
            loadingState = .ready([])
            return
        }

        // Collect all tracked manga ids already in the library
        let libraryMangaTitles: Set<String> = await CoreDataManager.shared.container.performBackgroundTask { context in
            let libraryObjects = CoreDataManager.shared.getLibraryManga(context: context)
            var titles = Set<String>()
            for obj in libraryObjects {
                if let title = obj.manga?.title.lowercased() {
                    titles.insert(title)
                }
            }
            return titles
        }

        // Fetch from each tracker concurrently
        var items: [TrackerImportItem] = []

        await withTaskGroup(of: [TrackerImportItem].self) { group in
            for tracker in activeTrackers {
                group.addTask {
                    guard let list = try? await tracker.getUserList() else { return [] }
                    return list.compactMap { searchItem in
                        guard let title = searchItem.title, !title.isEmpty else { return nil }
                        // Skip if already in library (fuzzy title match)
                        if libraryMangaTitles.contains(title.lowercased()) { return nil }
                        return TrackerImportItem(
                            trackerId: tracker.id,
                            trackerName: tracker.name,
                            trackerIcon: tracker.icon,
                            item: searchItem
                        )
                    }
                }
            }
            for await trackerItems in group {
                items.append(contentsOf: trackerItems)
            }
        }

        // Deduplicate by title (case-insensitive)
        var seen = Set<String>()
        items = items.filter { importItem in
            let key = (importItem.item.title ?? "").lowercased()
            return seen.insert(key).inserted
        }

        // Sort alphabetically
        items.sort { ($0.item.title ?? "") < ($1.item.title ?? "") }

        loadingState = .ready(items)
    }

    private func startSearch() {
        guard case .ready(let allItems) = loadingState else { return }
        let selected = allItems.filter { selectedIds.contains($0.id) }
        results = selected.map { TrackerImportResult(source: $0) }

        Task {
            await withTaskGroup(of: (UUID, TrackerImportResult.State).self) { group in
                for result in results {
                    let importItem = result.source
                    let sources = selectedSources
                    group.addTask {
                        let title = importItem.item.title ?? ""
                        for source in sources {
                            if let search = try? await source.getSearchMangaList(query: title, page: 1, filters: []),
                               let manga = search.entries.first {
                                return (result.id, .found(manga))
                            }
                        }
                        return (result.id, .notFound)
                    }
                }
                for await (resultId, state) in group {
                    await MainActor.run {
                        if let idx = results.firstIndex(where: { $0.id == resultId }) {
                            results[idx].state = state
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Item Row

private struct TrackerImportItemRow: View {
    let item: TrackerImportItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Cover thumbnail
                LazyImage(url: item.item.coverUrl.flatMap({ URL(string: $0) })) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(.systemGray5)
                    }
                }
                .frame(width: 40, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.item.title ?? "Sem título")
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    HStack(spacing: 4) {
                        if let icon = item.trackerIcon {
                            Image(uiImage: icon)
                                .resizable()
                                .frame(width: 14, height: 14)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        Text(item.trackerName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color(.systemGray4))
                    .font(.title2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Source Picker

private struct TrackerImportSourcePickerView: View {
    @Binding var selectedSources: [AidokuRunner.Source]
    let onConfirm: () -> Void

    private let availableSources = SourceManager.shared.sources
        .filter { !$0.key.hasPrefix(KomgaSourceRunner.sourceKeyPrefix) && !$0.key.hasPrefix(KavitaSourceRunner.sourceKeyPrefix) }
    private let pinnedSources = SourceManager.shared.getPinned()
        .filter { !$0.key.hasPrefix(KomgaSourceRunner.sourceKeyPrefix) && !$0.key.hasPrefix(KavitaSourceRunner.sourceKeyPrefix) }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if !pinnedSources.isEmpty {
                    Button {
                        for source in pinnedSources where !selectedSources.contains(source) {
                            selectedSources.append(source)
                        }
                    } label: {
                        Text(NSLocalizedString("SELECT_PINNED_SOURCES"))
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                    .disabled(pinnedSources.allSatisfy { selectedSources.contains($0) })
                }

                if !selectedSources.isEmpty {
                    Section("Selecionadas") {
                        ForEach(selectedSources, id: \.key) { source in
                            HStack {
                                SourceIconView(sourceId: source.key, imageUrl: source.imageUrl, iconSize: 32)
                                Text(source.name)
                                Spacer()
                                Button {
                                    selectedSources.removeAll { $0.key == source.key }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section("Disponíveis") {
                    ForEach(availableSources, id: \.key) { source in
                        Button {
                            if !selectedSources.contains(source) {
                                selectedSources.append(source)
                            }
                        } label: {
                            HStack {
                                SourceIconView(sourceId: source.key, imageUrl: source.imageUrl, iconSize: 32)
                                Text(source.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedSources.contains(source) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Selecionar Fonte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Buscar") {
                        onConfirm()
                    }
                    .disabled(selectedSources.isEmpty)
                }
            }
        }
    }
}

extension AidokuRunner.Source: @retroactive Equatable {
    public static func == (lhs: AidokuRunner.Source, rhs: AidokuRunner.Source) -> Bool {
        lhs.key == rhs.key
    }
}

extension AidokuRunner.Source: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }
}

// MARK: - Results View

fileprivate struct TrackerImportResultsView: View {
    @Binding var results: [TrackerImportResult]
    let sources: [AidokuRunner.Source]
    let onComplete: () -> Void

    @State private var isAdding = false
    @State private var addedCount = 0

    @EnvironmentObject private var path: NavigationCoordinator

    private var foundCount: Int {
        results.filter { if case .found = $0.state { true } else { false } }.count
    }

    private var searchingCount: Int {
        results.filter { if case .searching = $0.state { true } else { false } }.count
    }

    var body: some View {
        List {
            ForEach($results) { $result in
                TrackerImportResultRow(
                    result: $result,
                    sources: sources
                )
            }
        }
        .listStyle(.plain)
        .navigationTitle(searchingCount > 0
            ? "Buscando… (\(foundCount)/\(results.count))"
            : "\(foundCount) de \(results.count) encontrados"
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isAdding {
                    ProgressView()
                } else {
                    Button("Adicionar (\(foundCount))") {
                        Task { await addToLibrary() }
                    }
                    .disabled(foundCount == 0 || searchingCount > 0)
                }
            }
        }
    }

    private func addToLibrary() async {
        isAdding = true
        for result in results {
            guard case .found(let manga) = result.state else { continue }
            await MangaManager.shared.addToLibrary(manga: manga)
        }
        isAdding = false
        await MainActor.run {
            onComplete()
        }
    }
}

// MARK: - Result Row

private struct TrackerImportResultRow: View {
    @Binding var result: TrackerImportResult
    let sources: [AidokuRunner.Source]

    @EnvironmentObject private var path: NavigationCoordinator

    private let coverHeight: CGFloat = 80

    var body: some View {
        HStack(spacing: 12) {
            // Tracker cover (left side)
            LazyImage(url: result.source.item.coverUrl.flatMap({ URL(string: $0) })) { state in
                if let img = state.image {
                    img.resizable().scaledToFill()
                } else {
                    Color(.systemGray5)
                }
            }
            .frame(width: coverHeight * 2 / 3, height: coverHeight)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
                .font(.caption)

            // Source result (right side)
            Group {
                switch result.state {
                case .searching:
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                        ProgressView()
                    }
                    .frame(width: coverHeight * 2 / 3, height: coverHeight)

                case .found(let manga):
                    Button {
                        path.push(MangaViewController(manga: manga, parent: path.rootViewController))
                    } label: {
                        MangaGridItem(
                            source: SourceManager.shared.source(for: manga.sourceKey),
                            title: manga.title,
                            coverImage: manga.cover ?? ""
                        )
                        .aspectRatio(2/3, contentMode: .fit)
                        .frame(height: coverHeight)
                    }
                    .buttonStyle(.borderless)

                case .notFound:
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                        Image(systemName: "questionmark")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: coverHeight * 2 / 3, height: coverHeight)
                }
            }

            // Info column
            VStack(alignment: .leading, spacing: 4) {
                Text(result.source.item.title ?? "Sem título")
                    .font(.subheadline.bold())
                    .lineLimit(2)

                switch result.state {
                case .searching:
                    Text("Buscando…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .found(let manga):
                    let sourceName = SourceManager.shared.source(for: manga.sourceKey)?.name ?? manga.sourceKey
                    Text(sourceName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(manga.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                case .notFound:
                    Text("Não encontrado")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                // Manual search / change button
                Button {
                    path.push(MigrateSingleSearchView(
                        targetSources: sources,
                        selectedSeries: placeholderMangaFor(result.source),
                        resultSeries: Binding(
                            get: {
                                if case .found(let manga) = result.state { return manga }
                                return nil
                            },
                            set: { newManga in
                                if let newManga {
                                    result.state = .found(newManga)
                                } else {
                                    result.state = .notFound
                                }
                            }
                        )
                    ))
                } label: {
                    Text(result.state.isFound ? "Alterar" : "Buscar manualmente")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    private func placeholderMangaFor(_ importItem: TrackerImportItem) -> AidokuRunner.Manga {
        var manga = AidokuRunner.Manga(
            sourceKey: sources.first?.key ?? "",
            key: importItem.item.id,
            title: importItem.item.title ?? ""
        )
        manga.cover = importItem.item.coverUrl
        return manga
    }
}

private extension TrackerImportResult.State {
    var isFound: Bool {
        if case .found = self { return true }
        return false
    }
}
