//
//  File.swift
//  PhotoPiscum
//
//  Created by Dulcie on 10/1/25.
//

import UIKit

protocol Coordinator: AnyObject {
    var navigationController: UINavigationController { get set }
    func start()
}
