import Elementary
import Hummingbird

/// A streaming HTML writer that bridges Elementary's rendering pipeline to
/// Hummingbird's response body writer.
public struct HTMLResponseBodyWriter: HTMLStreamWriter {
    public mutating func write(_ bytes: ArraySlice<UInt8>) async throws {
        try await writer.write(allocator.buffer(bytes: bytes))
    }

    public var allocator: ByteBufferAllocator
    public var writer: any ResponseBodyWriter
}

extension HTML where Self: Sendable {
    /// Converts this HTML value into a Hummingbird `Response` with a
    /// `text/html; charset=utf-8` content type.
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        .init(
            status: .ok,
            headers: [.contentType: "text/html; charset=utf-8"],
            body: .init { [self] writer in
                try await self.render(
                    into: HTMLResponseBodyWriter(
                        allocator: ByteBufferAllocator(),
                        writer: writer
                    )
                )
                try await writer.finish(nil)
            }
        )
    }
}
