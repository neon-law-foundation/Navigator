import Fluent
import FluentSQLiteDriver
import NavigatorDAL
import Testing
import Vapor

@Suite("GitRepository Database Operations")
struct GitRepositoryTests {

    @Test("GitRepository can be linked to a project")
    func testLinkToProject() async throws {
        try await withDatabase { db in
            let project = Project()
            project.codename = "alpha-\(UUID().uuidString.prefix(8))"
            try await project.save(on: db)

            let uid = UUID().uuidString
            let repo = GitRepository(
                awsAccountID: "123456789012",
                awsRegion: "us-west-2",
                codecommitRepositoryID: uid,
                repositoryName: "test-repo-\(uid.prefix(8))",
                repositoryARN: "arn:aws:codecommit:us-west-2:123456789012:\(uid.prefix(8))"
            )
            repo.$project.id = project.id!
            try await repo.save(on: db)

            let loaded = try await GitRepository.find(repo.id, on: db)
            #expect(loaded?.$project.id == project.id)
        }
    }

    @Test("Two repositories cannot share the same project and aws_account_id")
    func testUniqueConstraintPerProjectAndAccount() async throws {
        try await withDatabase { db in
            let project = Project()
            project.codename = "beta-\(UUID().uuidString.prefix(8))"
            try await project.save(on: db)

            let uid1 = UUID().uuidString
            let repo1 = GitRepository(
                awsAccountID: "123456789012",
                awsRegion: "us-west-2",
                codecommitRepositoryID: uid1,
                repositoryName: "repo-1-\(uid1.prefix(8))",
                repositoryARN: "arn:aws:codecommit:us-west-2:123456789012:\(uid1.prefix(8))"
            )
            repo1.$project.id = project.id!
            try await repo1.save(on: db)

            let uid2 = UUID().uuidString
            let repo2 = GitRepository(
                awsAccountID: "123456789012",
                awsRegion: "us-west-2",
                codecommitRepositoryID: uid2,
                repositoryName: "repo-2-\(uid2.prefix(8))",
                repositoryARN: "arn:aws:codecommit:us-west-2:123456789012:\(uid2.prefix(8))"
            )
            repo2.$project.id = project.id!

            await #expect(throws: (any Error).self) {
                try await repo2.save(on: db)
            }
        }
    }

    @Test("Same project can have repositories in different accounts")
    func testDifferentAccountsAllowed() async throws {
        try await withDatabase { db in
            let project = Project()
            project.codename = "gamma-\(UUID().uuidString.prefix(8))"
            try await project.save(on: db)

            let uid1 = UUID().uuidString
            let stagingRepo = GitRepository(
                awsAccountID: "889786867297",
                awsRegion: "us-west-2",
                codecommitRepositoryID: uid1,
                repositoryName: "repo-staging-\(uid1.prefix(8))",
                repositoryARN: "arn:aws:codecommit:us-west-2:889786867297:\(uid1.prefix(8))"
            )
            stagingRepo.$project.id = project.id!
            try await stagingRepo.save(on: db)

            let uid2 = UUID().uuidString
            let productionRepo = GitRepository(
                awsAccountID: "978489150794",
                awsRegion: "us-west-2",
                codecommitRepositoryID: uid2,
                repositoryName: "repo-prod-\(uid2.prefix(8))",
                repositoryARN: "arn:aws:codecommit:us-west-2:978489150794:\(uid2.prefix(8))"
            )
            productionRepo.$project.id = project.id!
            try await productionRepo.save(on: db)

            let repos = try await project.$gitRepositories.query(on: db).all()
            #expect(repos.count == 2)
        }
    }
}
