//
//  PhotoListCoordinator.swift
//  PhotoPiscum
//
//  Created by Dulcie on 10/1/25.
//

import UIKit

final class PhotoListCoordinator: Coordinator {
    var navigationController: UINavigationController
    private let repository: PhotoRepositoryProtocol

    init(navigationController: UINavigationController, repository: PhotoRepositoryProtocol = PhotoRepository()) {
        self.navigationController = navigationController
        self.repository = repository
    }

    func start() {
        let useCase = FetchPhotosUseCase(repository: repository)
        let viewModel = PhotoListViewModel(fetchUseCase: useCase)
        let vc = PhotoListViewController(viewModel: viewModel)
        navigationController.pushViewController(vc, animated: false)
    }
}
