import Foundation

func deleteFile(at fileURL: URL) {
    let fileManager = FileManager.default

    do {
        try fileManager.removeItem(at: fileURL)
        debugPrint("File deleted successfully.")
    } catch {
        debugPrint("Error deleting file: \(error.localizedDescription)")
    }
}
