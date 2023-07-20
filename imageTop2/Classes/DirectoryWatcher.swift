import Foundation

enum DirectoryWatcherError: Error {
    case unableToOpenDirectory(String)
}

class DirectoryWatcher {
    var source: DispatchSourceFileSystemObject?

    init(directoryPath: String, onChange: @escaping () -> Void) throws {
        let fileDescriptor = open(directoryPath, O_EVTONLY)
        if fileDescriptor < 0 {
            throw DirectoryWatcherError.unableToOpenDirectory(directoryPath)
        }

        let queue = DispatchQueue.global()
        source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .write, queue: queue)

        source?.setEventHandler {
            iPrint("Directory contents changed.")
            onChange()
        }

        source?.setCancelHandler {
            close(fileDescriptor)
        }

        source?.resume()
    }

    func release() {
        source?.cancel()
    }

    deinit {
        release()
    }
}
