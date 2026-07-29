package com.thevipsong.slate.sync

import com.thevipsong.slate.data.SlateArchiveCodec
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import java.net.HttpURLConnection
import java.net.URI
import java.time.Instant

class SupabaseHTTPClient(
    private val configuration: SupabaseConfiguration
) {
    suspend fun signIn(email: String, password: String): StoredSupabaseSession {
        val body = SlateArchiveCodec.json.encodeToString(
            EmailPasswordRequest(email.trim(), password)
        )
        val response = request(
            method = "POST",
            path = "/auth/v1/token?grant_type=password",
            body = body
        )
        return response.toStoredSession()
    }

    suspend fun signUp(email: String, password: String): StoredSupabaseSession? {
        val body = SlateArchiveCodec.json.encodeToString(
            EmailPasswordRequest(email.trim(), password)
        )
        val response = request(
            method = "POST",
            path = "/auth/v1/signup",
            body = body
        )
        return if (response.accessToken != null) response.toStoredSession() else null
    }

    suspend fun refresh(session: StoredSupabaseSession): StoredSupabaseSession {
        val body = SlateArchiveCodec.json.encodeToString(
            RefreshRequest(session.refreshToken)
        )
        val response = request(
            method = "POST",
            path = "/auth/v1/token?grant_type=refresh_token",
            body = body
        )
        return response.toStoredSession()
    }

    suspend fun sync(
        session: StoredSupabaseSession,
        expectedRevision: Long,
        archive: com.thevipsong.slate.data.SlateArchive,
        deviceID: String
    ): CloudSyncRecord {
        val body = SlateArchiveCodec.json.encodeToString(
            SyncRPCRequest(expectedRevision, archive, deviceID)
        )
        val raw = requestRaw(
            method = "POST",
            path = "/rest/v1/rpc/sync_slate_archive",
            body = body,
            accessToken = session.accessToken
        )
        return SlateArchiveCodec.json.decodeFromString<List<CloudSyncRecord>>(raw)
            .singleOrNull()
            ?: error("同步服务没有返回有效记录。")
    }

    suspend fun fetchArchive(
        session: StoredSupabaseSession
    ): CloudArchiveRecord? {
        val raw = requestRaw(
            method = "GET",
            path = "/rest/v1/slate_archives" +
                "?select=revision,archive,device_id,updated_at&limit=1",
            body = null,
            accessToken = session.accessToken
        )
        return SlateArchiveCodec.json.decodeFromString<List<CloudArchiveRecord>>(raw)
            .firstOrNull()
    }

    private suspend fun request(
        method: String,
        path: String,
        body: String
    ): SupabaseSessionResponse {
        val raw = requestRaw(method, path, body, accessToken = null)
        return SlateArchiveCodec.json.decodeFromString(raw)
    }

    private suspend fun requestRaw(
        method: String,
        path: String,
        body: String?,
        accessToken: String?
    ): String = withContext(Dispatchers.IO) {
        require(configuration.isAllowedEndpoint) {
            "同步服务地址无效；正式版本必须使用 HTTPS。"
        }
        require(configuration.publishableKey.isNotBlank()) {
            "缺少 Supabase publishable key。"
        }

        val connection = URI(configuration.normalizedURL + path)
            .toURL()
            .openConnection() as HttpURLConnection
        try {
            connection.requestMethod = method
            connection.connectTimeout = 15_000
            connection.readTimeout = 20_000
            connection.doOutput = body != null
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("apikey", configuration.publishableKey)
            if (accessToken != null) {
                connection.setRequestProperty("Authorization", "Bearer $accessToken")
            }
            if (body != null) {
                connection.outputStream.use { output ->
                    output.write(body.toByteArray(Charsets.UTF_8))
                }
            }

            val status = connection.responseCode
            val stream = if (status in 200..299) {
                connection.inputStream
            } else connection.errorStream
            val response = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (status !in 200..299) {
                val detail = runCatching {
                    SlateArchiveCodec.json.decodeFromString<SupabaseError>(response).message
                }.getOrNull()
                error(detail ?: "同步服务请求失败（HTTP $status）。")
            }
            response
        } finally {
            connection.disconnect()
        }
    }

    private fun SupabaseSessionResponse.toStoredSession(): StoredSupabaseSession {
        val token = requireNotNull(accessToken) { "登录成功但未返回访问令牌。" }
        val refresh = requireNotNull(refreshToken) { "登录成功但未返回刷新令牌。" }
        val account = requireNotNull(user) { "登录成功但未返回用户信息。" }
        return StoredSupabaseSession(
            accessToken = token,
            refreshToken = refresh,
            userID = account.id,
            email = account.email,
            expiresAtEpochSeconds = Instant.now().epochSecond + (expiresIn ?: 3_600)
        )
    }
}

@Serializable
private data class EmailPasswordRequest(
    val email: String,
    val password: String
)

@Serializable
private data class RefreshRequest(
    @kotlinx.serialization.SerialName("refresh_token")
    val refreshToken: String
)

@Serializable
private data class SupabaseError(
    val message: String? = null,
    @kotlinx.serialization.SerialName("error_description")
    val errorDescription: String? = null
)
