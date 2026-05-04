import Testing

@testable import NavigatorWeb

@Suite("StorageService")
struct StorageServiceTests {

    @Test("healthCheck returns false when bucketURL is empty")
    func emptyBucketURLHealthCheckReturnsFalse() async throws {
        let service = StorageService(bucketURL: "")
        let result = try await service.healthCheck()
        #expect(result == false)
    }
}
