import Foundation

func clearFolder(folderPath: String) {
    do {
        let directoryURL = URL(fileURLWithPath: folderPath)
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
        for fileURL in contents {
            try fileManager.removeItem(at: fileURL)
        }
    } catch {
        // Handle the error.
        print("Error clearing directory: \(error)")
    }
}
