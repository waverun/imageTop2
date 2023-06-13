import Foundation

func writeFile(directoryURL: URL, fileName: String, contents: String) {
//    let directoryURL = URL(fileURLWithPath: directory)
    let fileURL = directoryURL.appendingPathComponent(fileName)

    do {
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        print("File is written successfully")
    } catch {
        print("Error writing file: \(error)")
    }
}
