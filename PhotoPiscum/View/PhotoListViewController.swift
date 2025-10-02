//
//  PhotoListViewController.swift
//  PhotoPiscum
//
//  Created by Dulcie on 10/1/25.
//

import UIKit

final class PhotoListViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var dataSource: UITableViewDiffableDataSource<Int, Photo>!
    private let viewModel: PhotoListViewModel
    private var spinnerFooter: UIActivityIndicatorView?

    init(viewModel: PhotoListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Picsum Photos"
        view.backgroundColor = .systemBackground
        setupTableView()
        configureDataSource()
        configureRefreshControl()
        configureFooterSpinner()
        bindViewModel()
        viewModel.loadNextPage() // initial load
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
    }

    private func setupTableView() {
        view.addSubview(tableView)
        tableView.register(PhotoCell.self, forCellReuseIdentifier: PhotoCell.reuseID)
        tableView.estimatedRowHeight = 260
        tableView.rowHeight = UITableView.automaticDimension
        tableView.prefetchDataSource = self
        tableView.delegate = self
    }

    private func configureDataSource() {
        dataSource = UITableViewDiffableDataSource(tableView: tableView) { (tv, idx, photo) -> UITableViewCell? in
            guard let cell = tv.dequeueReusableCell(withIdentifier: PhotoCell.reuseID, for: idx) as? PhotoCell else { return UITableViewCell() }
            cell.configure(with: photo)
            return cell
        }
    }

    private func applySnapshot(animating: Bool = true) {
        var snap = NSDiffableDataSourceSnapshot<Int, Photo>()
        snap.appendSections([0])
        snap.appendItems(viewModel.photos, toSection: 0)
        dataSource.apply(snap, animatingDifferences: animating)
    }

    private func configureRefreshControl() {
        let rc = UIRefreshControl()
        rc.addTarget(self, action: #selector(onRefresh), for: .valueChanged)
        tableView.refreshControl = rc
    }

    @objc private func onRefresh() {
        viewModel.refresh()
        tableView.refreshControl?.endRefreshing()
    }

    private func configureFooterSpinner() {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 44)
        spinner.hidesWhenStopped = true
        tableView.tableFooterView = spinner
        spinnerFooter = spinner
    }

    private func bindViewModel() {
        viewModel.onUpdate = { [weak self] in
            self?.applySnapshot()
            self?.spinnerFooter?.stopAnimating()
        }
        viewModel.onError = { [weak self] error in
            self?.spinnerFooter?.stopAnimating()
            DispatchQueue.main.async {
                let a = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                a.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(a, animated: true)
            }
        }
    }
}

extension PhotoListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Optionally show fullscreen image
    }

    func tableView(_ tableView: UITableView,
                   willDisplay cell: UITableViewCell,
                   forRowAt indexPath: IndexPath) {
        // pagination trigger
        let threshold = viewModel.photos.count - 6
        if indexPath.row >= threshold && viewModel.hasMore && !viewModel.isLoading {
            spinnerFooter?.startAnimating()
            viewModel.loadNextPage()
        }
    }
}

extension PhotoListViewController: UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        for idx in indexPaths {
            guard idx.row < viewModel.photos.count else { continue }
            let photo = viewModel.photos[idx.row]
            let width = Int(UIScreen.main.bounds.width - 16)
            if let url = URL(string: "https://picsum.photos/id/\(photo.id)/\(width)/200") {
                ImageLoader.shared.loadImage(from: url, targetSize: CGSize(width: width, height: 200)) { _ in }
            }
        }
    }

    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        for idx in indexPaths {
            guard idx.row < viewModel.photos.count else { continue }
            let photo = viewModel.photos[idx.row]
            let width = Int(UIScreen.main.bounds.width - 16)
            if let url = URL(string: "https://picsum.photos/id/\(photo.id)/\(width)/200") {
                ImageLoader.shared.cancelLoad(for: url)
            }
        }
    }
}
