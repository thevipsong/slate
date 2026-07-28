package com.thevipsong.slate

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.thevipsong.slate.ui.SlateScreen
import com.thevipsong.slate.ui.SlateTheme
import com.thevipsong.slate.ui.SlateViewModel

class MainActivity : ComponentActivity() {
    private val viewModel: SlateViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val state by viewModel.uiState.collectAsStateWithLifecycle()
            SlateTheme(mode = state.themeMode) {
                SlateScreen(state = state, viewModel = viewModel)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        viewModel.syncIfConfigured()
    }
}
