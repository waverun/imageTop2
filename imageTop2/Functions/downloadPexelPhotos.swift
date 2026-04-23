import Foundation

let apiKey = "haMLbq5Kxq01WHqDfOZhVrcYqTbBD1nakMA9CVPgd5qqKNKU6bV1Ljl2"
let pexelsCategories = ["beautiful", "abstract", "dark", "nature", "landscape", "space", "beach", "sky", "food", "technology", "business", "office", "flowers", "jungle", "summer", "car", "forest", "sunset"]

func downloadPexelPhotos(pexelsFolder: URL, appDelegate: AppDelegate, onDone: @escaping () -> Void) {
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

    if !isFreeSpaceMoreThan(gigabytes: 1) {
        iPrint("Not enough space to download Pexels photos")
        return
    }

    var pageNumberParam = ""
    let category = pexelsCategories.randomElement()!

    if let pageNumber = getPageNumber(itemsPerPage: 80) {
        pageNumberParam = "&page=" + String(pageNumber)
    }

    let url = URL(string: "https://api.pexels.com/v1/search?query=" + category + "&per_page=80" + pageNumberParam)!
    iPrint("pexels url: \(url)")
    var request = URLRequest(url: url)
    request.setValue(apiKey, forHTTPHeaderField: "Authorization")

    appDelegate.setDownloading(true)

    func logPexelsPhotosFailure(message: String, data: Data?, response: URLResponse?, error: Error?) {
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
            logPexelsPhotosFailure(message: "Pexels photos request failed", data: data, response: response, error: error)
            appDelegate.setDownloading(false)
            return
        }

        guard let data = data else {
            logPexelsPhotosFailure(message: "Pexels photos request returned empty body", data: nil, response: response, error: nil)
            appDelegate.setDownloading(false)
            return
        }

        if let statusCode = (response as? HTTPURLResponse)?.statusCode,
           !(200...299).contains(statusCode) {
            logPexelsPhotosFailure(message: "Pexels photos request returned non-success status", data: data, response: response, error: nil)
            appDelegate.setDownloading(false)
            return
        }

        do {
            let pexelsResponse = try JSONDecoder().decode(PexelsResponse.self, from: data)

            // Create a dispatch group
            let group = DispatchGroup()
            writeFile(directoryURL: pexelsFolder, fileName: ".imageTop", contents: String(pexelsResponse.totalResults))
            for photo in pexelsResponse.photos {
                // Enter group before each download
                group.enter()
                downloadPhoto(from: photo.src.landscape, photographer: photo.photographer, to: pexelsFolder) {
                    // Leave group after each download
                    group.leave()
                }
            }

            // Wait for all downloads to complete
            group.notify(queue: .main) {
                // All downloads completed
                appDelegate.numberOfPexelsPhotos = pexelsResponse.photos.count
                appDelegate.setDownloading(false)
                onDone()
            }
        } catch {
            logPexelsPhotosFailure(message: "Failed to decode Pexels photos JSON", data: data, response: response, error: error)
            appDelegate.setDownloading(false)
        }
    }

    task.resume()
}

//func downloadPexelPhotos(pexelsFolder: URL) {
//    let apiKey = "haMLbq5Kxq01WHqDfOZhVrcYqTbBD1nakMA9CVPgd5qqKNKU6bV1Ljl2"
//
//    let url = URL(string: "https://api.pexels.com/v1/search?query=nature&per_page=10")!
//    var request = URLRequest(url: url)
//    request.setValue(apiKey, forHTTPHeaderField: "Authorization")
//
//    let task = URLSession.shared.dataTask(with: request) { data, response, error in
//        if let error = error {
//            iPrint("Error: \(error)")
//        } else if let data = data {
//            let decoder = JSONDecoder()
//            do {
//                let pexelsResponse = try decoder.decode(PexelsResponse.self, from: data)
//                iPrint("pexelsResponse photos: \(pexelsResponse.photos.count)")
//                for photo in pexelsResponse.photos {
//                    downloadPhoto(from: photo.src.landscape, photographer: photo.photographer, to: pexelsFolder)
//                }
//
//                // Use pexelsResponse here
//            } catch {
//                iPrint("Error decoding JSON: \(error)")
//            }
//        }
//    }
//
//    task.resume()
//}
