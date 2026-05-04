import Elementary

/// Full workshop three-pane layout: `WorkshopFileSidebar` on the left,
/// `DocumentViewer` in the middle, `ChatInterface` on the right.
///
/// The workspace is a pure composition — it does not own any state
/// itself. Callers pass the files to list, the currently active file id,
/// the optional highlights, the chat message history, and the HTMX
/// `sendPath`; the workspace wires them through to its three children
/// and emits a flex-row grid. Active file selection flows through
/// `WorkshopFileSidebar`, which renders `\(filesBasePath)?file=\(id)`
/// anchors so selection travels over a full-page navigation (or an HTMX
/// swap wired by the caller at a higher level).
///
/// `ProjectSidebar` — which lists projects — is intentionally not
/// composed here; this component lives one level below that in the
/// workshop view hierarchy. A caller that wants both renders
/// `ProjectSidebar` outside the workspace and the workspace inside the
/// content column.
public struct WorkshopWorkspace: HTML {
    public let brandColor: String
    public let files: [WorkshopFile]
    public let activeFileId: String?
    public let filesBasePath: String
    public let highlights: [DocumentHighlight]
    public let contextFileIds: [String]
    public let messages: [ChatMessage]
    public let sendPath: String
    public let chatDisabled: Bool

    public init(
        brandColor: String,
        files: [WorkshopFile],
        activeFileId: String?,
        filesBasePath: String,
        highlights: [DocumentHighlight] = [],
        contextFileIds: [String],
        messages: [ChatMessage],
        sendPath: String,
        chatDisabled: Bool = false
    ) {
        self.brandColor = brandColor
        self.files = files
        self.activeFileId = activeFileId
        self.filesBasePath = filesBasePath
        self.highlights = highlights
        self.contextFileIds = contextFileIds
        self.messages = messages
        self.sendPath = sendPath
        self.chatDisabled = chatDisabled
    }

    private var activeFile: WorkshopFile? {
        guard let activeFileId else { return nil }
        return files.first { $0.id == activeFileId }
    }

    public var body: some HTML {
        div(
            .class("workshop-workspace flex h-full w-full overflow-hidden bg-gray-50")
        ) {
            WorkshopFileSidebar(
                files: files,
                activeFileId: activeFileId,
                basePath: filesBasePath,
                brandColor: brandColor
            )
            DocumentViewer(
                brandColor: brandColor,
                file: activeFile,
                highlights: highlights
            )
            div(.class("w-96 border-l border-gray-200 flex-shrink-0")) {
                ChatInterface(
                    brandColor: brandColor,
                    contextFileIds: contextFileIds,
                    messages: messages,
                    sendPath: sendPath,
                    disabled: chatDisabled
                )
            }
        }
    }
}
