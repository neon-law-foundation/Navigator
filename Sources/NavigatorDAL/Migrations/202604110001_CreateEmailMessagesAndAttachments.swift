import FluentKit
import SQLKit

struct CreateEmailMessagesAndAttachments: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(EmailMessage.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("message_id", .string, .required)
            .field("in_reply_to", .string)
            .field("references", .json, .required)
            .field("thread_id", .string, .required)
            .field("from_address", .string, .required)
            .field("from_name", .string)
            .field("to_address", .string, .required)
            .field("cc_addresses", .json, .required)
            .field("bcc_addresses", .json, .required)
            .field("subject", .string, .required)
            .field("text_body", .string)
            .field("html_body", .string)
            .field("raw_blob_id", .uuid, .references("blobs", "id"), .required)
            .field("spam_verdict", .string, .required)
            .field("virus_verdict", .string, .required)
            .field("dkim_verdict", .string, .required)
            .field("dmarc_verdict", .string, .required)
            .field("received_at", .datetime, .required)
            .field("acknowledged_at", .datetime)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "message_id")
            .create()

        try await database.schema(EmailAttachment.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("email_message_id", .uuid, .references("email_messages", "id"), .required)
            .field("blob_id", .uuid, .references("blobs", "id"), .required)
            .field("filename", .string, .required)
            .field("content_type", .string, .required)
            .field("size_bytes", .int64, .required)
            .field("content_id", .string)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .create()

        guard let sql = database as? SQLDatabase else { return }

        try await sql.raw(
            "CREATE INDEX email_messages_thread_id_idx ON email_messages (thread_id)"
        ).run()
        try await sql.raw(
            "CREATE INDEX email_messages_in_reply_to_idx ON email_messages (in_reply_to)"
        ).run()
        try await sql.raw(
            """
            CREATE INDEX email_messages_to_received_idx
            ON email_messages (to_address, received_at DESC)
            """
        ).run()
        try await sql.raw(
            "CREATE INDEX email_attachments_email_message_id_idx ON email_attachments (email_message_id)"
        ).run()

        let isPostgres = sql.dialect.name == "postgresql"
        guard isPostgres else { return }
        try await sql.raw(
            """
            CREATE INDEX email_messages_references_gin
            ON email_messages USING GIN ("references" jsonb_path_ops)
            """
        ).run()
    }

    func revert(on database: any Database) async throws {
        if let sql = database as? SQLDatabase {
            try await sql.raw("DROP INDEX IF EXISTS email_attachments_email_message_id_idx").run()
            try await sql.raw("DROP INDEX IF EXISTS email_messages_references_gin").run()
            try await sql.raw("DROP INDEX IF EXISTS email_messages_to_received_idx").run()
            try await sql.raw("DROP INDEX IF EXISTS email_messages_in_reply_to_idx").run()
            try await sql.raw("DROP INDEX IF EXISTS email_messages_thread_id_idx").run()
        }
        try await database.schema(EmailAttachment.schema).delete()
        try await database.schema(EmailMessage.schema).delete()
    }
}
