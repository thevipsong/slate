import Foundation

struct SupabaseConfiguration: Codable, Equatable, Sendable {
    let projectURL: String
    let publishableKey: String

    var normalizedURL: URL? {
        URL(string: projectURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    var isAllowedEndpoint: Bool {
        guard let url = normalizedURL, let host = url.host else { return false }
        if url.scheme == "https" {
            return true
        }
#if DEBUG
        return url.scheme == "http"
            && ["127.0.0.1", "localhost"].contains(host)
#else
        return false
#endif
    }
}

struct SupabaseUser: Codable, Equatable, Sendable {
    let id: String
    let email: String?
}

struct SupabaseSessionResponse: Codable, Sendable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let user: SupabaseUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }
}

struct StoredSupabaseSession: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let userID: String
    let email: String?
    let expiresAt: Date
}

struct SlateCloudSyncRecord: Decodable, Sendable {
    let accepted: Bool
    let revision: Int64
    let archive: TodoArchive
    let deviceID: String
    let updatedAtRaw: String

    var updatedAt: Date {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: updatedAtRaw) {
            return date
        }
        return ISO8601DateFormatter().date(from: updatedAtRaw) ?? .distantPast
    }

    enum CodingKeys: String, CodingKey {
        case accepted
        case revision
        case archive
        case deviceID = "device_id"
        case updatedAtRaw = "updated_at"
    }
}

struct SlateLocalSyncState: Codable, Equatable, Sendable {
    var baseArchive: TodoArchive?
    var remoteRevision: Int64
    let deviceID: String
    var localModifiedAt: Date
    var lastSyncedAt: Date

    init(
        baseArchive: TodoArchive? = nil,
        remoteRevision: Int64 = 0,
        deviceID: String = UUID().uuidString,
        localModifiedAt: Date = .distantPast,
        lastSyncedAt: Date = .distantPast
    ) {
        self.baseArchive = baseArchive
        self.remoteRevision = remoteRevision
        self.deviceID = deviceID
        self.localModifiedAt = localModifiedAt
        self.lastSyncedAt = lastSyncedAt
    }
}

struct SlateSyncOutcome: Equatable, Sendable {
    let archive: TodoArchive
    let revision: Int64
    let conflictCount: Int
    let syncedAt: Date
}
