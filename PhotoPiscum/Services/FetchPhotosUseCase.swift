//
//  FetchPhotosUseCase.swift
//  PhotoPiscum
//
//  Created by Dulcie on 10/1/25.
//

import Foundation

protocol FetchPhotosUseCaseProtocol {
    func execute(page: Int, limit: Int, completion: @escaping (Result<[Photo], Error>) -> Void)
}

final class FetchPhotosUseCase: FetchPhotosUseCaseProtocol {
    private let repository: PhotoRepositoryProtocol

    init(repository: PhotoRepositoryProtocol = PhotoRepository()) {
        self.repository = repository
    }

    func execute(page: Int, limit: Int, completion: @escaping (Result<[Photo], Error>) -> Void) {
        repository.fetchPhotos(page: page, limit: limit, completion: completion)
    }
}
