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

    /// Load image with caching & optional resize
    @discardableResult
    func loadImage(
        from url: URL,
        targetSize: CGSize? = nil,
        completion: @escaping (UIImage?) -> Void
    ) -> URLSessionDataTask? {

        let key = cacheKey(url: url, size: targetSize)

        // 1. Check in-memory cache first
        if let cached = cache.object(forKey: key as NSString) {
            completion(cached)
            return nil
        }

        // 2. If a task already running for this URL → return it
        lock.lock()
        if let existingTask = runningTasks[url] {
            lock.unlock()
            return existingTask
        }
        lock.unlock()

        // 3. Start new task
        let task = session.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            defer {
                self.lock.lock()
                self.runningTasks.removeValue(forKey: url)
                self.lock.unlock()
            }

            // Handle error
            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                // Task cancelled, không cần completion
                return
            }

            guard let data = data, let rawImage = UIImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // Resize nếu có targetSize
            let finalImage: UIImage
            if let size = targetSize {
                finalImage = rawImage.scaled(to: size)
            } else {
                finalImage = rawImage
            }

            // Save vào cache
            if let cost = self.imageCost(img: finalImage) {
                self.cache.setObject(finalImage, forKey: key as NSString, cost: cost)
            } else {
                self.cache.setObject(finalImage, forKey: key as NSString)
            }

            DispatchQueue.main.async {
                completion(finalImage)
            }
        }

        // 4. Add vào runningTasks
        lock.lock()
        runningTasks[url] = task
        lock.unlock()

        task.resume()
        return task
    }

    /// Cancel task đang chạy
    func cancelLoad(for url: URL) {
        lock.lock()
        if let task = runningTasks[url] {
            task.cancel()
            runningTasks.removeValue(forKey: url)
        }
        lock.unlock()
    }

    /// Cache key gồm URL + size
    private func cacheKey(url: URL, size: CGSize?) -> String {
        if let s = size {
            return "\(url.absoluteString)-\(Int(s.width))x\(Int(s.height))"
        }
        return url.absoluteString
    }

    /// Ước lượng cost của ảnh trong memory
    private func imageCost(img: UIImage) -> Int? {
        guard let cg = img.cgImage else { return nil }
        return cg.bytesPerRow * cg.height
    }
}

// MARK: - UIImage Resize Helper
private extension UIImage {
    func scaled(to target: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
