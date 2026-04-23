import Foundation
import AppKit

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

    let category = pexelsCategories.randomElement()!
    let kind = ["search"].randomElement()!
    let url = URL(string: "https://api.pexels.com/videos/" + kind + "?orientation=landscape&query=" + category + "&min_duration=10&max_duration=60&per_page=80")!
    iPrint("pexels url: \(url)")
    var request = URLRequest(url: url)
    request.setValue(apiKey, forHTTPHeaderField: "Authorization")

    var screenWidth = WindowManager.shared.getMaxScreenWidth()
    if 0 < screenWidth {
        screenWidth = Int(Double(screenWidth) * 0.9)
    }

    appDelegate.setDownloading(true)

    func logPexelsVideosFailure(message: String, data: Data?, response: URLResponse?, error: Error?) {
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        var logMessage = "\(message)"

        if let statusCode = statusCode {
            logMessage += " | HTTP \(statusCode)"
        }

        if let error = error {
            logMessage += " | error: \(error.localizedDescription)"
        }

        if let data = data,
           let body = String(data: data, encoding: .utf8),
           !body.isEmpty {
            let preview = String(body.prefix(500))
            logMessage += " | body: \(preview)"
        }

        iPrint(logMessage)
    }

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            logPexelsVideosFailure(message: "Pexels videos request failed", data: data, response: response, error: error)
            appDelegate.setDownloading(false)
            return
        }

        guard let data = data else {
            logPexelsVideosFailure(message: "Pexels videos request returned empty body", data: nil, response: response, error: nil)
            appDelegate.setDownloading(false)
            return
        }

        if let statusCode = (response as? HTTPURLResponse)?.statusCode,
           !(200...299).contains(statusCode) {
            logPexelsVideosFailure(message: "Pexels videos request returned non-success status", data: data, response: response, error: nil)
            appDelegate.setDownloading(false)
            return
        }

        do {
            let videoData = try JSONDecoder().decode(VideoData.self, from: data)

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

            if videoLinks.isEmpty {
                logPexelsVideosFailure(message: "Pexels videos response contained no usable video links", data: data, response: response, error: nil)
                appDelegate.setDownloading(false)
                onDone([])
                return
            }

            let videoList = videoLinks.joined(separator: "\n")
            writeFile(directoryURL: pexelsFolder, fileName: pexelsVideoList, contents: videoList)
            DispatchQueue.main.async {
                appDelegate.numberOfPexelsVideos = videoLinks.count
            }
            appDelegate.setDownloading(false)
            onDone(videoLinks)
        } catch {
            logPexelsVideosFailure(message: "Failed to decode Pexels videos JSON", data: data, response: response, error: error)
            appDelegate.setDownloading(false)
        }
    }

    task.resume()
}
