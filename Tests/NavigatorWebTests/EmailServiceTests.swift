import Testing

@testable import NavigatorWeb

@Suite("EmailService")
struct EmailServiceTests {

    @Test("EmailService initializes")
    func initializes() {
        let service = EmailService()
        _ = service
    }
}
