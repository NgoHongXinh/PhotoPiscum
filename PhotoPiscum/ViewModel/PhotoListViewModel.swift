//
//  PhotoListViewModel.swift
//  PhotoPiscum
//
//  Created by Dulcie on 10/1/25.
//

import Foundation

final class PhotoListViewModel {

    private(set) var photos: [Photo] = []
    private(set) var isLoading: Bool = false
    private(set) var hasMore: Bool = true

    private var currentPage: Int = 1
    private let perPage: Int = 100   // yêu cầu: 100 photos/page

    // MARK: - Dependencies
    private let fetchUseCase: FetchPhotosUseCaseProtocol


    var onUpdate: (() -> Void)?
    var onError: ((Error) -> Void)?

    init(fetchUseCase: FetchPhotosUseCaseProtocol = FetchPhotosUseCase()) {
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
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .failure(let error):
                    self.onError?(error)

                case .success(let newPhotos):
                    // Nếu số lượng nhỏ hơn perPage => đã hết data
                    if newPhotos.count < self.perPage {
                        self.hasMore = false
                    }

                    // Nếu là refresh => replace, ngược lại append
                    if self.currentPage == 1 {
                        self.photos = newPhotos
                    } else {
                        self.photos.append(contentsOf: newPhotos)
                    }

                    self.currentPage += 1
                    self.onUpdate?()
                }
            }
        }
    }
}
