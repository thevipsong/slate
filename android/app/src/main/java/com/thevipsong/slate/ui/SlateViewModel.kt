package com.thevipsong.slate.ui

import android.app.Application
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.thevipsong.slate.SlateApplication
import com.thevipsong.slate.data.SlateArchive
import com.thevipsong.slate.data.SlateThemeMode
import com.thevipsong.slate.data.SlateTodoItem
import com.thevipsong.slate.data.TodoFilter
import com.thevipsong.slate.sync.SupabaseConfiguration
import com.thevipsong.slate.sync.SupabaseHTTPClient
import com.thevipsong.slate.sync.SlateCloudDefaults
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

data class SlateUiState(
    val archive: SlateArchive = SlateArchive(),
    val selectedGroupID: String = "",
    val filter: TodoFilter = TodoFilter.PENDING,
    val search: String = "",
    val selectedItemID: String? = null,
    val themeMode: SlateThemeMode = SlateThemeMode.DARK,
    val message: String? = null,
    val remindersEnabled: Boolean = false,
    val sync: SyncSettingsUiState = SyncSettingsUiState()
) {
    val groups get() = archive.groups.filterNot { it.isDeleted }.sortedBy { it.sortOrder }
    val visibleItems: List<SlateTodoItem>
        get() {
            val today = LocalDate.now()
            return archive.items.asSequence()
                .filterNot { it.isDeleted }
                .filter { it.groupID == selectedGroupID }
                .filter { item ->
                    when (filter) {
                        TodoFilter.ALL -> true
                        TodoFilter.PENDING -> !item.isCompleted
                        TodoFilter.COMPLETED -> item.isCompleted
                        TodoFilter.OVERDUE -> !item.isCompleted && item.dueDate
                            ?.atZone(ZoneId.systemDefault())
                            ?.toLocalDate()
                            ?.isBefore(today) == true
                    }
                }
                .filter { search.isBlank() || it.title.contains(search.trim(), ignoreCase = true) }
                .sortedWith(
                    compareBy<SlateTodoItem> { it.sortOrder ?: Double.MAX_VALUE }
                        .thenBy { it.createdAt }
                )
                .toList()
        }
    val totalCount get() = archive.items.count { !it.isDeleted }
    val pendingCount get() = archive.items.count { !it.isDeleted && !it.isCompleted }
}

data class SyncSettingsUiState(
    val projectURL: String = "",
    val publishableKey: String = "",
    val accountEmail: String? = null,
    val isSyncing: Boolean = false,
    val lastSyncedAt: Instant = Instant.EPOCH
) {
    val isConfigured: Boolean
        get() = SupabaseConfiguration(projectURL, publishableKey).isAllowedEndpoint &&
            publishableKey.isNotBlank()
    val isSignedIn: Boolean get() = accountEmail != null
}

class SlateViewModel(application: Application) : AndroidViewModel(application) {
    private val app = application as SlateApplication
    private val repository = app.repository
    private val preferences = application.getSharedPreferences("slate_preferences", 0)
    private val selectedGroupID = MutableStateFlow(repository.archive.value.groups.first().id)
    private val filter = MutableStateFlow(TodoFilter.PENDING)
    private val search = MutableStateFlow("")
    private val selectedItemID = MutableStateFlow<String?>(null)
    private val themeMode = MutableStateFlow(
        runCatching {
            SlateThemeMode.valueOf(
                preferences.getString("theme_mode", SlateThemeMode.DARK.name)
                    ?: SlateThemeMode.DARK.name
            )
        }.getOrDefault(SlateThemeMode.DARK)
    )
    private val message = MutableStateFlow<String?>(null)
    private val remindersEnabled = MutableStateFlow(app.reminderScheduler.isEnabled)
    private var autoSyncJob: Job? = null
    private val syncSettings = MutableStateFlow(
        SyncSettingsUiState(
            projectURL = preferences.getString(
                "sync_project_url",
                SlateCloudDefaults.PROJECT_URL
            ).orEmpty(),
            publishableKey = preferences.getString(
                "sync_publishable_key",
                SlateCloudDefaults.PUBLISHABLE_KEY
            ).orEmpty(),
            accountEmail = app.sessionStore.load()?.email,
            lastSyncedAt = app.syncStateStore.load().lastSyncedAt
        )
    )

