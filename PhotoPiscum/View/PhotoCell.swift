//
//  PhotoCell.swift
//  PhotoPiscum
//
//  Created by Dulcie on 10/1/25.
//

import UIKit

final class PhotoCell: UITableViewCell {
    static let reuseID = "PhotoCell"

    private let photoImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = UIColor(white: 0.95, alpha: 1)
        return iv
    }()

    private let authorLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 14)
        lbl.numberOfLines = 1
        return lbl
    }()

    private var currentURL: URL?
    private var currentTask: URLSessionDataTask?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupLayout() {
        contentView.addSubview(photoImageView)
        contentView.addSubview(authorLabel)

        NSLayoutConstraint.activate([
            photoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            photoImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            photoImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            photoImageView.heightAnchor.constraint(equalToConstant: 200),

            authorLabel.topAnchor.constraint(equalTo: photoImageView.bottomAnchor, constant: 8),
            authorLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            authorLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            authorLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        photoImageView.image = nil
        authorLabel.text = nil
        if let url = currentURL { ImageLoader.shared.cancelLoad(for: url) }
        currentTask?.cancel()
        currentTask = nil
        currentURL = nil
    }

    func configure(with photo: Photo) {
        authorLabel.text = photo.author

        // Build a thumbnail URL sized for device width & height 200
        let width = Int(UIScreen.main.bounds.width - 16)
        if let thumbURL = URL(string: "https://picsum.photos/id/\(photo.id)/\(width)/200") {
            currentURL = thumbURL
            let targetSize = CGSize(width: width, height: 200)
            currentTask = ImageLoader.shared.loadImage(from: thumbURL, targetSize: targetSize) { [weak self] image in
                guard let self = self else { return }
                guard self.currentURL == thumbURL else { return } // cell reused
                if let img = image {
                    self.photoImageView.alpha = 0
                    self.photoImageView.image = img
                    UIView.animate(withDuration: 0.25) { self.photoImageView.alpha = 1 }
                } else {
                    // keep placeholder
                }
            }
        }
    }
}
