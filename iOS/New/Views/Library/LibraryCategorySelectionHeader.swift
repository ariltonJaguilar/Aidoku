//
//  LibraryCategorySelectionHeader.swift
//  Aidoku
//
//  Created by Skitty on 2/25/26.
//  Tabs rewrite: scrollable pill-style tabs replacing the dropdown menu.
//  Public interface is unchanged for upstream merge compatibility.
//

import UIKit

// based on MangaListSelectionHeaderDelegate

protocol LibraryCategorySelectionHeaderDelegate: AnyObject {
    func optionSelected(_ indexPath: IndexPath)
}

class LibraryCategorySelectionHeader: UICollectionReusableView {
    weak var delegate: LibraryCategorySelectionHeaderDelegate?

    struct Section {
        var title: String?
        var options: [String] = []
    }

    var options: [Section] = [] {
        didSet { buildTabs() }
    }
    var lockedOptions: [IndexPath] = [] {
        didSet { refreshTabAppearance() }
    }

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceHorizontal = false
        sv.clipsToBounds = false
        return sv
    }()

    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 8
        sv.alignment = .center
        return sv
    }()

    private var tabEntries: [(button: UIButton, indexPath: IndexPath)] = []
    private var selectedIndexPath = IndexPath(row: 0, section: 0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setup() {
        addSubview(scrollView)
        scrollView.addSubview(stackView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // allow centering when content is smaller than the view, but keep
            // flexible leading/trailing so the stack can grow and enable scrolling
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            // center horizontally within the frame when possible
            stackView.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 4),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -4),
            stackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor, constant: -8)
        ])
    }

    // MARK: - Tab Building

    private func buildTabs() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        tabEntries = []

        for (sectionIdx, section) in options.enumerated() {
            for (rowIdx, title) in section.options.enumerated() {
                let indexPath = IndexPath(row: rowIdx, section: sectionIdx)
                let button = makeTabButton(title: title, indexPath: indexPath)
                stackView.addArrangedSubview(button)
                tabEntries.append((button: button, indexPath: indexPath))
            }
        }

        refreshTabAppearance()
    }

    private func makeTabButton(title: String, indexPath: IndexPath) -> UIButton {
        let button = UIButton(configuration: tabConfiguration(selected: false, locked: false, title: title))
        let ip = indexPath
        button.addAction(UIAction { [weak self] _ in
            guard let self, self.selectedIndexPath != ip else { return }
            self.selectedIndexPath = ip
            self.refreshTabAppearance()
            self.scrollToTab(at: ip, animated: true)
            self.delegate?.optionSelected(ip)
        }, for: .touchUpInside)
        return button
    }

    private func tabConfiguration(selected: Bool, locked: Bool, title: String) -> UIButton.Configuration {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 14)

        if selected {
            config.baseBackgroundColor = tintColor
            config.baseForegroundColor = .white
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
                var a = attrs
                a.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
                return a
            }
        } else {
            config.baseBackgroundColor = UIColor.secondarySystemFill
            config.baseForegroundColor = .label
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
                var a = attrs
                a.font = UIFont.systemFont(ofSize: 14, weight: .regular)
                return a
            }
        }

        if locked {
            config.image = UIImage(
                systemName: "lock.fill",
                withConfiguration: UIImage.SymbolConfiguration(scale: .small)
            )
            config.imagePadding = 4
            config.imagePlacement = .trailing
        }

        return config
    }

    // MARK: - Appearance

    private func refreshTabAppearance() {
        for (button, indexPath) in tabEntries {
            let isSelected = indexPath == selectedIndexPath
            let isLocked = lockedOptions.contains(indexPath)
            let title = button.configuration?.title ?? button.title(for: .normal) ?? ""
            button.configuration = tabConfiguration(selected: isSelected, locked: isLocked, title: title)
        }
    }

    // MARK: - Public API (unchanged from original)

    func setSelectedOption(_ indexPath: IndexPath) {
        guard selectedIndexPath != indexPath else { return }
        selectedIndexPath = indexPath
        refreshTabAppearance()
        scrollToTab(at: indexPath, animated: false)
    }

    // MARK: - Scroll helpers

    private func scrollToTab(at indexPath: IndexPath, animated: Bool) {
        guard let entry = tabEntries.first(where: { $0.indexPath == indexPath }) else { return }
        let frame = stackView.convert(entry.button.frame, to: scrollView)
        scrollView.scrollRectToVisible(frame.insetBy(dx: -16, dy: 0), animated: animated)
    }
}
