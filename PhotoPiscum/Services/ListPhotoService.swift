//
//  ListPhotoService.swift
//  PhotoPiscum
//
//  Created by Dulcie on 10/1/25.
//

import Foundation
protocol ListPhotoService{
    func request(url: URL, completion: @escaping (Result<Data, Error>) -> Void)
}

final class Service: ListPhotoService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func request(url: URL, completion: @escaping (Result<Data, Error>) -> Void) {
        let task = session.dataTask(with: url) { data, resp, err in
            if let err = err { completion(.failure(err)); return }
            guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode, let data = data else {
                completion(.failure(URLError(.badServerResponse))); return
            }
            completion(.success(data))
        }
        task.resume()
    }
}
