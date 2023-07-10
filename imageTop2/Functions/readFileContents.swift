import Foundation

func readFileContents(atPath path: String) -> String? {
    do {
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        return contents
    } catch {
        iPrint("Error reading file: \(error)")
        return nil
    }
}
