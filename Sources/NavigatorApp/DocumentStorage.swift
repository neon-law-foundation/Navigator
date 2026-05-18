import Foundation
import Vapor

/// Pluggable backend that persists a Document's raw bytes somewhere
/// addressable.
///
/// The default implementation writes to `NSTemporaryDirectory()` plus a
/// `navigator-uploads/` subdirectory and returns a `file:` URL that
/// callers stash on the matching `Blob.objectStorageUrl`. Production
/// swap-out (S3, etc.) plugs in by storing a different conformer at
/// `Application.documentStorage`.
public protocol DocumentStorage: Sendable {
    /// Writes `bytes` and returns a stable URL that can later be read
    /// back via ``read(url:)`` or removed via ``remove(url:)``.
    func write(_ bytes: ByteBuffer, suggestedFilename: String) async throws -> String

    /// Resolves a previously-stored URL back to its local filesystem
    /// path so the download route can stream it. Returns `nil` when the
    /// URL is not backed by this store (e.g. a real S3 URL from an
    /// upstream pipeline).
    func localPath(for url: String) -> String?

    /// Removes the underlying file, if any. Tolerates missing files —
    /// the goal is the post-condition that the bytes are gone.
    func remove(url: String) async throws
}

/// Disk-backed default that stashes uploads under `NSTemporaryDirectory()`.
///
/// `prefix:` defaults to `"file:"` so the rendered URL is visually
/// distinct from an S3 URL and the download route can sniff which
/// backend owns the bytes.
public struct LocalDocumentStorage: DocumentStorage {
    public let directory: String
    public let prefix: String

    public init(directory: String? = nil, prefix: String = "file:") {
        self.directory = directory ?? (NSTemporaryDirectory() + "navigator-uploads/")
        self.prefix = prefix
    }

    public func write(_ bytes: ByteBuffer, suggestedFilename _: String) async throws -> String {
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )
        let id = UUID().uuidString
        let path = directory + id
        let data = Data(buffer: bytes)
        try data.write(to: URL(fileURLWithPath: path))
        return "\(prefix)\(path)"
    }

    public func localPath(for url: String) -> String? {
        guard url.hasPrefix(prefix) else { return nil }
        return String(url.dropFirst(prefix.count))
    }

    public func remove(url: String) async throws {
        guard let path = localPath(for: url) else { return }
        try? FileManager.default.removeItem(atPath: path)
    }
}

struct DocumentStorageKey: StorageKey {
    typealias Value = any DocumentStorage
}

extension Application {
    /// The ``DocumentStorage`` admin document uploads write through.
    /// Defaults to ``LocalDocumentStorage`` so tests don't need to wire
    /// anything in; production runs that swap to S3 install a different
    /// conformer here.
    public var documentStorage: any DocumentStorage {
        get { storage[DocumentStorageKey.self] ?? LocalDocumentStorage() }
        set { storage[DocumentStorageKey.self] = newValue }
    }
}
