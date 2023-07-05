import Foundation

func writeFile(directoryURL: URL, fileName: String, contents: String) {
//    let directoryURL = URL(fileURLWithPath: directory)
    let fileURL = directoryURL.appendingPathComponent(fileName)

    do {
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        debugPrint("File is written successfully")
    } catch {
        debugPrint("Error writing file: \(error)")
    }
}
