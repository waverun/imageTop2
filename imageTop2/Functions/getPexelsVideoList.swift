import Foundation
import AppKit

private let pexelsVideoMaxFullPagesByCategory = ThreadSafeDict<String, Int>()
private let pexelsVideoPerPage = 80
private let pexelsVideoRequestTimeout: TimeInterval = 10
private let pexelsVideoMaxAttempts = 80

private struct PexelsVideosRequestError: Error {
    let userMessage: String
    let logMessage: String
}

private func pexelsVideosDataPreview(_ data: Data?) -> String {
    guard let data,
          let body = String(data: data, encoding: .utf8),
          !body.isEmpty else {
        return ""
    }
    return String(body.prefix(500))
}

private func requestPexelsVideosPage(
    category: String,
    page: Int,
    attempt: Int = 1,
    completion: @escaping (Result<VideoData, PexelsVideosRequestError>) -> Void
) {
    let url = URL(string: "https://api.pexels.com/videos/search?orientation=landscape&query=\(category)&min_duration=10&max_duration=60&per_page=\(pexelsVideoPerPage)&page=\(page)")!
    var request = URLRequest(url: url)
    request.setValue(apiKey, forHTTPHeaderField: "Authorization")
    request.timeoutInterval = pexelsVideoRequestTimeout

    URLSession.shared.dataTask(with: request) { data, response, error in
        let requestSummary = "query='\(category)' page=\(page) per_page=\(pexelsVideoPerPage) attempt=\(attempt)/\(pexelsVideoMaxAttempts)"

        if let error {
            if attempt < pexelsVideoMaxAttempts {
                requestPexelsVideosPage(category: category, page: page, attempt: attempt + 1, completion: completion)
                return
            }

            let message = "Pexels videos failed: network request error."
            let log = "\(message) | \(requestSummary) | error: \(error.localizedDescription)"
            completion(.failure(PexelsVideosRequestError(userMessage: "\(message) (\(requestSummary))", logMessage: log)))
            return
        }

        guard let data else {
            if attempt < pexelsVideoMaxAttempts {
                requestPexelsVideosPage(category: category, page: page, attempt: attempt + 1, completion: completion)
                return
            }

            let message = "Pexels videos failed: empty server response."
            let log = "\(message) | \(requestSummary)"
            completion(.failure(PexelsVideosRequestError(userMessage: "\(message) (\(requestSummary))", logMessage: log)))
            return
        }

        if let statusCode = (response as? HTTPURLResponse)?.statusCode,
           !(200...299).contains(statusCode) {
            if attempt < pexelsVideoMaxAttempts {
                requestPexelsVideosPage(category: category, page: page, attempt: attempt + 1, completion: completion)
                return
            }

            let message = "Pexels videos failed: server returned HTTP \(statusCode)."
            let preview = pexelsVideosDataPreview(data)
            let log = preview.isEmpty ? "\(message) | \(requestSummary)" : "\(message) | \(requestSummary) | body: \(preview)"
            completion(.failure(PexelsVideosRequestError(userMessage: "\(message) (\(requestSummary))", logMessage: log)))
            return
        }

        do {
            let response = try JSONDecoder().decode(VideoData.self, from: data)
            completion(.success(response))
        } catch {
            if attempt < pexelsVideoMaxAttempts {
                requestPexelsVideosPage(category: category, page: page, attempt: attempt + 1, completion: completion)
                return
            }

            let message = "Pexels videos failed: invalid response format."
            let preview = pexelsVideosDataPreview(data)
            let log = preview.isEmpty ? "\(message) | \(requestSummary) | error: \(error.localizedDescription)" : "\(message) | \(requestSummary) | error: \(error.localizedDescription) | body: \(preview)"
            completion(.failure(PexelsVideosRequestError(userMessage: "\(message) (\(requestSummary))", logMessage: log)))
        }
    }.resume()
}