    val uiState: StateFlow<SlateUiState> = combine(
        repository.archive,
        selectedGroupID,
        filter,
        search,
        selectedItemID,
        themeMode,
        message,
        remindersEnabled,
        syncSettings
    ) { values ->
        @Suppress("UNCHECKED_CAST")
        SlateUiState(
            archive = values[0] as SlateArchive,
            selectedGroupID = values[1] as String,
            filter = values[2] as TodoFilter,
            search = values[3] as String,
            selectedItemID = values[4] as String?,
            themeMode = values[5] as SlateThemeMode,
            message = values[6] as String?,
            remindersEnabled = values[7] as Boolean,
            sync = values[8] as SyncSettingsUiState
        )
    }.stateIn(
        viewModelScope,
        SharingStarted.WhileSubscribed(5_000),
        SlateUiState(
            archive = repository.archive.value,
            selectedGroupID = selectedGroupID.value,
            remindersEnabled = remindersEnabled.value,
            sync = syncSettings.value
        )
    )

    init {
        viewModelScope.launch {
            repository.archive.collect { archive ->
                if (archive.groups.none { it.id == selectedGroupID.value }) {
                    selectedGroupID.value = archive.groups.first().id
                }
                app.reminderScheduler.sync(archive.items)
            }
        }
    }

    fun selectGroup(id: String) {
        selectedGroupID.value = id
        selectedItemID.value = null
    }

    fun setFilter(value: TodoFilter) {
        filter.value = value
        selectedItemID.value = null
    }

    fun setSearch(value: String) {
        search.value = value
    }

    fun selectTodo(id: String) {
        selectedItemID.value = if (selectedItemID.value == id) null else id
    }

    fun setTheme(value: SlateThemeMode) {
        themeMode.value = value
        preferences.edit().putString("theme_mode", value.name).apply()
    }

    fun addTodo(title: String, dueDate: Instant?) = launchMutation {
        repository.addTodo(title, selectedGroupID.value, dueDate)
    }

    fun toggleTodo(id: String) = launchMutation { repository.toggleTodo(id) }
    fun renameTodo(id: String, title: String) = launchMutation { repository.renameTodo(id, title) }
    fun setDueDate(id: String, date: Instant?) = launchMutation { repository.setDueDate(id, date) }
    fun deleteTodo(id: String) = launchMutation {
        repository.deleteTodo(id)
        selectedItemID.value = null
    }
    fun moveTodo(id: String, groupID: String) = launchMutation {
        repository.moveTodo(id, groupID)
        selectedItemID.value = null
    }
    fun reorderTodo(sourceID: String, targetID: String) =
        launchMutation { repository.reorderTodo(sourceID, targetID) }
    fun addGroup(name: String) = launchMutation { repository.addGroup(name) }
    fun renameGroup(id: String, name: String) = launchMutation {
        repository.renameGroup(id, name)
    }
    fun deleteGroup(id: String) = launchMutation { repository.deleteGroup(id) }

    fun setRemindersEnabled(enabled: Boolean) {
        app.reminderScheduler.isEnabled = enabled
        remindersEnabled.value = enabled
        app.reminderScheduler.sync(repository.archive.value.items)
    }

