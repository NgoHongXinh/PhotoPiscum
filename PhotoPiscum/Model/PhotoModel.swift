//
//  PhotoListViewModel.swift
//  PhotoPiscum
//
//  Created by Dulcie on 10/1/25.
//

import Foundation

struct Photo: Codable, Hashable {
    let id: String
    let author: String
    let width: Int
    let height: Int
    let url: URL
    let download_url: URL
}
