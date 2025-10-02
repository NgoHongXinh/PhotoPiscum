//
//  AppCoordinator.swift
//  PhotoPiscum
//
//  Created by Dulcie on 10/1/25.
//

import UIKit

final class AppCoordinator: Coordinator {
    var navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        let photoListCoordinator = PhotoListCoordinator(navigationController: navigationController)
        photoListCoordinator.start()
    }
}