    fun configureAndAuthenticateSync(
        projectURL: String,
        publishableKey: String,
        email: String,
        password: String,
        createAccount: Boolean
    ) {
        val configuration = SupabaseConfiguration(projectURL, publishableKey)
        if (!configuration.isAllowedEndpoint) {
            message.value = "Supabase 项目地址无效；正式版本必须使用 https://。"
            return
        }
        if (publishableKey.isBlank() || email.isBlank() || password.length < 6) {
            message.value = "请填写 publishable key、邮箱和至少 6 位密码。"
            return
        }
        syncSettings.value = syncSettings.value.copy(isSyncing = true)
        viewModelScope.launch {
            try {
                val client = SupabaseHTTPClient(configuration)
                val session = if (createAccount) {
                    client.signUp(email, password)
                } else {
                    client.signIn(email, password)
                }
                preferences.edit()
                    .putString("sync_project_url", configuration.normalizedURL)
                    .putString("sync_publishable_key", publishableKey.trim())
                    .apply()
                if (session == null) {
                    syncSettings.value = SyncSettingsUiState(
                        projectURL = configuration.normalizedURL,
                        publishableKey = publishableKey.trim()
                    )
                    message.value = "注册成功，请先查收验证邮件，再返回登录。"
                } else {
                    app.sessionStore.save(session)
                    syncSettings.value = syncSettings.value.copy(
                        projectURL = configuration.normalizedURL,
                        publishableKey = publishableKey.trim(),
                        accountEmail = session.email,
                        isSyncing = false
                    )
                    message.value = "同步账户已登录。"
                    syncNow()
                }
            } catch (error: Throwable) {
                syncSettings.value = syncSettings.value.copy(isSyncing = false)
                message.value = error.message ?: "同步账户操作失败。"
            }
        }
    }

    fun syncNow() {
        val current = syncSettings.value
        if (!current.isConfigured || !current.isSignedIn) {
            message.value = "请先配置并登录同步账户。"
            return
        }
        if (current.isSyncing) return
        syncSettings.value = current.copy(isSyncing = true)
        viewModelScope.launch {
            try {
                val outcome = app.syncCoordinator.sync(
                    SupabaseConfiguration(current.projectURL, current.publishableKey)
                )
                syncSettings.value = syncSettings.value.copy(
                    isSyncing = false,
                    lastSyncedAt = outcome.syncedAt
                )
                message.value = if (outcome.conflictCount == 0) {
                    "同步完成。"
                } else {
                    "同步完成，已自动处理 ${outcome.conflictCount} 处冲突。"
                }
            } catch (error: Throwable) {
                syncSettings.value = syncSettings.value.copy(isSyncing = false)
                message.value = error.message ?: "同步失败，请稍后重试。"
            }
        }
    }

    fun syncIfConfigured() {
        if (syncSettings.value.isConfigured && syncSettings.value.isSignedIn) {
            syncNow()
        }
    }

    fun signOutSync() {
        app.sessionStore.clear()
        app.syncStateStore.clearBaseline()
        syncSettings.value = syncSettings.value.copy(
            accountEmail = null,
            lastSyncedAt = Instant.EPOCH
        )
        message.value = "已退出同步账户，本地待办不会删除。"
    }

    fun importArchive(uri: Uri) {
        launchMutation(successMessage = "待办数据已导入") {
            getApplication<Application>().contentResolver.openInputStream(uri)?.use {
                repository.importFrom(it)
            } ?: error("无法打开所选文件。")
        }
    }

    fun exportArchive(uri: Uri) {
        launchMutation(successMessage = "备份已导出") {
            getApplication<Application>().contentResolver.openOutputStream(uri)?.use {
                repository.exportTo(it)
            } ?: error("无法写入所选文件。")
        }
    }

    fun clearMessage() {
        message.value = null
    }

    private fun launchMutation(
        successMessage: String? = null,
        block: suspend () -> Unit
    ) {
        viewModelScope.launch {
            try {
                block()
                if (successMessage != null) message.value = successMessage
                scheduleAutoSync()
            } catch (error: Throwable) {
                message.value = error.message ?: "操作失败，请重试。"
            }
        }
    }

    private fun scheduleAutoSync() {
        val current = syncSettings.value
        if (!current.isConfigured || !current.isSignedIn) return
        autoSyncJob?.cancel()
        autoSyncJob = viewModelScope.launch {
            delay(1_500)
            syncNow()
        }
    }
}
