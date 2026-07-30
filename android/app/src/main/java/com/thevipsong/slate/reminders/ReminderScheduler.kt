package com.thevipsong.slate.reminders

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.edit
import androidx.core.content.ContextCompat
import com.thevipsong.slate.MainActivity
import com.thevipsong.slate.R
import com.thevipsong.slate.SlateApplication
import com.thevipsong.slate.data.SlateTodoItem
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class ReminderScheduler(private val context: Context) {
    private val alarmManager = context.getSystemService(AlarmManager::class.java)
    private val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    var isEnabled: Boolean
        get() = preferences.getBoolean(KEY_ENABLED, false)
        set(value) = preferences.edit { putBoolean(KEY_ENABLED, value) }

    fun createNotificationChannel() {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "到期提醒",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "在待办到期当天上午 9 点提醒"
            }
        )
    }

    fun sync(items: List<SlateTodoItem>) {
        val existing = preferences
            .getStringSet(KEY_SCHEDULED_ENTRIES, emptySet())
            .orEmpty()
            .mapNotNull { ScheduledReminder.decode(it) }
            .associateBy(ScheduledReminder::itemID)
        val desired = if (isEnabled) items.asSequence()
            .filter { !it.isCompleted && !it.isDeleted && it.dueDate != null }
            .mapNotNull { item ->
                val reminderAt = reminderInstant(item.dueDate ?: return@mapNotNull null)
                if (reminderAt <= Instant.now()) return@mapNotNull null
                item.id to ScheduledReminder(
                    itemID = item.id,
                    triggerAtMillis = reminderAt.toEpochMilli(),
                    titleHash = item.title.hashCode()
                )
            }
            .toMap() else emptyMap()

        existing.forEach { (itemID, entry) ->
            if (desired[itemID] != entry) cancelReminder(itemID)
        }
        desired.forEach { (itemID, entry) ->
            if (existing[itemID] != entry) {
                val item = items.firstOrNull { it.id == itemID } ?: return@forEach
                schedule(item, entry.triggerAtMillis)
            }
        }
        cancelLegacyAlarms()
        preferences.edit {
            putStringSet(
                KEY_SCHEDULED_ENTRIES,
                desired.values.mapTo(mutableSetOf(), ScheduledReminder::encode)
            )
        }
    }

    fun snooze(itemID: String, title: String) {
        val item = SlateTodoItem(id = itemID, title = title)
        schedule(item, Instant.now().plusSeconds(60 * 60).toEpochMilli(), requestSuffix = "snooze")
    }

    private fun reminderInstant(dueDate: Instant): Instant {
        val zone = ZoneId.systemDefault()
        return dueDate
            .atZone(zone)
            .toLocalDate()
            .atTime(LocalTime.of(9, 0))
            .atZone(zone)
            .toInstant()
    }

    private fun cancelLegacyAlarms() {
        preferences.getStringSet(KEY_SCHEDULED_IDS, emptySet()).orEmpty().forEach { id ->
            cancelReminder(id)
        }
        preferences.edit { remove(KEY_SCHEDULED_IDS) }
    }

    private fun cancelReminder(itemID: String) {
        listOf(itemID.hashCode(), "$itemID:snooze".hashCode()).forEach { requestCode ->
            val pending = PendingIntent.getBroadcast(
                context,
                requestCode,
                Intent(context, ReminderReceiver::class.java),
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pending != null) alarmManager.cancel(pending)
        }
    }

    private fun schedule(
        item: SlateTodoItem,
        triggerAtMillis: Long,
        requestSuffix: String = ""
    ) {
        alarmManager.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAtMillis,
            reminderIntent(item, requestSuffix)
        )
    }

    private fun reminderIntent(item: SlateTodoItem, requestSuffix: String): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            putExtra(EXTRA_ITEM_ID, item.id)
            putExtra(EXTRA_TITLE, item.title)
        }
        val requestKey = if (requestSuffix.isEmpty()) item.id else "${item.id}:$requestSuffix"
        return PendingIntent.getBroadcast(
            context,
            requestKey.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    companion object {
        const val CHANNEL_ID = "slate_due_dates"
        const val EXTRA_ITEM_ID = "item_id"
        const val EXTRA_TITLE = "title"
        private const val PREFERENCES = "slate_reminders"
        private const val KEY_ENABLED = "enabled"
        private const val KEY_SCHEDULED_IDS = "scheduled_ids"
        private const val KEY_SCHEDULED_ENTRIES = "scheduled_entries"
    }

    private data class ScheduledReminder(
        val itemID: String,
        val triggerAtMillis: Long,
        val titleHash: Int
    ) {
        fun encode(): String = "$itemID|$triggerAtMillis|$titleHash"

        companion object {
            fun decode(raw: String): ScheduledReminder? {
                val parts = raw.split('|')
                if (parts.size != 3) return null
                return ScheduledReminder(
                    itemID = parts[0],
                    triggerAtMillis = parts[1].toLongOrNull() ?: return null,
                    titleHash = parts[2].toIntOrNull() ?: return null
                )
            }
        }
    }
}

class ReminderReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
        ) return

        val id = intent.getStringExtra(ReminderScheduler.EXTRA_ITEM_ID) ?: return
        val title = intent.getStringExtra(ReminderScheduler.EXTRA_TITLE) ?: "待办事项"
        val openApp = PendingIntent.getActivity(
            context,
            id.hashCode(),
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val complete = reminderActionIntent(context, ReminderActions.COMPLETE, id, title)
        val snooze = reminderActionIntent(context, ReminderActions.SNOOZE, id, title)
        val notification = NotificationCompat.Builder(context, ReminderScheduler.CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("任务今天到期")
            .setContentText(title)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(openApp)
            .addAction(R.drawable.ic_notification, "完成", complete)
            .addAction(R.drawable.ic_notification, "稍后提醒", snooze)
            .setAutoCancel(true)
            .build()

        NotificationManagerCompat.from(context).notify(id.hashCode(), notification)
    }
}

private object ReminderActions {
    const val COMPLETE = "com.thevipsong.slate.reminders.COMPLETE"
    const val SNOOZE = "com.thevipsong.slate.reminders.SNOOZE"
}

private fun reminderActionIntent(
    context: Context,
    action: String,
    itemID: String,
    title: String
): PendingIntent = PendingIntent.getBroadcast(
    context,
    "$action:$itemID".hashCode(),
    Intent(context, ReminderActionReceiver::class.java).apply {
        this.action = action
        putExtra(ReminderScheduler.EXTRA_ITEM_ID, itemID)
        putExtra(ReminderScheduler.EXTRA_TITLE, title)
    },
    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
)

class ReminderActionReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val itemID = intent.getStringExtra(ReminderScheduler.EXTRA_ITEM_ID) ?: return
        val title = intent.getStringExtra(ReminderScheduler.EXTRA_TITLE) ?: "待办事项"
        val pendingResult = goAsync()
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                val app = context.applicationContext as SlateApplication
                when (intent.action) {
                    ReminderActions.COMPLETE -> {
                        val item = app.repository.archive.value.items.firstOrNull {
                            it.id == itemID && !it.isDeleted
                        }
                        if (item != null && !item.isCompleted) {
                            app.repository.toggleTodo(itemID)
                            app.reminderScheduler.sync(app.repository.archive.value.items)
                        }
                    }
                    ReminderActions.SNOOZE -> app.reminderScheduler.snooze(itemID, title)
                }
                NotificationManagerCompat.from(context).cancel(itemID.hashCode())
            } finally {
                pendingResult.finish()
            }
        }
    }
}
