import Foundation

let apiKey = "haMLbq5Kxq01WHqDfOZhVrcYqTbBD1nakMA9CVPgd5qqKNKU6bV1Ljl2"
let pexelsCategories = [
    "beautiful", "abstract", "dark", "nature", "landscape", "space", "beach", "sky", "food", "technology", "business", "office", "flowers", "jungle", "summer", "car", "forest", "sunset",
    "aurora", "nebula", "galaxy", "night-sky", "stars", "milky-way", "ocean", "waterfall", "mountains", "desert", "rain", "thunderstorm", "fog", "snow", "ice", "sunrise", "city-lights", "aerial", "drone", "timelapse", "minimal", "bokeh", "neon", "silhouette", "reflections", "waves", "forest-path", "clouds", "campfire",
    "leaves", "orange", "ship", "switzerland", "pets"
]

private let pexelsPhotoMaxFullPagesByCategory = ThreadSafeDict<String, Int>()
private let pexelsPhotoPerPage = 80
private let pexelsPhotoRequestTimeout: TimeInterval = 10
private let pexelsPhotoMaxAttempts = 3

private struct PexelsPhotosRequestError: Error {
    let userMessage: String
    let logMessage: String
}

private func pexelsPhotosDataPreview(_ data: Data?) -> String {
    guard let data,
          let body = String(data: data, encoding: .utf8),
          !body.isEmpty else {
        return ""
    }
    return String(body.prefix(500))
}

private func requestPexelsPhotosPage(
    category: String,
    page: Int,
    attempt: Int = 1,
    completion: @escaping (Result<PexelsResponse, PexelsPhotosRequestError>) -> Void
) {
    let url = URL(string: "https://api.pexels.com/v1/search?query=\(category)&per_page=\(pexelsPhotoPerPage)&page=\(page)")!
    var request = URLRequest(url: url)
    request.setValue(apiKey, forHTTPHeaderField: "Authorization")
    request.timeoutInterval = pexelsPhotoRequestTimeout

    URLSession.shared.dataTask(with: request) { data, response, error in
        let requestSummary = "query='\(category)' page=\(page) per_page=\(pexelsPhotoPerPage) attempt=\(attempt)/\(pexelsPhotoMaxAttempts)"

        if let error {
            if attempt < pexelsPhotoMaxAttempts {
                requestPexelsPhotosPage(category: category, page: page, attempt: attempt + 1, completion: completion)
                return
            }

            let message = "Pexels photos failed: network request error."
            let log = "\(message) | \(requestSummary) | error: \(error.localizedDescription)"
            completion(.failure(PexelsPhotosRequestError(userMessage: "\(message) (\(requestSummary))", logMessage: log)))
            return
        }

        guard let data else {
            if attempt < pexelsPhotoMaxAttempts {
                requestPexelsPhotosPage(category: category, page: page, attempt: attempt + 1, completion: completion)
                return
            }

            let message = "Pexels photos failed: empty server response."
            let log = "\(message) | \(requestSummary)"
            completion(.failure(PexelsPhotosRequestError(userMessage: "\(message) (\(requestSummary))", logMessage: log)))
            return
        }

        if let statusCode = (response as? HTTPURLResponse)?.statusCode,
           !(200...299).contains(statusCode) {
            if attempt < pexelsPhotoMaxAttempts {
                requestPexelsPhotosPage(category: category, page: page, attempt: attempt + 1, completion: completion)
                return
            }

            let message = "Pexels photos failed: server returned HTTP \(statusCode)."
            let preview = pexelsPhotosDataPreview(data)
            let log = preview.isEmpty ? "\(message) | \(requestSummary)" : "\(message) | \(requestSummary) | body: \(preview)"
            completion(.failure(PexelsPhotosRequestError(userMessage: "\(message) (\(requestSummary))", logMessage: log)))
            return
        }

        do {
            let response = try JSONDecoder().decode(PexelsResponse.self, from: data)
            completion(.success(response))
        } catch {
            if attempt < pexelsPhotoMaxAttempts {
                requestPexelsPhotosPage(category: category, page: page, attempt: attempt + 1, completion: completion)
                return
            }

            let message = "Pexels photos failed: invalid response format."
            let preview = pexelsPhotosDataPreview(data)
            let log = preview.isEmpty ? "\(message) | \(requestSummary) | error: \(error.localizedDescription)" : "\(message) | \(requestSummary) | error: \(error.localizedDescription) | body: \(preview)"
            completion(.failure(PexelsPhotosRequestError(userMessage: "\(message) (\(requestSummary))", logMessage: log)))
        }
    }.resume()
}

