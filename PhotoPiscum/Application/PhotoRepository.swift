//
//  PhotoRepository.swift
//  PhotoPiscum
//
//  Created by Dulcie on 10/1/25.
//

import Foundation

protocol PhotoRepositoryProtocol {
    func fetchPhotos(page: Int, limit: Int, completion: @escaping (Result<[Photo], Error>) -> Void)
}

final class PhotoRepository: PhotoRepositoryProtocol {
    private let network: ListPhotoService

    init(network: ListPhotoService = Service()) {
        self.network = network
    }

    func fetchPhotos(page: Int, limit: Int, completion: @escaping (Result<[Photo], Error>) -> Void) {
        var comp = URLComponents(string: "https://picsum.photos/v2/list")!
        comp.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        guard let url = comp.url else {
            completion(.failure(URLError(.badURL))); return
        }

        network.request(url: url) { result in
            switch result {
            case .failure(let e): completion(.failure(e))
            case .success(let data):
                do {
                    let decoder = JSONDecoder()
                    let photos = try decoder.decode([Photo].self, from: data)
                    completion(.success(photos))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }
}
