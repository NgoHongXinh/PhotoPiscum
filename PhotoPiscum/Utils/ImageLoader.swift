//
//  ImageLoader.swift
//  PhotoPiscum
//
//  Created by Dulcie on 10/1/25.
//

import UIKit

final class ImageLoader {
    static let shared = ImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    private var runningTasks = [URL: URLSessionDataTask]()
    private let lock = NSLock()
    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.session = session
        cache.totalCostLimit = 1024 * 1024 * 100 // ~100MB
    }

    @discardableResult
    func loadImage(from url: URL, targetSize: CGSize? = nil, completion: @escaping (UIImage?) -> Void) -> URLSessionDataTask? {
        let key = cacheKey(url: url, size: targetSize)
        if let img = cache.object(forKey: key as NSString) {
            completion(img)
            return nil
        }

        lock.lock()
        if let existing = runningTasks[url] {
            lock.unlock()
            return existing
        }
        lock.unlock()

        let task = session.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self else { return }
            var image: UIImage? = nil
            if let d = data, let raw = UIImage(data: d) {
                if let ts = targetSize {
                    image = raw.scaled(to: ts)
                } else {
                    image = raw
                }
                if let img = image, let cost = self.imageCost(img: img) {
                    self.cache.setObject(img, forKey: key as NSString, cost: cost)
                } else if let img = image {
                    self.cache.setObject(img, forKey: key as NSString)
                }
            }
            DispatchQueue.main.async {
                completion(image)
            }
            self.lock.lock(); self.runningTasks.removeValue(forKey: url); self.lock.unlock()
        }
        lock.lock(); runningTasks[url] = task; lock.unlock()
        task.resume()
        return task
    }

    func cancelLoad(for url: URL) {
        lock.lock()
        let t = runningTasks[url]
        lock.unlock()
        t?.cancel()
    }

    private func cacheKey(url: URL, size: CGSize?) -> String {
        if let s = size { return "\(url.absoluteString)-\(Int(s.width))x\(Int(s.height))" }
        return url.absoluteString
    }

    private func imageCost(img: UIImage) -> Int? {
        guard let cg = img.cgImage else { return nil }
        return cg.bytesPerRow * cg.height
    }
}

private extension UIImage {
    func scaled(to target: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
