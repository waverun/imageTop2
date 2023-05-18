import Foundation

class DirectoryWatcher {
    var source: DispatchSourceFileSystemObject?

    init(directoryPath: String, onChange: @escaping () -> Void) {
        let fileDescriptor = open(directoryPath, O_EVTONLY)
        if fileDescriptor < 0 {
            fatalError("Failed to open path: \(directoryPath)")
        }

        let queue = DispatchQueue.global()
        source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .write, queue: queue)

        source?.setEventHandler {
            print("Directory contents changed.")
            onChange()
            // Handle the directory change (reload data, etc.)
        }

        source?.setCancelHandler {
            close(fileDescriptor)
        }

        source?.resume()
    }

    deinit {
        source?.cancel()
    }
}
