import Foundation

func downloadPhoto(from urlString: String, photographer: String, to folder: URL, onComplete: @escaping () -> Void) {
    guard let url = URL(string: urlString) else {
        iPrint("Invalid URL: \(urlString)")
        onComplete()
        return
    }

    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            iPrint("Error downloading photo: \(error)")
        } else if let data = data {
            // Generate a unique filename based on the photographer's name
            let sanitizedPhotographerName = sanitizeFileName(photographer)
            let filename = "\(sanitizedPhotographerName)_\(UUID().uuidString).jpg"
            let fileURL = folder.appendingPathComponent(filename)

            do {
                try data.write(to: fileURL)
                iPrint("Saved photo to: \(fileURL)")
            } catch {
                iPrint("Error saving photo: \(error)")
            }
        }
        onComplete()
    }

    task.resume()
}

//func downloadPhoto(from urlString: String, photographer: String, to folder: URL) {
//    guard let url = URL(string: urlString) else {
//        iPrint("Invalid URL: \(urlString)")
//        return
//    }
//
//    let task = URLSession.shared.dataTask(with: url) { data, response, error in
//        if let error = error {
//            iPrint("Error downloading photo: \(error)")
//        } else if let data = data {
//            // Generate a unique filename based on the photographer's name
//            let sanitizedPhotographerName = sanitizeFileName(photographer)
//            let filename = "\(sanitizedPhotographerName)_\(UUID().uuidString).jpg"
//            let fileURL = folder.appendingPathComponent(filename)
//
//            do {
//                try data.write(to: fileURL)
//                iPrint("Saved photo to: \(fileURL)")
//            } catch {
//                iPrint("Error saving photo: \(error)")
//            }
//        }
//    }
//
//    task.resume()
//}
