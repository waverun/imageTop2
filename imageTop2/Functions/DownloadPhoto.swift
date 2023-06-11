import Foundation

func downloadPhoto(from urlString: String, photographer: String, to folder: URL) {
    guard let url = URL(string: urlString) else {
        print("Invalid URL: \(urlString)")
        return
    }

    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            print("Error downloading photo: \(error)")
        } else if let data = data {
            // Generate a unique filename based on the photographer's name
            let sanitizedPhotographerName = sanitizeFileName(photographer)
            let filename = "\(sanitizedPhotographerName)_\(UUID().uuidString).jpg"
            let fileURL = folder.appendingPathComponent(filename)

            do {
                try data.write(to: fileURL)
                print("Saved photo to: \(fileURL)")
            } catch {
                print("Error saving photo: \(error)")
            }
        }
    }

    task.resume()
}
