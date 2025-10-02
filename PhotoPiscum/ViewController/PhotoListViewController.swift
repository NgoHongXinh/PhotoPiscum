import UIKit

final class PhotoListViewController: UIViewController {
    
    // MARK: - UI Components
    private let tableView = UITableView()
    private let refreshControl = UIRefreshControl()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)

    // MARK: - ViewModel
    private let viewModel: PhotoListViewModel
    
    // MARK: - Init
    init(viewModel: PhotoListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Picsum Photos"
        view.backgroundColor = .white
        
        setupTableView()
        setupBindings()
        
        // Initial load
        loadingIndicator.startAnimating()
        viewModel.refresh()
    }
}

// MARK: - Setup UI
extension PhotoListViewController {
    private func setupTableView() {
        tableView.register(PhotoCell.self, forCellReuseIdentifier: "PhotoCell")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.prefetchDataSource = self
        tableView.refreshControl = refreshControl
        
        refreshControl.addTarget(self, action: #selector(refreshPhotos), for: .valueChanged)
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Loading indicator
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupBindings() {
        viewModel.onUpdate = { [weak self] in
            DispatchQueue.main.async {
                self?.loadingIndicator.stopAnimating()
                self?.refreshControl.endRefreshing()
                self?.tableView.reloadData()
            }
        }
        
        viewModel.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.loadingIndicator.stopAnimating()
                self?.refreshControl.endRefreshing()
                let alert = UIAlertController(
                    title: "Error",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
            }
        }
    }
    
    @objc private func refreshPhotos() {
        viewModel.refresh()
    }
}

// MARK: - UITableViewDataSource & Delegate
extension PhotoListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.photos.count
    }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: "PhotoCell",
            for: indexPath
        ) as? PhotoCell else {
            return UITableViewCell()
        }
        cell.configure(with: viewModel.photos[indexPath.row])
        return cell
    }
    
    // Pagination
    func tableView(_ tableView: UITableView,
                   willDisplay cell: UITableViewCell,
                   forRowAt indexPath: IndexPath) {
        if indexPath.row == viewModel.photos.count - 1 {
            loadingIndicator.startAnimating()
            viewModel.loadNextPage()
        }
    }
}

// MARK: - UITableViewDataSourcePrefetching
extension PhotoListViewController: UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView,
                   prefetchRowsAt indexPaths: [IndexPath]) {
        for idx in indexPaths {
            guard idx.row < viewModel.photos.count else { continue }
            let photo = viewModel.photos[idx.row]
            let width = Int(UIScreen.main.bounds.width - 16)
            if let url = URL(string: "https://picsum.photos/id/\(photo.id)/\(width)/200") {
                ImageLoader.shared.loadImage(
                    from: url,
                    targetSize: CGSize(width: width, height: 200)
                ) { _ in }
            }
        }
    }
    
    func tableView(_ tableView: UITableView,
                   cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
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
