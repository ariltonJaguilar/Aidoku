//
//  LibraryCategorySelectionHeader.swift
//  Aidoku
//
//  Created by Skitty on 2/25/26.
//  SwiftUI glass-effect rewrite — matches ListingsHeaderView pattern exactly.
//  Public interface is unchanged for upstream merge compatibility.
//

import UIKit
import SwiftUI

// MARK: - Protocol (unchanged)

protocol LibraryCategorySelectionHeaderDelegate: AnyObject {
    func optionSelected(_ indexPath: IndexPath)
}

// MARK: - SwiftUI State

private final class CategoryTabsModel: ObservableObject {
    @Published var sections: [LibraryCategorySelectionHeader.Section] = []
    @Published var selectedIndexPath: IndexPath = IndexPath(row: 0, section: 0)
    @Published var lockedOptions: [IndexPath] = []
    @Published var scrollTo: IndexPath?
    var onSelect: ((IndexPath) -> Void)?
}

// MARK: - SwiftUI View (follows ListingsHeaderView.headerScrollView pattern exactly)

private struct CategoryTabsContent: View {
    @ObservedObject var model: CategoryTabsModel

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { proxy in
                    HStack(spacing: 6) {
                        ForEach(model.sections.indices, id: \.self) { sIdx in
                            let section = model.sections[sIdx]
                            ForEach(section.options.indices, id: \.self) { rIdx in
                                let ip = IndexPath(row: rIdx, section: sIdx)
                                let active = model.selectedIndexPath == ip
                                let locked = model.lockedOptions.contains(ip)

                                Button {
                                    guard model.selectedIndexPath != ip else { return }
                                    model.selectedIndexPath = ip
                                    model.onSelect?(ip)
                                } label: {
                                    let label = HStack(spacing: 3) {
                                        Text(section.options[rIdx])
                                        if locked {
                                            Image(systemName: "lock.fill")
                                                .font(.caption2)
                                        }
                                    }
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 8)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(active ? Color.white : Color.primary)

                                    if #available(iOS 26.0, *) {
                                        label
                                            .glassEffect(active ? .regular.tint(.accentColor) : .regular)
                                    } else {
                                        label
                                            .background(
                                                RoundedRectangle(cornerRadius: 100)
                                                    .fill(Color(uiColor: active ? .tintColor : .secondarySystemFill))
                                            )
                                    }
                                }
                                .id(ip)
                            }
                        }
                    }
                    // ensure the HStack is at least as wide as the available space
                    .frame(minWidth: geo.size.width, alignment: .center)
                    .padding(.horizontal)
                    .onChange(of: model.scrollTo) { ip in
                        guard let ip else { return }
                        withAnimation { proxy.scrollTo(ip, anchor: .center) }
                    }
                }
            }
        }
    }
}

// MARK: - UICollectionReusableView (public interface unchanged)

class LibraryCategorySelectionHeader: UICollectionReusableView {
    weak var delegate: LibraryCategorySelectionHeaderDelegate?

    struct Section {
        var title: String?
        var options: [String] = []
    }

    var options: [Section] = [] {
        didSet { model.sections = options }
    }
    var lockedOptions: [IndexPath] = [] {
        didSet { model.lockedOptions = lockedOptions }
    }

    private let model = CategoryTabsModel()
    // Retained strongly to prevent deallocation — same pattern as UIHostingCollectionViewCell
    private var hostingController: UIHostingController<CategoryTabsContent>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        model.onSelect = { [weak self] ip in
            self?.delegate?.optionSelected(ip)
        }

        let host = UIHostingController(rootView: CategoryTabsContent(model: model))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.view.topAnchor.constraint(equalTo: topAnchor),
            host.view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        hostingController = host
    }

    // MARK: - Public API (unchanged from original)

    func setSelectedOption(_ indexPath: IndexPath) {
        guard model.selectedIndexPath != indexPath else { return }
        model.selectedIndexPath = indexPath
        model.scrollTo = indexPath
    }
}
