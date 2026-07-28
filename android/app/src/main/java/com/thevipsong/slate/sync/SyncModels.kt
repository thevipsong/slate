package com.thevipsong.slate.sync

import com.thevipsong.slate.BuildConfig
import com.thevipsong.slate.data.InstantIsoSerializer
import com.thevipsong.slate.data.SlateArchive
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.net.URI
import java.time.Instant
import java.util.UUID

@Serializable
data class SupabaseConfiguration(
    val projectURL: String,
    val publishableKey: String
) {
    val normalizedURL: String get() = projectURL.trim().trimEnd('/')

    val isAllowedEndpoint: Boolean
        get() {
            val uri = runCatching { URI(normalizedURL) }.getOrNull() ?: return false
            if (uri.scheme == "https" && !uri.host.isNullOrBlank()) return true
            return BuildConfig.DEBUG &&
                uri.scheme == "http" &&
                uri.host in setOf("127.0.0.1", "localhost", "10.0.2.2")
        }
}

@Serializable
data class SupabaseUser(
    val id: String,
    val email: String? = null
)

@Serializable
data class SupabaseSessionResponse(
    @SerialName("access_token")
    val accessToken: String? = null,
    @SerialName("refresh_token")
    val refreshToken: String? = null,
    @SerialName("expires_in")
    val expiresIn: Long? = null,
    val user: SupabaseUser? = null
)

@Serializable
data class StoredSupabaseSession(
    val accessToken: String,
    val refreshToken: String,
    val userID: String,
    val email: String? = null,
    val expiresAtEpochSeconds: Long
)

@Serializable
data class CloudSyncRecord(
    val accepted: Boolean,
    val revision: Long,
    val archive: SlateArchive,
    @SerialName("device_id")
    val deviceID: String,
    @Serializable(with = InstantIsoSerializer::class)
    @SerialName("updated_at")
    val updatedAt: Instant
)

@Serializable
data class SyncRPCRequest(
    @SerialName("expected_revision")
    val expectedRevision: Long,
    @SerialName("new_archive")
    val newArchive: SlateArchive,
    @SerialName("new_device_id")
    val newDeviceID: String
)

@Serializable
data class LocalSyncState(
    val baseArchive: SlateArchive? = null,
    val remoteRevision: Long = 0,
    val deviceID: String = UUID.randomUUID().toString(),
    @Serializable(with = InstantIsoSerializer::class)
    val localModifiedAt: Instant = Instant.EPOCH,
    @Serializable(with = InstantIsoSerializer::class)
    val lastSyncedAt: Instant = Instant.EPOCH
)

data class SyncOutcome(
    val revision: Long,
    val conflictCount: Int,
    val syncedAt: Instant
)
