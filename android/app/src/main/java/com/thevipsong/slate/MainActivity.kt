package com.thevipsong.slate

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.thevipsong.slate.ui.SlateScreen
import com.thevipsong.slate.ui.SlateTheme
import com.thevipsong.slate.ui.SlateViewModel
import com.thevipsong.slate.widget.SlateWidgetProvider

class MainActivity : ComponentActivity() {
    private val viewModel: SlateViewModel by viewModels()
    private val quickAddFocusRequest = mutableLongStateOf(0L)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
        enableEdgeToEdge()
        setContent {
            val state by viewModel.uiState.collectAsStateWithLifecycle()
            SlateTheme(mode = state.themeMode) {
                SlateScreen(
                    state = state,
                    viewModel = viewModel,
                    quickAddFocusRequest = quickAddFocusRequest.longValue
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    override fun onStart() {
        super.onStart()
        viewModel.startAutomaticSync()
        viewModel.syncIfConfigured()
    }

    override fun onStop() {
        viewModel.stopAutomaticSync()
        super.onStop()
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        if (intent.getBooleanExtra(SlateWidgetProvider.EXTRA_FOCUS_QUICK_ADD, false)) {
            quickAddFocusRequest.longValue += 1
            intent.removeExtra(SlateWidgetProvider.EXTRA_FOCUS_QUICK_ADD)
        }
        if (intent.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            intent.getStringExtra(Intent.EXTRA_TEXT)
                ?.trim()
                ?.takeIf(String::isNotEmpty)
                ?.let { viewModel.addTodo(it, null) }
            intent.removeExtra(Intent.EXTRA_TEXT)
        }
    }
}
