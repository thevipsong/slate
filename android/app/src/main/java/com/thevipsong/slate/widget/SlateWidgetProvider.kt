package com.thevipsong.slate.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.thevipsong.slate.MainActivity
import com.thevipsong.slate.R
import com.thevipsong.slate.data.SlateFileStore
import com.thevipsong.slate.data.SlateTodoItem
import java.time.ZoneId
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class SlateWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val pendingResult = goAsync()
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                val items = runCatching {
                    SlateFileStore(context).load().items
                        .asSequence()
                        .filter { !it.isDeleted && !it.isCompleted }
                        .sortedWith(
                            compareBy<SlateTodoItem> {
                                it.dueDate?.atZone(ZoneId.systemDefault())?.toLocalDate()
                            }.thenBy { it.sortOrder ?: Double.MAX_VALUE }
                        )
                        .toList()
                }.getOrDefault(emptyList())
                appWidgetIds.forEach { widgetID ->
                    appWidgetManager.updateAppWidget(
                        widgetID,
                        buildRemoteViews(context, items)
                    )
                }
            } finally {
                pendingResult.finish()
            }
        }
    }

    companion object {
        const val EXTRA_FOCUS_QUICK_ADD = "focus_quick_add"

        fun requestUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, SlateWidgetProvider::class.java)
            val widgetIDs = manager.getAppWidgetIds(component)
            if (widgetIDs.isEmpty()) return
            context.sendBroadcast(
                Intent(context, SlateWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIDs)
                }
            )
        }

        private fun buildRemoteViews(
            context: Context,
            items: List<SlateTodoItem>
        ): RemoteViews {
            val openApp = PendingIntent.getActivity(
                context,
                1001,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val quickAdd = PendingIntent.getActivity(
                context,
                1002,
                Intent(context, MainActivity::class.java).apply {
                    putExtra(EXTRA_FOCUS_QUICK_ADD, true)
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            return RemoteViews(context.packageName, R.layout.slate_widget).apply {
                setTextViewText(R.id.widget_count, "${items.size} 项待办")
                val preview = items.take(3)
                val views = intArrayOf(
                    R.id.widget_task_one,
                    R.id.widget_task_two,
                    R.id.widget_task_three
                )
                views.forEachIndexed { index, viewID ->
                    val title = preview.getOrNull(index)?.title
                    setTextViewText(viewID, title?.let { "○  $it" }.orEmpty())
                    setViewVisibility(
                        viewID,
                        if (title == null) android.view.View.GONE else android.view.View.VISIBLE
                    )
                }
                setViewVisibility(
                    R.id.widget_empty,
                    if (items.isEmpty()) android.view.View.VISIBLE else android.view.View.GONE
                )
                setOnClickPendingIntent(R.id.widget_root, openApp)
                setOnClickPendingIntent(R.id.widget_add, quickAdd)
            }
        }
    }
}
