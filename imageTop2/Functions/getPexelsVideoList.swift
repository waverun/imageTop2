import Foundation

func getPexelsVideoList(pexelsFolder: URL, onDone: @escaping (_: [String]) -> Void) {
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


//    if !isFreeSpaceMoreThan(gigabytes: 1) {
//        print("Not enough space to download Pexels photos")
//        return
//    }

    if let videoLinks = loadVideoNames(from: pexelsFolder) {
        onDone(videoLinks)
        return
    }

    var pageNumberParam = ""
    let category = pexelsCategories.randomElement()!

    if let pageNumber = getPageNumber(itemsPerPage: 80) {
        pageNumberParam = "&page=" + String(pageNumber)
    }

    let url = URL(string: "https://api.pexels.com/videos/search?query=" + category + "&per_page=80" + pageNumberParam)!
    print("pexels url: \(url)")
    var request = URLRequest(url: url)
    request.setValue(apiKey, forHTTPHeaderField: "Authorization")

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error: \(error)")
        } else if let data = data {
            _ = JSONDecoder()
            do {
//                let pexelsResponse = try decoder.decode(PexelsResponse.self, from: data)
                let videoData = try JSONDecoder().decode(VideoData.self, from: data)

                print("pexelsResponse photos: \(videoData.videos.count)")

                var videoLinks: [String] = []
                for video in videoData.videos {
                    var width = 0
                    var link = ""
                    for videoFile in video.videoFiles {
                        if let videoWidth = videoFile.width,
                           videoWidth > width {
                            link = videoFile.link
                            width = videoWidth
                        }
                    }
                    videoLinks.append(link)
                }
//                let videoFileURL = pexelsFolder.appendingPathComponent("videoList.txx")
                let videoList = videoLinks.joined(separator: "\n")
                writeFile(directoryURL: pexelsFolder, fileName: pexelsVideoList, contents: videoList)
                onDone(videoLinks)
                // Create a dispatch group
//                let group = DispatchGroup()
//                writeFile(directoryURL: pexelsFolder, fileName: ".imageTop", contents: String(pexelsResponse.totalResults))
//                for photo in pexelsResponse.photos {
//                    // Enter group before each download
//                    group.enter()
//                    downloadPhoto(from: photo.src.landscape, photographer: photo.photographer, to: pexelsFolder) {
//                        // Leave group after each download
//                        group.leave()
//                    }
//                }
//
//                // Wait for all downloads to complete
//                group.notify(queue: .main) {
//                    // All downloads completed
//                    onDone()
//                }
            } catch {
                print("Error decoding JSON: \(error)")
            }
        }
    }

    task.resume()
}