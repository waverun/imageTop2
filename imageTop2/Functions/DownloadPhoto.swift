import Foundation

func downloadPhoto(from urlString: String, photographer: String, to folder: URL, onComplete: @escaping (Bool) -> Void) {
    guard let url = URL(string: urlString) else {
        iPrint("Invalid URL: \(urlString)")
        onComplete(false)
        return
    }

    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            iPrint("Error downloading photo: \(error.localizedDescription)")
            onComplete(false)
            return
        }

        if let statusCode = (response as? HTTPURLResponse)?.statusCode,
           !(200...299).contains(statusCode) {
            iPrint("Error downloading photo: HTTP \(statusCode)")
            onComplete(false)
            return
        }

        guard let data = data,
              !data.isEmpty else {
            iPrint("Error downloading photo: empty response body")
            onComplete(false)
            return
        }

        let sanitizedPhotographerName = sanitizeFileName(photographer)
        let filename = "\(sanitizedPhotographerName)_\(UUID().uuidString).jpg"
        let fileURL = folder.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            iPrint("Saved photo to: \(fileURL)")
            onComplete(true)
        } catch {
            iPrint("Error saving photo: \(error.localizedDescription)")
            onComplete(false)
        }
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
