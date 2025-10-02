//
//  PhotoListViewModel.swift
//  PhotoPiscum
//
//  Created by Dulcie on 10/1/25.
//

import Foundation

final class PhotoListViewModel {
    // Public read-only
    private(set) var photos: [Photo] = []
    private(set) var isLoading: Bool = false
    private(set) var hasMore: Bool = true

    // Pagination config
    private var currentPage: Int = 1
    private let perPage: Int

    // Dependencies
    private let fetchUseCase: FetchPhotosUseCaseProtocol

    // Bindings
    var onUpdate: (() -> Void)?
    var onError: ((Error) -> Void)?

    init(perPage: Int = 30, fetchUseCase: FetchPhotosUseCaseProtocol = FetchPhotosUseCase()) {
        self.perPage = perPage
        self.fetchUseCase = fetchUseCase
    }

    func refresh() {
        currentPage = 1
        hasMore = true
        photos.removeAll()
        loadNextPage()
    }

    func loadNextPage() {
        guard !isLoading && hasMore else { return }
        isLoading = true

        fetchUseCase.execute(page: currentPage, limit: perPage) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            switch result {
            case .failure(let error):
                self.onError?(error)
            case .success(let new):
                if new.count < self.perPage { self.hasMore = false }
                if self.currentPage == 1 {
                    self.photos = new
                } else {
                    self.photos.append(contentsOf: new)
                }
                self.currentPage += 1
                self.onUpdate?()
            }
        }
    }
}
