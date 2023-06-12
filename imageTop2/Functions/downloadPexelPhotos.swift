import Foundation

func downloadPexelPhotos(pexelsFolder: URL, onDone: @escaping () -> Void) {
    if !isFreeSpaceMoreThan(gigabytes: 1) {
        print("Not enough space to download Pexels photos")
        return
    }
    
    let apiKey = "haMLbq5Kxq01WHqDfOZhVrcYqTbBD1nakMA9CVPgd5qqKNKU6bV1Ljl2"

    let url = URL(string: "https://api.pexels.com/v1/search?query=nature&per_page=80")!
    var request = URLRequest(url: url)
    request.setValue(apiKey, forHTTPHeaderField: "Authorization")

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error: \(error)")
        } else if let data = data {
            let decoder = JSONDecoder()
            do {
                let pexelsResponse = try decoder.decode(PexelsResponse.self, from: data)
                print("pexelsResponse photos: \(pexelsResponse.photos.count)")

                // Create a dispatch group
                let group = DispatchGroup()

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
                    onDone()
                }
            } catch {
                print("Error decoding JSON: \(error)")
            }
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
//            print("Error: \(error)")
//        } else if let data = data {
//            let decoder = JSONDecoder()
//            do {
//                let pexelsResponse = try decoder.decode(PexelsResponse.self, from: data)
//                print("pexelsResponse photos: \(pexelsResponse.photos.count)")
//                for photo in pexelsResponse.photos {
//                    downloadPhoto(from: photo.src.landscape, photographer: photo.photographer, to: pexelsFolder)
//                }
//
//                // Use pexelsResponse here
//            } catch {
//                print("Error decoding JSON: \(error)")
//            }
//        }
//    }
//
//    task.resume()
//}
