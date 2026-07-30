package com.thevipsong.slate.ui

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import com.thevipsong.slate.data.SlateThemeMode

val SlateBlue = Color(0xFF4A8DFF)
val SlateBlueSoft = Color(0xFF263B60)
val SlateDark = Color(0xFF10141B)
val SlateSurface = Color(0xFF181D25)
val SlateSurfaceHigh = Color(0xFF202733)
val SlateText = Color(0xFFF4F6FA)
val SlateMuted = Color(0xFFADB6C5)
val SlateOrange = Color(0xFFFFA24B)

private val DarkColors = darkColorScheme(
    primary = SlateBlue,
    onPrimary = Color.White,
    primaryContainer = Color(0xFF203F70),
    onPrimaryContainer = Color(0xFFDCE8FF),
    secondary = Color(0xFFA8C7FA),
    secondaryContainer = Color(0xFF203F70),
    onSecondaryContainer = Color(0xFFDCE8FF),
    background = SlateDark,
    onBackground = SlateText,
    surface = SlateSurface,
    surfaceContainerLow = Color(0xFF171C24),
    surfaceContainer = Color(0xFF1C222C),
    surfaceContainerHigh = Color(0xFF222A35),
    onSurface = SlateText,
    surfaceVariant = SlateSurfaceHigh,
    onSurfaceVariant = SlateMuted,
    outline = Color(0xFF3D4654),
    error = Color(0xFFFF6B72)
)

private val LightColors = lightColorScheme(
    primary = Color(0xFF1769D2),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFD8E7FF),
    onPrimaryContainer = Color(0xFF102746),
    secondary = Color(0xFF46617F),
    secondaryContainer = Color(0xFFD8E7FF),
    onSecondaryContainer = Color(0xFF102746),
    background = Color(0xFFF5F7FB),
    onBackground = Color(0xFF171B22),
    surface = Color.White,
    surfaceContainerLow = Color(0xFFFAFBFD),
    surfaceContainer = Color(0xFFFFFFFF),
    surfaceContainerHigh = Color(0xFFF0F3F7),
    onSurface = Color(0xFF171B22),
    surfaceVariant = Color(0xFFEBEFF5),
    onSurfaceVariant = Color(0xFF5B6471),
    outline = Color(0xFFD4DAE3),
    error = Color(0xFFBA1A1A)
)

@Composable
fun SlateTheme(
    mode: SlateThemeMode,
    content: @Composable () -> Unit
) {
    val dark = when (mode) {
        SlateThemeMode.SYSTEM -> isSystemInDarkTheme()
        SlateThemeMode.DARK -> true
        SlateThemeMode.LIGHT -> false
    }
    val colors = if (dark) DarkColors else LightColors
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            WindowCompat.getInsetsController(window, window.decorView).apply {
                isAppearanceLightStatusBars = !dark
                isAppearanceLightNavigationBars = !dark
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                window.isNavigationBarContrastEnforced = false
            }
        }
    }

    MaterialTheme(
        colorScheme = colors,
        typography = MaterialTheme.typography.copy(),
        content = content
    )
}
