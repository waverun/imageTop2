import Foundation

func deleteFile(at fileURL: URL) {
    let fileManager = FileManager.default

    do {
        try fileManager.removeItem(at: fileURL)
        print("File deleted successfully.")
    } catch {
        print("Error deleting file: \(error.localizedDescription)")
    }
}
