import Foundation

public enum ValidationError: Error, LocalizedError {
    case directoryNotAccessible(URL)
    case fileNotFound(URL)
    case invalidPath(String)
    case fixFailed(URL)

    public var errorDescription: String? {
        switch self {
        case .directoryNotAccessible(let url):
            return "Directory not accessible: \(url.path)"
        case .fileNotFound(let url):
            return "File not found: \(url.path)"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        case .fixFailed(let url):
            return "Failed to fix file: \(url.path)"
        }
    }
}
