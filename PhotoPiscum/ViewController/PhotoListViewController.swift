import UIKit

final class PhotoListViewController: UIViewController {
    
    private let tableView = UITableView()
    private let refreshControl = UIRefreshControl()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)

    // Search
    private let searchField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Search by author or id"
        tf.borderStyle = .roundedRect
        tf.returnKeyType = .search
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        return tf
    }()

    // Debounce
    private var debounceWorkItem: DispatchWorkItem?

    private let viewModel: PhotoListViewModel

    private var allPhotos: [Photo] = []

    private var filteredPhotos: [Photo] = []
    
    private let noResultsLabel: UILabel = {
           let label = UILabel()
           label.text = "No results"
           label.textAlignment = .center
           label.textColor = .gray
           label.font = .systemFont(ofSize: 16, weight: .medium)
           label.isHidden = true
           return label
       }()

    // MARK: Init
    init(viewModel: PhotoListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Picsum Photos"
        view.backgroundColor = .systemBackground

        setupTableView()
        setupSearchHeader()
        setupBindings()

        // initial load
        loadingIndicator.startAnimating()
        viewModel.refresh()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
    }

    // MARK: Setup UI
    private func setupTableView() {
        tableView.register(PhotoCell.self, forCellReuseIdentifier: PhotoCell.reuseID)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.prefetchDataSource = self

        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refreshPhotos), for: .valueChanged)

        view.addSubview(tableView)

        // loading indicator
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupSearchHeader() {
        // container to size the header properly
        let container = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 56))
        searchField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(searchField)

        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            searchField.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            searchField.heightAnchor.constraint(equalToConstant: 36)
        ])

        tableView.tableHeaderView = container

        // delegate + target
        searchField.delegate = self
        searchField.addTarget(self, action: #selector(searchFieldEditingChanged(_:)), for: .editingChanged)
    }

    // MARK: Bindings
    private func setupBindings() {
        viewModel.onUpdate = { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                // Append newly loaded photos to allPhotos
                // assume viewModel.photos is cumulative (append when loading pages)
                self.allPhotos = self.viewModel.photos
                // If there's a current query -> re-filter, else show all
                if let q = self.searchField.text, !q.isEmpty {
                    self.performFilter(query: q)
                } else {
                    self.filteredPhotos = self.allPhotos
                }
                self.tableView.reloadData()
                self.refreshControl.endRefreshing()
                self.loadingIndicator.stopAnimating()
            }
        }

        viewModel.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.refreshControl.endRefreshing()
                self?.loadingIndicator.stopAnimating()
                let a = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                a.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(a, animated: true)
            }
        }
    }

    @objc private func refreshPhotos() {
        searchField.text = ""              // clear query on manual refresh (optional)
        viewModel.refresh()
    }

    // Debounced editing changed
    @objc private func searchFieldEditingChanged(_ sender: UITextField) {
        debounceWorkItem?.cancel()
        let query = sender.text ?? ""
        // schedule debounce
        let wi = DispatchWorkItem { [weak self] in
            self?.performFilter(query: query)
        }
        debounceWorkItem = wi
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: wi)
    }

    // Filtering logic
    private func performFilter(query rawQuery: String) {
        let q = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            // empty -> show all
            filteredPhotos = allPhotos
            tableView.reloadData()
            return
        }

        // If query is purely numeric -> search by id (contains)
        if CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: q)) {
            filteredPhotos = allPhotos.filter { $0.id.contains(q) }
        } else {
            // search author case-insensitive (ASCII only)
            filteredPhotos = allPhotos.filter { $0.author.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }

        tableView.reloadData()
        // Optional: scroll to top
        if !filteredPhotos.isEmpty {
            tableView.setContentOffset(.zero, animated: true)
        }
    }
}


extension PhotoListViewController: UITableViewDataSource, UITableViewDelegate, UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredPhotos.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: PhotoCell.reuseID, for: indexPath) as? PhotoCell else {
            return UITableViewCell()
        }
        let photo = filteredPhotos[indexPath.row]
        cell.configure(with: photo)
        return cell
    }

    // pagination trigger (when showing last row in filtered list we load next if no active search)
    func tableView(_ tableView: UITableView,
                   willDisplay cell: UITableViewCell,
                   forRowAt indexPath: IndexPath) {
        // only trigger pagination if not currently searching (avoid confusing results)
        let isSearching = !(searchField.text ?? "").isEmpty
        if !isSearching && indexPath.row >= (filteredPhotos.count - 6) && viewModel.hasMore && !viewModel.isLoading {
            loadingIndicator.startAnimating()
            viewModel.loadNextPage()
        }
    }

    // prefetch images for visible (use filteredPhotos)
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        for idx in indexPaths {
            guard idx.row < filteredPhotos.count else { continue }
            let photo = filteredPhotos[idx.row]
            let width = Int(UIScreen.main.bounds.width - 16)
            if let url = URL(string: "https://picsum.photos/id/\(photo.id)/\(width)/200") {
                ImageLoader.shared.loadImage(from: url, targetSize: CGSize(width: width, height: 200)) { _ in }
            }
        }
    }

    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        for idx in indexPaths {
            guard idx.row < filteredPhotos.count else { continue }
            let photo = filteredPhotos[idx.row]
            let width = Int(UIScreen.main.bounds.width - 16)
            if let url = URL(string: "https://picsum.photos/id/\(photo.id)/\(width)/200") {
                ImageLoader.shared.cancelLoad(for: url)
            }
        }
    }
}

// MARK: - UITextFieldDelegate: validation (no diacritics, allow only specific chars, no emoji, max 15)
extension PhotoListViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {

        // block emoji quickly
        if string.containsEmoji { return false }

        // compute resulting string
        let current = textField.text ?? ""
        guard let stringRange = Range(range, in: current) else { return false }
        let updated = current.replacingCharacters(in: stringRange, with: string)

        // length limit
        if updated.count > 15 { return false }

        // allowed charset: ASCII letters, digits, and allowed punctuation !@#$%^&*():."
        let pattern = "^[A-Za-z0-9!@#\\$%\\^&\\*\\(\\):\\.\\\"]*$"
        let matches = updated.range(of: pattern, options: .regularExpression) != nil
        return matches
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // immediate search on return
        debounceWorkItem?.cancel()
        performFilter(query: textField.text ?? "")
        textField.resignFirstResponder()
        return true
    }
}

fileprivate extension String {
    var containsEmoji: Bool {
        for scalar in unicodeScalars {
            switch scalar.value {
            case 0x1F600...0x1F64F,  // Emoticons
                 0x1F300...0x1F5FF,  // Misc Symbols & Pictographs
                 0x1F680...0x1F6FF,  // Transport & Map
                 0x2600...0x26FF,    // Misc symbols
                 0x2700...0x27BF,    // Dingbats
                 0xFE00...0xFE0F,    // Variation Selectors
                 0x1F900...0x1F9FF,  // Supplemental Symbols & Pictographs
                 0x1F1E6...0x1F1FF:  // Flags
                return true
            default:
                continue
            }
        }
        return false
    }
}
