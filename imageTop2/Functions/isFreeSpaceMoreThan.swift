import Foundation

func isFreeSpaceMoreThan(gigabytes: Double) -> Bool {
    do {
        let fileSystemAttributes = try FileManager.default.attributesOfFileSystem(forPath: "/")
        if let freeSpace = fileSystemAttributes[.systemFreeSize] as? NSNumber {
            let freeSpaceInGigabytes = Double(truncating: freeSpace) / 1_000_000_000 // 1 GB = 1_000_000_000 bytes
            return freeSpaceInGigabytes > gigabytes
        }
    } catch {
        debugPrint("Error retrieving system free size: \(error)")
    }
    return false
}
