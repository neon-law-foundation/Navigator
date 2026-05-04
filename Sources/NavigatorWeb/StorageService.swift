import Foundation
import SotoS3

/// Manages object storage via AWS S3.
///
/// Uses `AWS_ENDPOINT_URL` when set to route requests to LocalStack for local development.
/// Pass an empty `bucketURL` to disable storage operations (health check returns false).
actor StorageService {
    private var s3: S3?
    private var awsClient: AWSClient?
    private let bucketURL: String

    init(bucketURL: String) {
        self.bucketURL = bucketURL
    }

    private func connect() async throws {
        guard s3 == nil else { return }
        let endpoint = ProcessInfo.processInfo.environment["AWS_ENDPOINT_URL"]
        let client = AWSClient()
        self.awsClient = client
        self.s3 = S3(client: client, endpoint: endpoint)
    }

    func healthCheck() async throws -> Bool {
        guard !bucketURL.isEmpty else { return false }
        try await connect()
        guard let s3 else { return false }
        guard let bucketName = URL(string: bucketURL)?.host else { return false }
        let request = S3.HeadBucketRequest(bucket: bucketName)
        do {
            _ = try await s3.headBucket(request)
            return true
        } catch {
            return false
        }
    }

    func shutdown() async throws {
        self.s3 = nil
        if let client = awsClient {
            try await client.shutdown()
            self.awsClient = nil
        }
    }
}

enum StorageError: Error {
    case notConfigured
}
