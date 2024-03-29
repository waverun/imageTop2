import Foundation
import AppKit

func getPexelsVideoList(pexelsFolder: URL, appDelegate: AppDelegate, onDone: @escaping (_: [String]) -> Void) {
    let pexelsVideoList = "videoList.txt"

    func loadVideoNames(from: URL) -> [String]? {
        let videosFileName = pexelsVideoList
        let videoFileURL = from.appendingPathComponent(videosFileName)

        if let videoNamesList = readFileContents(atPath: videoFileURL.path) {
            let videoNames = videoNamesList.components(separatedBy: "\n")
            return videoNames
        }
        return nil
    }

    func getPageNumber(itemsPerPage: Int) -> Int? {
        func getNumberOfItems() -> Int? {
            if let numberOfItems = readFileContents(atPath: pexelsFolder.path + "/.imageTop") {
                return Int(numberOfItems)
            }
            return nil
        }
        if let numberOfItems = getNumberOfItems() {
            if numberOfItems > itemsPerPage * 2 {
                let numberOfPages = numberOfItems / itemsPerPage
                let random = Int.random(in: 1...numberOfPages)
                return random
            }
        }
        return nil
    }

    if let videoLinks = loadVideoNames(from: pexelsFolder) {
        onDone(videoLinks)
        return
    }

    var pageNumberParam = ""
    let category = pexelsCategories.randomElement()!

    if let pageNumber = getPageNumber(itemsPerPage: 80) {
        pageNumberParam = "&page=" + String(pageNumber)
    }

    let kind = ["search"].randomElement()!
    let url = URL(string: "https://api.pexels.com/videos/" + kind + "?orientation=landscape&query=" + category + "&min_duration=10&max_duration=60&per_page=80" + pageNumberParam)!
    iPrint("pexels url: \(url)")
    var request = URLRequest(url: url)
    request.setValue(apiKey, forHTTPHeaderField: "Authorization")

    var screenWidth = WindowManager.shared.getMaxScreenWidth()
    if 0 < screenWidth {
        screenWidth = Int(Double(screenWidth) * 0.9)
    }

    appDelegate.setDownloading(true)

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            iPrint("Error: \(error)")

        } else if let data = data {
            _ = JSONDecoder()
            do {
                let videoData = try JSONDecoder().decode(VideoData.self, from: data)
                iPrint("pexelsResponse photos: \(videoData.videos.count)")

                var videoLinks: [String] = []
                for video in videoData.videos {
                    var width = 0
                    var link = ""
                    for videoFile in video.videoFiles {
                        if let videoWidth = videoFile.width,
                           video.duration >= 10, video.duration <= 60,
                           videoWidth > width && width < screenWidth
                           || videoWidth > screenWidth && videoWidth < width {
                            link = videoFile.link + "," + video.user.name
                            width = videoWidth
                            iPrint("viderFile: lenght: \(video.duration)")
                        }
                    }
                    videoLinks.append(link)
                }
                let videoList = videoLinks.joined(separator: "\n")
                writeFile(directoryURL: pexelsFolder, fileName: pexelsVideoList, contents: videoList)
                iPrint("videoLinks.count: \(videoLinks.count)")
                DispatchQueue.main.async {
                    appDelegate.numberOfPexelsVideos = videoLinks.count
                }
                appDelegate.setDownloading(false)
                onDone(videoLinks)
            } catch {
                iPrint("Error decoding JSON: \(error)")
                appDelegate.setDownloading(false)
            }
        }
//        appDelegate.setDownloading(false)
    }

    task.resume()
}
