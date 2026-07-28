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
import androidx.core.content.ContextCompat
import com.thevipsong.slate.R
import com.thevipsong.slate.data.SlateTodoItem
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId

class ReminderScheduler(private val context: Context) {
    private val alarmManager = context.getSystemService(AlarmManager::class.java)
    private val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    var isEnabled: Boolean
        get() = preferences.getBoolean(KEY_ENABLED, false)
        set(value) = preferences.edit().putBoolean(KEY_ENABLED, value).apply()

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
        cancelKnownAlarms()
        if (!isEnabled) return

        val scheduled = mutableSetOf<String>()
        items.asSequence()
            .filter { !it.isCompleted && !it.isDeleted && it.dueDate != null }
            .forEach { item ->
                val reminderAt = reminderInstant(item.dueDate ?: return@forEach)
                if (reminderAt <= Instant.now()) return@forEach
                val intent = reminderIntent(item)
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    reminderAt.toEpochMilli(),
                    intent
                )
                scheduled += item.id
            }
        preferences.edit().putStringSet(KEY_SCHEDULED_IDS, scheduled).apply()
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

    private fun cancelKnownAlarms() {
        preferences.getStringSet(KEY_SCHEDULED_IDS, emptySet()).orEmpty().forEach { id ->
            val intent = Intent(context, ReminderReceiver::class.java)
            val pending = PendingIntent.getBroadcast(
                context,
                id.hashCode(),
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pending != null) alarmManager.cancel(pending)
        }
        preferences.edit().remove(KEY_SCHEDULED_IDS).apply()
    }

    private fun reminderIntent(item: SlateTodoItem): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            putExtra(EXTRA_ITEM_ID, item.id)
            putExtra(EXTRA_TITLE, item.title)
        }
        return PendingIntent.getBroadcast(
            context,
            item.id.hashCode(),
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
        val notification = NotificationCompat.Builder(context, ReminderScheduler.CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("任务今天到期")
            .setContentText(title)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()

        NotificationManagerCompat.from(context).notify(id.hashCode(), notification)
    }
}