func downloadPexelPhotos(pexelsFolder: URL, appDelegate: AppDelegate, onDone: @escaping (_ success: Bool) -> Void) {
    if !isFreeSpaceMoreThan(gigabytes: 1) {
        let message = "Pexels photos failed: not enough free disk space."
        iPrint(message)
        appDelegate.showSettingsError(message)
        onDone(false)
        return
    }

    let category = pexelsCategories.randomElement() ?? "nature"
    appDelegate.setDownloading(true)

    func fail(_ error: PexelsPhotosRequestError) {
        iPrint(error.logMessage)
        appDelegate.showSettingsError(error.userMessage)
        appDelegate.setDownloading(false)
        onDone(false)
    }

    func processResponse(_ pexelsResponse: PexelsResponse, category: String, page: Int, allowPageOneFallback: Bool) {
        let requestSummary = "query='\(category)' page=\(page) per_page=\(pexelsPhotoPerPage)"
        let attemptedCount = pexelsResponse.photos.count

        if attemptedCount == 0 {
            if allowPageOneFallback, page != 1 {
                fetchAndProcessPage(1, allowPageOneFallback: false)
                return
            }

            let message = "Pexels photos failed: Pexels returned 0 photos."
            let log = "\(message) | \(requestSummary)"
            fail(PexelsPhotosRequestError(userMessage: "\(message) (\(requestSummary))", logMessage: log))
            return
        }

        writeFile(directoryURL: pexelsFolder, fileName: ".imageTop", contents: String(pexelsResponse.totalResults))

        let group = DispatchGroup()
        let resultQueue = DispatchQueue(label: "downloadPexelPhotos.resultQueue")
        var downloadedCount = 0

        for photo in pexelsResponse.photos {
            group.enter()
            downloadPhoto(from: photo.src.landscape, photographer: photo.photographer, to: pexelsFolder) { success in
                if success {
                    resultQueue.sync {
                        downloadedCount += 1
                    }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            appDelegate.numberOfPexelsPhotos = downloadedCount
            appDelegate.setDownloading(false)

            guard downloadedCount >= 2 else {
                if allowPageOneFallback, page != 1 {
                    fetchAndProcessPage(1, allowPageOneFallback: false)
                    return
                }

                let message = "Pexels photos failed: downloaded \(downloadedCount)/\(attemptedCount) photos."
                let log = "\(message) | \(requestSummary)"
                fail(PexelsPhotosRequestError(userMessage: "\(message) (\(requestSummary))", logMessage: log))
                return
            }

            appDelegate.clearSettingsError()
            onDone(true)
        }
    }

    func fetchAndProcessPage(_ page: Int, allowPageOneFallback: Bool) {
        requestPexelsPhotosPage(category: category, page: page) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    processResponse(response, category: category, page: page, allowPageOneFallback: allowPageOneFallback)
                case .failure(let error):
                    if allowPageOneFallback, page != 1 {
                        fetchAndProcessPage(1, allowPageOneFallback: false)
                    } else {
                        fail(error)
                    }
                }
            }
        }
    }
    if let cachedMaxFullPages = pexelsPhotoMaxFullPagesByCategory[category] {
        let randomPage = Int.random(in: 1...max(cachedMaxFullPages, 1))
        fetchAndProcessPage(randomPage, allowPageOneFallback: true)
        return
    }

    requestPexelsPhotosPage(category: category, page: 1) { result in
        DispatchQueue.main.async {
            switch result {
            case .failure(let error):
                fail(error)

            case .success(let firstResponse):
                let maxFullPages = max(firstResponse.totalResults / pexelsPhotoPerPage, 1)
                pexelsPhotoMaxFullPagesByCategory[category] = maxFullPages

                let randomPage = Int.random(in: 1...maxFullPages)
                requestPexelsPhotosPage(category: category, page: randomPage) { secondResult in
                    DispatchQueue.main.async {
                        switch secondResult {
                        case .success(let randomPageResponse):
                            processResponse(randomPageResponse, category: category, page: randomPage, allowPageOneFallback: true)
                        case .failure(let error):
                            fail(error)
                        }
                    }
                }
            }
        }
    }
}

