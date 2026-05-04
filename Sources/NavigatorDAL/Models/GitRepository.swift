import FluentKit
import Foundation

/// Represents an AWS CodeCommit Git repository that stores notation templates
public final class GitRepository: Model, @unchecked Sendable {
    public static let schema = "git_repositories"

    @ID(key: .id)
    public var id: UUID?

    /// AWS Account ID (12-digit number as string)
    @Field(key: "aws_account_id")
    public var awsAccountID: String

    /// AWS Region (e.g., "us-west-2")
    @Field(key: "aws_region")
    public var awsRegion: String

    /// CodeCommit repository ID (UUID format)
    @Field(key: "codecommit_repository_id")
    public var codecommitRepositoryID: String

    /// CodeCommit repository name (human-readable)
    @Field(key: "repository_name")
    public var repositoryName: String

    /// CodeCommit repository ARN
    @Field(key: "repository_arn")
    public var repositoryARN: String

    /// The project this repository belongs to
    @Parent(key: "project_id")
    public var project: Project

    /// Optional description
    @OptionalField(key: "description")
    public var description: String?

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(
        awsAccountID: String,
        awsRegion: String,
        codecommitRepositoryID: String,
        repositoryName: String,
        repositoryARN: String,
        description: String? = nil
    ) {
        self.awsAccountID = awsAccountID
        self.awsRegion = awsRegion
        self.codecommitRepositoryID = codecommitRepositoryID
        self.repositoryName = repositoryName
        self.repositoryARN = repositoryARN
        self.description = description
    }
}
