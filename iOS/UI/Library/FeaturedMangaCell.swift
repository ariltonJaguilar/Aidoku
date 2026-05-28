//
//  FeaturedMangaCell.swift
//  Aidoku (iOS)
//
//  Created by Aidoku on 2024.
//

import Gifu
import Nuke
import UIKit

class FeaturedMangaCell: UICollectionViewCell {
    var sourceId: String?
    var mangaId: String?
    var onContinueReading: (() -> Void)?

    var title: String? {
        get { titleLabel.text }
        set { titleLabel.text = newValue ?? NSLocalizedString("UNTITLED") }
    }

    let imageView = GIFImageView()
    private let titleLabel = UILabel()
    private let overlayView = UIView()
    private let gradient = CAGradientLayer()
    private let continueButton = UIButton(type: .system)
    private let highlightView = UIView()

    private var url: String?
    private var imageTask: ImageTask?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
        constrain()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        contentView.clipsToBounds = true
        contentView.layer.cornerRadius = 5
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.quaternarySystemFill.cgColor

        imageView.image = UIImage(named: "MangaPlaceholder")
        imageView.contentMode = .scaleAspectFill
        contentView.addSubview(imageView)

        // Gradient overlay: darkened at top and bottom
        gradient.locations = [0, 0.25, 0.65, 1]
        gradient.colors = [
            UIColor(white: 0, alpha: 0.5).cgColor,
            UIColor(white: 0, alpha: 0.0).cgColor,
            UIColor(white: 0, alpha: 0.0).cgColor,
            UIColor(white: 0, alpha: 0.75).cgColor
        ]
        gradient.cornerRadius = contentView.layer.cornerRadius
        gradient.needsDisplayOnBoundsChange = true

        overlayView.layer.insertSublayer(gradient, at: 0)
        overlayView.layer.cornerRadius = contentView.layer.cornerRadius
        contentView.addSubview(overlayView)

        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        contentView.addSubview(titleLabel)

        // "Continue Reading" button
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.9)
        config.baseForegroundColor = .black
        config.cornerStyle = .capsule
        config.image = UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold))
        config.imagePadding = 6
        config.imagePlacement = .leading
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 16)
        config.title = NSLocalizedString("CONTINUE_READING")
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { container in
            var c = container
            c.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            return c
        }
        continueButton.configuration = config
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        contentView.addSubview(continueButton)

        highlightView.alpha = 0
        highlightView.backgroundColor = UIColor(white: 0, alpha: 0.5)
        highlightView.layer.cornerRadius = contentView.layer.cornerRadius
        contentView.addSubview(highlightView)
    }

    private func constrain() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        highlightView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            overlayView.topAnchor.constraint(equalTo: contentView.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            continueButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            continueButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),

            highlightView.topAnchor.constraint(equalTo: contentView.topAnchor),
            highlightView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            highlightView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            highlightView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = contentView.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = UIImage(named: "MangaPlaceholder")
        imageTask?.cancel()
        imageTask = nil
        highlightView.alpha = 0
        onContinueReading = nil
        sourceId = nil
        mangaId = nil
    }

    @objc private func continueButtonTapped() {
        onContinueReading?()
    }

    func highlight() {
        highlightView.alpha = 1
    }

    func unhighlight(animated: Bool = true) {
        UIView.animate(withDuration: animated ? 0.3 : 0) {
            self.highlightView.alpha = 0
        }
    }
}

extension FeaturedMangaCell {
    func loadImage(url: URL?) async {
        guard let url else { return }

        if let imageTask, imageTask.state == .running {
            return
        }

        imageView.stopAnimatingGIF()

        var urlRequest = URLRequest(url: url)
        var cached = ImagePipeline.shared.cache.containsCachedImage(for: .init(urlRequest: urlRequest))

        if !cached {
            if let fileUrl = url.toAidokuFileUrl() {
                urlRequest = URLRequest(url: fileUrl)
            } else if let sourceId {
                await SourceManager.shared.waitForSourcesLoad()
                if let source = SourceManager.shared.source(for: sourceId) {
                    urlRequest = await source.getModifiedImageRequest(url: url, context: nil)
                }
            }
        }

        self.url = (urlRequest.url ?? url).absoluteString

        let request = ImageRequest(
            urlRequest: urlRequest,
            processors: [DownsampleProcessor(width: bounds.width)]
        )

        cached = cached || ImagePipeline.shared.cache.containsCachedImage(for: request)

        imageTask = ImagePipeline.shared.loadImage(with: request) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success(let response):
                    if response.request.imageId != self.url {
                        return
                    }
                    Task { @MainActor in
                        if cached {
                            self.imageView.image = response.image
                        } else {
                            UIView.transition(with: self.imageView, duration: 0.3, options: .transitionCrossDissolve) {
                                self.imageView.image = response.image
                            }
                        }
                        if response.container.type == .gif, let data = response.container.data {
                            self.imageView.animate(withGIFData: data)
                        }
                    }
                case .failure:
                    self.imageTask = nil
            }
        }
    }
}
