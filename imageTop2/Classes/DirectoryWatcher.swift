import Foundation

enum DirectoryWatcherError: Error {
    case unableToOpenDirectory(path: String, errnoCode: Int32)
}

extension DirectoryWatcherError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unableToOpenDirectory(let path, let errnoCode):
            let systemMessage = String(cString: strerror(errnoCode))
            return "Unable to open directory '\(path)'. errno \(errnoCode): \(systemMessage)"
        }
    }
}

class DirectoryWatcher {
    var source: DispatchSourceFileSystemObject?

    init(directoryPath: String, onChange: @escaping () -> Void) throws {
        let fileDescriptor = open(directoryPath, O_EVTONLY)
        if fileDescriptor < 0 {
            let errorCode = errno
            throw DirectoryWatcherError.unableToOpenDirectory(path: directoryPath, errnoCode: errorCode)
        }

        let queue = DispatchQueue.global()
        source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .write, queue: queue)

        source?.setEventHandler {
            onChange()
        }

        source?.setCancelHandler {
            close(fileDescriptor)
        }

        source?.resume()
    }

    func release() {
        source?.cancel()
        source = nil
    }

    deinit {
        release()
    }
}
