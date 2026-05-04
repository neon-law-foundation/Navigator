import HTTPTypes
import OpenAPIRuntime

struct ConditionalAuthMiddleware: ServerMiddleware {
    let inner: any ServerMiddleware
    let unauthenticatedOperations: Set<String>

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        metadata: ServerRequestMetadata,
        operationID: String,
        next:
            @Sendable (HTTPRequest, HTTPBody?, ServerRequestMetadata) async throws -> (
                HTTPResponse, HTTPBody?
            )
    ) async throws -> (HTTPResponse, HTTPBody?) {
        if unauthenticatedOperations.contains(operationID) {
            return try await next(request, body, metadata)
        }
        return try await inner.intercept(
            request,
            body: body,
            metadata: metadata,
            operationID: operationID,
            next: next
        )
    }
}