func getPexelsVideoList(
    pexelsFolder: URL,
    appDelegate: AppDelegate,
    selectionMode: PexelsCategorySelectionMode = .automaticNoRepeat,
    onDone: @escaping (_ videos: [String], _ previews: [String]) -> Void
) {
    let pexelsVideoList = "videoList.txt"
    let pexelsVideoPreviewList = "videoPreviewList.txt"

    func loadVideoNamesAndPreviews(from: URL) -> ([String], [String])? {
        let videosFileURL = from.appendingPathComponent(pexelsVideoList)
        let previewsFileURL = from.appendingPathComponent(pexelsVideoPreviewList)

        guard FileManager.default.fileExists(atPath: videosFileURL.path) else {
            return nil
        }

        guard let videoNamesList = readFileContents(atPath: videosFileURL.path) else {
            return nil
        }

        let videoLinks = videoNamesList
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard !videoLinks.isEmpty else {
            return nil
        }

        var previewLinks: [String] = []
        if FileManager.default.fileExists(atPath: previewsFileURL.path),
           let previewNamesList = readFileContents(atPath: previewsFileURL.path) {
            previewLinks = previewNamesList
                .components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }

        if previewLinks.count < videoLinks.count {
            previewLinks.append(contentsOf: Array(repeating: "", count: videoLinks.count - previewLinks.count))
        }

        return (videoLinks, previewLinks)
    }

    func validateCachedVideoLinks(_ links: [String], completion: @escaping (Bool) -> Void) {
        let urlsToValidate = links.prefix(2).compactMap { entry -> String? in
            let components = entry.components(separatedBy: ",")
            return components.first
        }
        guard !urlsToValidate.isEmpty else {
            completion(false)
            return
        }

        let group = DispatchGroup()
        var allValid = true
        let resultQueue = DispatchQueue(label: "pexels.cachedVideoValidation.resultQueue")
        for url in urlsToValidate {
            group.enter()
            checkIfURLExists(url: url) { exists in
                resultQueue.sync {
                    if !exists {
                        allValid = false
                    }
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            completion(allValid)
        }
    }

    // Keep existing videos between app launches.
    // Manual mode still forces a fresh fetch.
    if selectionMode == .automaticNoRepeat,
       let (videoLinks, previewLinks) = loadVideoNamesAndPreviews(from: pexelsFolder) {
        validateCachedVideoLinks(videoLinks) { isValid in
            if isValid {
                onDone(videoLinks, previewLinks)
                return
            }
            clearPexelVideos(folderURL: pexelsFolder, fileName: pexelsVideoList)
            clearPexelVideos(folderURL: pexelsFolder, fileName: pexelsVideoPreviewList)
            getPexelsVideoList(pexelsFolder: pexelsFolder, appDelegate: appDelegate, selectionMode: selectionMode, onDone: onDone)
        }
        return
    }

    let category = nextPexelsCategory(mode: selectionMode)

    var screenWidth = WindowManager.shared.getMaxScreenWidth()
    if 0 < screenWidth {
        screenWidth = Int(Double(screenWidth) * 0.9)
    }

    appDelegate.setDownloading(true)

    func fail(_ error: PexelsVideosRequestError) {
        iPrint(error.logMessage)
        appDelegate.showSettingsError(error.userMessage)
        appDelegate.setDownloading(false)
        onDone([], [])
    }

    func processResponse(_ videoData: VideoData, category: String, page: Int, allowPageOneFallback: Bool) {
        let requestSummary = "query='\(category)' page=\(page) per_page=\(pexelsVideoPerPage)"

        var videoLinks: [String] = []
        var previewLinks: [String] = []
        for video in videoData.videos {
            guard video.duration >= 10, video.duration <= 60 else {
                continue
            }

            let candidateFiles = video.videoFiles.compactMap { videoFile -> (width: Int, link: String)? in
                guard let videoWidth = videoFile.width,
                      !videoFile.link.isEmpty else {
                    return nil
                }
                return (videoWidth, videoFile.link)
            }

            guard !candidateFiles.isEmpty else {
                continue
            }

            let selectedFile: (width: Int, link: String)
            if let bestBelowScreen = candidateFiles
                .filter({ $0.width <= screenWidth })
                .max(by: { $0.width < $1.width }) {
                selectedFile = bestBelowScreen
            } else if let smallestAboveScreen = candidateFiles
                .filter({ $0.width > screenWidth })
                .min(by: { $0.width < $1.width }) {
                selectedFile = smallestAboveScreen
            } else {
                continue
            }

            let linkWithPhotographer = selectedFile.link + "," + video.user.name
            videoLinks.append(linkWithPhotographer)
            previewLinks.append(video.image ?? "")
        }

        guard !videoLinks.isEmpty else {
            if allowPageOneFallback, page != 1 {
                fetchAndProcessPage(1, allowPageOneFallback: false)
                return
            }

            let message = "Pexels videos failed: no usable videos returned."
            let log = "\(message) | \(requestSummary)"
            fail(PexelsVideosRequestError(userMessage: "\(message) (\(requestSummary))", logMessage: log))
            return
        }

        let videoList = videoLinks.joined(separator: "\n")
        let previewList = previewLinks.joined(separator: "\n")
        writeFile(directoryURL: pexelsFolder, fileName: pexelsVideoList, contents: videoList)
        writeFile(directoryURL: pexelsFolder, fileName: pexelsVideoPreviewList, contents: previewList)
        DispatchQueue.main.async {
            appDelegate.numberOfPexelsVideos = videoLinks.count
        }
        appDelegate.clearSettingsError()
        appDelegate.setDownloading(false)
        onDone(videoLinks, previewLinks)
    }

    func fetchAndProcessPage(_ page: Int, allowPageOneFallback: Bool) {
        requestPexelsVideosPage(category: category, page: page) { result in
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

    if let cachedMaxFullPages = pexelsVideoMaxFullPagesByCategory[category] {
        let randomPage = Int.random(in: 1...max(cachedMaxFullPages, 1))
        fetchAndProcessPage(randomPage, allowPageOneFallback: true)
        return
    }

    requestPexelsVideosPage(category: category, page: 1) { result in
        DispatchQueue.main.async {
            switch result {
            case .failure(let error):
                fail(error)

            case .success(let firstResponse):
                let totalResults = firstResponse.totalResults ?? pexelsVideoPerPage
                let maxFullPages = max(totalResults / pexelsVideoPerPage, 1)
                pexelsVideoMaxFullPagesByCategory[category] = maxFullPages

                let randomPage = Int.random(in: 1...maxFullPages)
                requestPexelsVideosPage(category: category, page: randomPage) { secondResult in
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
