/// A file surfaced in a workshop — pleadings, contracts, correspondence,
/// statutes, prompts, etc.
///
/// `DocumentViewer` and `WorkshopFileSidebar` both consume this shape. The
/// optional `contentType` disambiguates how the viewer should render the
/// file; when omitted, the viewer falls back to name/url suffix detection.
public struct WorkshopFile: Sendable, Equatable, Codable {
    /// How `DocumentViewer` should render the file body.
    public enum ContentType: String, Sendable, Equatable, Codable {
        case text
        case markdown
        case pdf
    }

    /// Stable identifier for the file; used to match `activeFileId`.
    public let id: String

    /// Human-readable display name shown in the sidebar and viewer header.
    public let name: String

    /// Category label shown as a chip above the file name in the viewer.
    public let category: String

    /// Remote URL (e.g. S3 signed URL). Required for PDF rendering.
    public let url: String?

    /// Inlined content, if already fetched. Plain text or markdown source.
    public let content: String?

    /// Explicit render hint. Falls back to suffix detection when omitted.
    public let contentType: ContentType?

    public init(
        id: String,
        name: String,
        category: String,
        url: String? = nil,
        content: String? = nil,
        contentType: ContentType? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.url = url
        self.content = content
        self.contentType = contentType
    }
}
