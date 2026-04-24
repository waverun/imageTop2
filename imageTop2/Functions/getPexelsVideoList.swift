import Foundation
import AppKit

private let pexelsVideoMaxFullPagesByCategory = ThreadSafeDict<String, Int>()
private let pexelsVideoPerPage = 80
private let pexelsVideoRequestTimeout: TimeInterval = 10
private let pexelsVideoMaxAttempts = 3

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

func getPexelsVideoList(pexelsFolder: URL, appDelegate: AppDelegate, onDone: @escaping (_: [String]) -> Void) {
    let pexelsVideoList = "videoList.txt"

    func loadVideoNames(from: URL) -> [String]? {
        let videosFileName = pexelsVideoList
        let videoFileURL = from.appendingPathComponent(videosFileName)

        guard FileManager.default.fileExists(atPath: videoFileURL.path) else {
            return nil
        }

        if let videoNamesList = readFileContents(atPath: videoFileURL.path) {
            return videoNamesList
                .components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }

        return nil
    }

    if let videoLinks = loadVideoNames(from: pexelsFolder) {
        onDone(videoLinks)
        return
    }

    let category = pexelsCategories.randomElement() ?? "nature"

    var screenWidth = WindowManager.shared.getMaxScreenWidth()
    if 0 < screenWidth {
        screenWidth = Int(Double(screenWidth) * 0.9)
    }

    appDelegate.setDownloading(true)

    func fail(_ error: PexelsVideosRequestError) {
        iPrint(error.logMessage)
        appDelegate.showSettingsError(error.userMessage)
        appDelegate.setDownloading(false)
        onDone([])
    }

    func processResponse(_ videoData: VideoData, category: String, page: Int, allowPageOneFallback: Bool) {
        let requestSummary = "query='\(category)' page=\(page) per_page=\(pexelsVideoPerPage)"

        var videoLinks: [String] = []
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
        writeFile(directoryURL: pexelsFolder, fileName: pexelsVideoList, contents: videoList)
        DispatchQueue.main.async {
            appDelegate.numberOfPexelsVideos = videoLinks.count
        }
        appDelegate.clearSettingsError()
        appDelegate.setDownloading(false)
        onDone(videoLinks)
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
