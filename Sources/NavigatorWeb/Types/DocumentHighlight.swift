/// A character offset range into a `WorkshopFile`'s inlined content.
///
/// `DocumentViewer` slices the file's `content` using the half-open
/// `[start, end)` interval and renders each snippet inline in a
/// "Highlighted Passages" sidebar. Offsets are clamped to valid range at
/// render time so callers can surface API-supplied offsets without
/// pre-validating them.
///
/// Highlights are ignored for PDFs because iframe content is not
/// addressable by offset; callers should pass an empty array or `nil` in
/// that case.
///
/// Introduced in Milestone 2 of the pure-Swift web stack migration
/// (sagebrush-services/AWS#112) when porting `DocumentViewer` from the
/// archived NLF/WebComponents React library.
public struct DocumentHighlight: Sendable, Equatable, Codable {
    /// Inclusive start offset into the file's content string.
    public let start: Int

    /// Exclusive end offset into the file's content string.
    public let end: Int

    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }
}
