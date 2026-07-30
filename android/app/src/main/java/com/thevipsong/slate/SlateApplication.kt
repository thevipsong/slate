package com.thevipsong.slate

import android.app.Application
import com.thevipsong.slate.data.SlateFileStore
import com.thevipsong.slate.data.SlateRepository
import com.thevipsong.slate.reminders.ReminderScheduler
import com.thevipsong.slate.sync.LocalSyncStateStore
import com.thevipsong.slate.sync.SecureSessionStore
import com.thevipsong.slate.sync.SlateSyncCoordinator
import com.thevipsong.slate.widget.SlateWidgetProvider

class SlateApplication : Application() {
    val syncStateStore: LocalSyncStateStore by lazy {
        LocalSyncStateStore(this)
    }

    val sessionStore: SecureSessionStore by lazy {
        SecureSessionStore(this)
    }

    val repository: SlateRepository by lazy {
        SlateRepository(
            store = SlateFileStore(this),
            onLocalChange = {
                syncStateStore.markLocalChange()
                SlateWidgetProvider.requestUpdate(this)
            }
        )
    }

    val syncCoordinator: SlateSyncCoordinator by lazy {
        SlateSyncCoordinator(repository, syncStateStore, sessionStore)
    }

    val reminderScheduler: ReminderScheduler by lazy {
        ReminderScheduler(this)
    }

    override fun onCreate() {
        super.onCreate()
        reminderScheduler.createNotificationChannel()
    }
}
