import Foundation

func deleteFile(at fileURL: URL) {
    let fileManager = FileManager.default

    do {
        try fileManager.removeItem(at: fileURL)
        iPrint("File deleted successfully.")
    } catch {
        iPrint("Error deleting file: \(error.localizedDescription)")
    }
}
