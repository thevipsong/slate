import Foundation

struct SupabaseHTTPClient: Sendable {
    let configuration: SupabaseConfiguration

    func signIn(email: String, password: String) async throws -> StoredSupabaseSession {
        let response: SupabaseSessionResponse = try await post(
            path: "/auth/v1/token?grant_type=password",
            body: EmailPasswordRequest(email: email, password: password),
            accessToken: nil
        )
        return try storedSession(from: response)
    }

    func signUp(email: String, password: String) async throws -> StoredSupabaseSession? {
        let response: SupabaseSessionResponse = try await post(
            path: "/auth/v1/signup",
            body: EmailPasswordRequest(email: email, password: password),
            accessToken: nil
        )
        guard response.accessToken != nil else { return nil }
        return try storedSession(from: response)
    }

    func refresh(_ session: StoredSupabaseSession) async throws -> StoredSupabaseSession {
        let response: SupabaseSessionResponse = try await post(
            path: "/auth/v1/token?grant_type=refresh_token",
            body: RefreshRequest(refreshToken: session.refreshToken),
            accessToken: nil
        )
        return try storedSession(from: response)
    }

    func sync(
        session: StoredSupabaseSession,
        expectedRevision: Int64,
        archive: TodoArchive,
        deviceID: String
    ) async throws -> SlateCloudSyncRecord {
        let records: [SlateCloudSyncRecord] = try await post(
            path: "/rest/v1/rpc/sync_slate_archive",
            body: SyncRPCRequest(
                expectedRevision: expectedRevision,
                newArchive: archive,
                newDeviceID: deviceID
            ),
            accessToken: session.accessToken
        )
        guard let record = records.single else {
            throw SyncNetworkError(message: "同步服务没有返回有效记录。")
        }
        return record
    }

    private func post<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        path: String,
        body: Body,
        accessToken: String?
    ) async throws -> Response {
        guard let baseURL = configuration.normalizedURL,
              configuration.isAllowedEndpoint,
              !configuration.publishableKey.isEmpty,
              let url = URL(string: path, relativeTo: baseURL) else {
            throw SyncNetworkError(message: "Supabase 项目配置无效。")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SyncNetworkError(message: "同步服务响应无效。")
        }
        guard (200..<300).contains(http.statusCode) else {
            let payload = try? JSONDecoder().decode(SupabaseError.self, from: data)
            throw SyncNetworkError(
                message: payload?.message
                    ?? payload?.errorDescription
                    ?? "同步服务请求失败（HTTP \(http.statusCode)）。"
            )
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Response.self, from: data)
    }

    private func storedSession(
        from response: SupabaseSessionResponse
    ) throws -> StoredSupabaseSession {
        guard let token = response.accessToken,
              let refresh = response.refreshToken,
              let user = response.user else {
            throw SyncNetworkError(message: "登录成功但没有返回完整会话。")
        }
        return StoredSupabaseSession(
            accessToken: token,
            refreshToken: refresh,
            userID: user.id,
            email: user.email,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn ?? 3_600))
        )
    }
}

private struct EmailPasswordRequest: Encodable, Sendable {
    let email: String
    let password: String
}

private struct RefreshRequest: Encodable, Sendable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

private struct SyncRPCRequest: Encodable, Sendable {
    let expectedRevision: Int64
    let newArchive: TodoArchive
    let newDeviceID: String

    enum CodingKeys: String, CodingKey {
        case expectedRevision = "expected_revision"
        case newArchive = "new_archive"
        case newDeviceID = "new_device_id"
    }
}

private struct SupabaseError: Decodable {
    let message: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case message
        case errorDescription = "error_description"
    }
}

private struct SyncNetworkError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private extension Collection {
    var single: Element? { count == 1 ? first : nil }
}
