@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.thevipsong.slate.ui

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.FileDownload
import androidx.compose.material.icons.filled.FileUpload
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.DragIndicator
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDefaults
import androidx.compose.material3.DrawerValue
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.ModalDrawerSheet
import androidx.compose.material3.ModalNavigationDrawer
import androidx.compose.material3.NavigationDrawerItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Surface
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberDrawerState
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
import com.thevipsong.slate.data.SlateThemeMode
import com.thevipsong.slate.data.SlateTodoGroup
import com.thevipsong.slate.data.SlateTodoItem
import com.thevipsong.slate.data.TodoFilter
import com.thevipsong.slate.sync.SupabaseConfiguration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun SlateScreen(
    state: SlateUiState,
    viewModel: SlateViewModel,
    quickAddFocusRequest: Long = 0L
) {
    val snackbarHost = remember { SnackbarHostState() }
    val drawerState = rememberDrawerState(initialValue = DrawerValue.Closed)
    val coroutineScope = rememberCoroutineScope()
    var showSettings by rememberSaveable { mutableStateOf(false) }
    var showAddGroup by rememberSaveable { mutableStateOf(false) }
    var showSearch by rememberSaveable { mutableStateOf(false) }
    var showSyncSetup by rememberSaveable { mutableStateOf(false) }
    var groupToManage by remember { mutableStateOf<SlateTodoGroup?>(null) }
    var editingItem by remember { mutableStateOf<SlateTodoItem?>(null) }
    val importLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri -> uri?.let(viewModel::importArchive) }
    val exportLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/json")
    ) { uri -> uri?.let(viewModel::exportArchive) }
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted -> viewModel.setRemindersEnabled(granted) }
    val context = LocalContext.current
    val deleteWithUndo: (String) -> Unit = { id ->
        viewModel.deleteTodo(id)
        coroutineScope.launch {
            snackbarHost.currentSnackbarData?.dismiss()
            val result = snackbarHost.showSnackbar(
                message = "任务已删除",
                actionLabel = "撤销",
                withDismissAction = true,
                duration = SnackbarDuration.Long
            )
            if (result == SnackbarResult.ActionPerformed) {
                viewModel.restoreTodo(id)
            }
        }
    }

    LaunchedEffect(state.message) {
        state.message?.let {
            snackbarHost.showSnackbar(it)
            viewModel.clearMessage()
        }
    }

    val selectGroup: (String) -> Unit = { groupID ->
        viewModel.selectGroup(groupID)
        coroutineScope.launch { drawerState.close() }
    }
    val manageGroup: (SlateTodoGroup) -> Unit = {
        groupToManage = it
        coroutineScope.launch { drawerState.close() }
    }
    val addGroup: () -> Unit = {
        showAddGroup = true
        coroutineScope.launch { drawerState.close() }
    }
    val homeContent: @Composable (Boolean) -> Unit = { showGroupButton ->
        Scaffold(
            modifier = Modifier
                .fillMaxSize()
                .imePadding(),
            containerColor = MaterialTheme.colorScheme.background,
            contentWindowInsets = WindowInsets(0),
            snackbarHost = { SnackbarHost(snackbarHost) },
            bottomBar = {
                QuickAddBar(
                    focusRequest = quickAddFocusRequest,
                    onAdd = viewModel::addTodo
                )
            }
        ) { contentPadding ->
            Box(
                Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(
                                MaterialTheme.colorScheme.primary.copy(alpha = 0.10f),
                                MaterialTheme.colorScheme.background,
                                MaterialTheme.colorScheme.background
                            )
                        )
                    )
                    .padding(contentPadding)
            ) {
                Column(
                    Modifier
                        .fillMaxSize()
                        .statusBarsPadding()
                ) {
                    SlateHeader(
                        state = state,
                        searchActive = showSearch || state.search.isNotBlank(),
                        showGroupButton = showGroupButton,
                        onOpenGroups = { coroutineScope.launch { drawerState.open() } },
                        onSearch = { showSearch = !showSearch },
                        onSettings = { showSettings = true }
                    )
                    AnimatedVisibility(
                        visible = showSearch || state.search.isNotBlank(),
                        enter = fadeIn() + slideInVertically { -it / 2 },
                        exit = fadeOut() + slideOutVertically { -it / 2 }
                    ) {
                        SearchField(
                            search = state.search,
                            onSearch = viewModel::setSearch,
                            onClose = {
                                viewModel.setSearch("")
                                showSearch = false
                            }
                        )
                    }
                    CompactFilterBar(
                        selected = state.filter,
                        onFilter = viewModel::setFilter
                    )

                    if (state.visibleItems.isEmpty()) {
                        EmptyState(
                            hasSearch = state.search.isNotBlank(),
                            modifier = Modifier.weight(1f)
                        )
                    } else {
                        TodoList(
                            sections = state.taskSections,
                            onToggle = viewModel::toggleTodo,
                            onDelete = deleteWithUndo,
                            onReorder = viewModel::reorderTodo,
                            onEdit = { item ->
                                viewModel.selectTodo(item.id)
                                editingItem = item
                            },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }
        }
    }

    BoxWithConstraints(Modifier.fillMaxSize()) {
        if (maxWidth >= 840.dp) {
            Row(Modifier.fillMaxSize()) {
                PermanentGroupPane(
                    state = state,
                    onSelect = selectGroup,
                    onManage = manageGroup,
                    onAdd = addGroup
                )
                Box(
                    Modifier
                        .weight(1f)
                        .fillMaxSize(),
                    contentAlignment = Alignment.TopCenter
                ) {
                    Box(
                        Modifier
                            .fillMaxSize()
                            .widthIn(max = 920.dp)
                    ) {
                        homeContent(false)
                    }
                }
            }
        } else {
            ModalNavigationDrawer(
                drawerState = drawerState,
                gesturesEnabled = true,
                drawerContent = {
                    GroupDrawer(
                        state = state,
                        onSelect = selectGroup,
                        onManage = manageGroup,
                        onAdd = addGroup
                    )
                }
            ) {
                homeContent(true)
            }
        }
    }

    editingItem?.let { item ->
        val currentItem = state.archive.items.firstOrNull { it.id == item.id && !it.isDeleted }
        if (currentItem == null) {
            editingItem = null
        } else {
            TaskEditorSheet(
                item = currentItem,
                groups = state.groups,
                onDismiss = {
                    editingItem = null
                    viewModel.selectTodo(currentItem.id)
                },
                onSave = { title, dueDate, groupID ->
                    viewModel.updateTodo(currentItem.id, title, dueDate, groupID)
                    editingItem = null
                },
                onToggle = {
                    viewModel.toggleTodo(currentItem.id)
                    editingItem = null
                },
                onDelete = {
                    deleteWithUndo(currentItem.id)
                    editingItem = null
                }
            )
        }
    }

    if (showAddGroup) {
        TextEntryDialog(
            title = "新建分组",
            initialValue = "",
            confirmLabel = "创建",
            onDismiss = { showAddGroup = false },
            onConfirm = {
                viewModel.addGroup(it)
                showAddGroup = false
            }
        )
    }

    groupToManage?.let { group ->
        GroupManageDialog(
            group = group,
            canDelete = state.groups.size > 1,
            onDismiss = { groupToManage = null },
            onRename = {
                viewModel.renameGroup(group.id, it)
                groupToManage = null
            },
            onDelete = {
                viewModel.deleteGroup(group.id)
                groupToManage = null
            }
        )
    }

    if (showSettings) {
        SettingsSheet(
            state = state,
            onDismiss = { showSettings = false },
            onTheme = viewModel::setTheme,
            onReminders = { enabled ->
                if (
                    enabled &&
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                    ContextCompat.checkSelfPermission(
                        context,
                        Manifest.permission.POST_NOTIFICATIONS
                    ) != PackageManager.PERMISSION_GRANTED
                ) {
                    permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                } else {
                    viewModel.setRemindersEnabled(enabled)
                }
            },
            onImport = { importLauncher.launch(arrayOf("application/json", "text/plain")) },
            onExport = { exportLauncher.launch("slate-backup.json") },
            onSyncSetup = { showSyncSetup = true },
            onSyncNow = viewModel::syncNow,
            onSyncSignOut = viewModel::signOutSync
        )
    }

    if (showSyncSetup) {
        SyncSetupDialog(
            initialURL = state.sync.projectURL,
            initialKey = state.sync.publishableKey,
            onDismiss = { showSyncSetup = false },
            onSubmit = { url, key, email, password, createAccount ->
                viewModel.configureAndAuthenticateSync(
                    projectURL = url,
                    publishableKey = key,
                    email = email,
                    password = password,
                    createAccount = createAccount
                )
                showSyncSetup = false
            }
        )
    }
}

@Composable
private fun SlateHeader(
    state: SlateUiState,
    searchActive: Boolean,
    showGroupButton: Boolean,
    onOpenGroups: () -> Unit,
    onSearch: () -> Unit,
    onSettings: () -> Unit
) {
    val date = LocalDate.now().format(
        DateTimeFormatter.ofPattern("M月d日 E", Locale.SIMPLIFIED_CHINESE)
    )
    Row(
        Modifier
            .fillMaxWidth()
            .padding(start = 4.dp, top = 8.dp, end = 4.dp, bottom = 2.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (showGroupButton) {
            IconButton(onClick = onOpenGroups, modifier = Modifier.size(48.dp)) {
                Icon(Icons.Default.Menu, contentDescription = "打开分组")
            }
        } else {
            Spacer(Modifier.width(12.dp))
        }
        Column(Modifier.weight(1f)) {
            val selectedGroup = state.groups.firstOrNull { it.id == state.selectedGroupID }
            Text(
                selectedGroup?.name ?: "待办",
                fontSize = 20.sp,
                lineHeight = 24.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                "$date · ${state.selectedGroupPendingCount}项待办",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontWeight = FontWeight.Medium,
                fontSize = 12.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        IconButton(
            onClick = onSearch,
            modifier = Modifier.size(48.dp)
        ) {
            Icon(
                Icons.Default.Search,
                contentDescription = if (searchActive) "收起搜索" else "搜索",
                tint = if (searchActive) {
                    MaterialTheme.colorScheme.primary
                } else MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        IconButton(
            onClick = onSettings,
            modifier = Modifier.size(48.dp)
        ) {
            Icon(Icons.Default.Settings, contentDescription = "设置")
        }
    }
}

@Composable
private fun GroupDrawer(
    state: SlateUiState,
    onSelect: (String) -> Unit,
    onManage: (SlateTodoGroup) -> Unit,
    onAdd: () -> Unit
) {
    ModalDrawerSheet(
        modifier = Modifier
            .fillMaxWidth(0.84f)
            .navigationBarsPadding(),
        drawerShape = RoundedCornerShape(topEnd = 28.dp, bottomEnd = 28.dp)
    ) {
        GroupListContent(state, onSelect, onManage, onAdd)
    }
}

@Composable
private fun PermanentGroupPane(
    state: SlateUiState,
    onSelect: (String) -> Unit,
    onManage: (SlateTodoGroup) -> Unit,
    onAdd: () -> Unit
) {
    Surface(
        modifier = Modifier
            .width(292.dp)
            .fillMaxSize(),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 2.dp
    ) {
        GroupListContent(state, onSelect, onManage, onAdd)
    }
}

@Composable
private fun GroupListContent(
    state: SlateUiState,
    onSelect: (String) -> Unit,
    onManage: (SlateTodoGroup) -> Unit,
    onAdd: () -> Unit
) {
    Column(
        Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .navigationBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 12.dp)
    ) {
        Text(
            "序事",
            modifier = Modifier.padding(start = 16.dp, top = 18.dp),
            fontSize = 24.sp,
            lineHeight = 30.sp,
            fontWeight = FontWeight.Bold
        )
        Text(
            "Slate · 分组",
            modifier = Modifier.padding(start = 16.dp, top = 4.dp, bottom = 20.dp),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontSize = 14.sp,
            lineHeight = 20.sp,
            fontWeight = FontWeight.SemiBold
        )
        state.groups.forEach { group ->
            val selected = group.id == state.selectedGroupID
            val pendingCount = state.groupPendingCounts[group.id] ?: 0
            Row(
                modifier = Modifier.padding(end = 4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                NavigationDrawerItem(
                    modifier = Modifier.weight(1f),
                    selected = selected,
                    onClick = { onSelect(group.id) },
                    icon = {
                        Icon(Icons.Outlined.Folder, contentDescription = null)
                    },
                    label = {
                        Text(
                            group.name,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            fontWeight = if (selected) {
                                FontWeight.SemiBold
                            } else FontWeight.Medium
                        )
                    },
                    badge = { Text(pendingCount.toString()) }
                )
                IconButton(
                    onClick = { onManage(group) },
                    modifier = Modifier.size(48.dp)
                ) {
                    Icon(
                        Icons.Default.MoreHoriz,
                        contentDescription = "管理${group.name}分组",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
        HorizontalDivider(Modifier.padding(vertical = 12.dp))
        OutlinedButton(
            onClick = onAdd,
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp)
        ) {
            Icon(Icons.Default.Add, contentDescription = null)
            Spacer(Modifier.width(8.dp))
            Text("新建分组")
        }
    }
}

@Composable
private fun GroupManageDialog(
    group: SlateTodoGroup,
    canDelete: Boolean,
    onDismiss: () -> Unit,
    onRename: (String) -> Unit,
    onDelete: () -> Unit
) {
    var name by rememberSaveable(group.id) { mutableStateOf(group.name) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("管理分组") },
        text = {
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("分组名称") },
                singleLine = true,
                shape = RoundedCornerShape(14.dp)
            )
        },
        confirmButton = {
            TextButton(
                enabled = name.isNotBlank(),
                onClick = { onRename(name) }
            ) { Text("保存") }
        },
        dismissButton = {
            Row {
                if (canDelete) {
                    TextButton(onClick = onDelete) {
                        Text("删除", color = MaterialTheme.colorScheme.error)
                    }
                }
                TextButton(onClick = onDismiss) { Text("取消") }
            }
        }
    )
}

@Composable
private fun QuickAddBar(
    focusRequest: Long,
    onAdd: (String, Instant?) -> Unit
) {
    var title by rememberSaveable { mutableStateOf("") }
    var dueDate by rememberSaveable { mutableStateOf<Instant?>(null) }
    var showDatePicker by rememberSaveable { mutableStateOf(false) }
    var isFocused by remember { mutableStateOf(false) }
    val focusRequester = remember { FocusRequester() }
    val keyboardController = LocalSoftwareKeyboardController.current
    val focusManager = LocalFocusManager.current

    fun submit() {
        val cleanTitle = title.trim()
        if (cleanTitle.isEmpty()) return
        onAdd(cleanTitle, dueDate)
        title = ""
        dueDate = null
        focusManager.clearFocus()
        keyboardController?.hide()
    }

    LaunchedEffect(focusRequest) {
        if (focusRequest > 0L) {
            focusRequester.requestFocus()
            keyboardController?.show()
        }
    }

    Surface(
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 0.dp,
        shadowElevation = 0.dp
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = 16.dp, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            dueDate?.let {
                DueDateLabel(
                    dueDate = it,
                    onClear = { dueDate = null }
                )
            }
            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .focusRequester(focusRequester)
                    .onFocusChanged { isFocused = it.isFocused }
                    .border(
                        width = 1.dp,
                        color = if (isFocused) {
                            MaterialTheme.colorScheme.primary
                        } else {
                            MaterialTheme.colorScheme.outline
                        },
                        shape = RoundedCornerShape(18.dp)
                    ),
                placeholder = { Text("添加一件事…") },
                leadingIcon = {
                    Icon(
                        Icons.Default.Add,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary
                    )
                },
                trailingIcon = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        IconButton(
                            onClick = { showDatePicker = true },
                            modifier = Modifier.size(48.dp)
                        ) {
                            Icon(
                                Icons.Outlined.CalendarMonth,
                                contentDescription = "设置到期日期",
                                tint = if (dueDate == null) {
                                    MaterialTheme.colorScheme.onSurfaceVariant
                                } else {
                                    MaterialTheme.colorScheme.primary
                                }
                            )
                        }
                        IconButton(
                            enabled = title.isNotBlank(),
                            onClick = { submit() },
                            modifier = Modifier.size(48.dp)
                        ) {
                            Icon(
                                Icons.Rounded.Check,
                                contentDescription = "添加任务",
                                tint = if (title.isNotBlank()) {
                                    MaterialTheme.colorScheme.primary
                                } else {
                                    MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.38f)
                                }
                            )
                        }
                    }
                },
                singleLine = true,
                shape = RoundedCornerShape(18.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = Color.Transparent,
                    unfocusedBorderColor = Color.Transparent,
                    disabledBorderColor = Color.Transparent,
                    errorBorderColor = Color.Transparent,
                    focusedContainerColor = MaterialTheme.colorScheme.surfaceContainer,
                    unfocusedContainerColor = MaterialTheme.colorScheme.surfaceContainer,
                    disabledContainerColor = MaterialTheme.colorScheme.surfaceContainer
                ),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = { submit() })
            )
        }
    }

    if (showDatePicker) {
        SlateDatePickerDialog(
            initial = dueDate,
            onDismiss = { showDatePicker = false },
            onConfirm = {
                dueDate = it
                showDatePicker = false
            }
        )
    }
}

@Composable
private fun AddTodoSheet(
    onDismiss: () -> Unit,
    onAdd: (String, Instant?) -> Unit
) {
    val focusManager = LocalFocusManager.current
    var title by rememberSaveable { mutableStateOf("") }
    var dueDate by rememberSaveable { mutableStateOf<Instant?>(null) }
    var showDatePicker by rememberSaveable { mutableStateOf(false) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    fun submit() {
        if (title.isBlank()) return
        onAdd(title, dueDate)
        focusManager.clearFocus()
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .imePadding()
                .navigationBarsPadding()
                .padding(horizontal = 22.dp)
                .padding(bottom = 22.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Text("新建任务", fontSize = 24.sp, fontWeight = FontWeight.Bold)
            Text(
                "先记下来，日期可以稍后再补充。",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = 13.sp
            )
            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("任务标题") },
                placeholder = { Text("例如：提交报销材料") },
                singleLine = true,
                shape = RoundedCornerShape(16.dp),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = { submit() })
            )
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                FilledTonalButton(
                    onClick = { showDatePicker = true },
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                ) {
                    Icon(Icons.Default.CalendarMonth, null, Modifier.size(19.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(if (dueDate == null) "设置日期" else "修改日期")
                }
                Button(
                    enabled = title.isNotBlank(),
                    onClick = { submit() },
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                ) {
                    Text("添加任务")
                }
            }
            dueDate?.let {
                DueDateLabel(
                    dueDate = it,
                    onClear = { dueDate = null }
                )
            }
        }
    }

    if (showDatePicker) {
        SlateDatePickerDialog(
            initial = dueDate,
            onDismiss = { showDatePicker = false },
            onConfirm = {
                dueDate = it
                showDatePicker = false
            }
        )
    }
}

@Composable
private fun SearchField(
    search: String,
    onSearch: (String) -> Unit,
    onClose: () -> Unit
) {
    OutlinedTextField(
        value = search,
        onValueChange = onSearch,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 4.dp),
        placeholder = { Text("搜索当前分组") },
        leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
        trailingIcon = {
            IconButton(onClick = onClose, modifier = Modifier.size(48.dp)) {
                Icon(Icons.Default.Close, contentDescription = "关闭搜索")
            }
        },
        singleLine = true,
        shape = RoundedCornerShape(16.dp)
    )
}

@Composable
private fun CompactFilterBar(
    selected: TodoFilter,
    onFilter: (TodoFilter) -> Unit
) {
    val filters = listOf(
        TodoFilter.ALL to "全部",
        TodoFilter.PENDING to "待完成",
        TodoFilter.COMPLETED to "已完成",
        TodoFilter.OVERDUE to "逾期"
    )
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 6.dp),
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.72f)
    ) {
        Row(
            Modifier.padding(3.dp),
            horizontalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            filters.forEach { (filter, label) ->
                val isSelected = selected == filter
                Surface(
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .semantics {
                            role = Role.Tab
                            this.selected = isSelected
                        },
                    onClick = { onFilter(filter) },
                    shape = RoundedCornerShape(13.dp),
                    color = if (isSelected) {
                        MaterialTheme.colorScheme.surface
                    } else Color.Transparent,
                    tonalElevation = if (isSelected) 2.dp else 0.dp
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Text(
                            label,
                            color = if (isSelected) {
                                MaterialTheme.colorScheme.primary
                            } else MaterialTheme.colorScheme.onSurfaceVariant,
                            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium,
                            fontSize = 13.sp,
                            maxLines = 1
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun TodoList(
    sections: List<SlateTaskSection>,
    onToggle: (String) -> Unit,
    onDelete: (String) -> Unit,
    onReorder: (String, String) -> Unit,
    onEdit: (SlateTodoItem) -> Unit,
    modifier: Modifier = Modifier
) {
    val listState = rememberLazyListState()
    val haptics = LocalHapticFeedback.current
    var draggingID by remember { mutableStateOf<String?>(null) }
    var dragOffset by remember { mutableFloatStateOf(0f) }
    var lastTargetID by remember { mutableStateOf<String?>(null) }
    var displaySections by remember { mutableStateOf(sections) }

    LaunchedEffect(sections, draggingID) {
        if (draggingID == null) displaySections = sections
    }

    LazyColumn(
        modifier = modifier.fillMaxWidth(),
        state = listState,
        contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 4.dp, bottom = 40.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        displaySections.forEach { section ->
            item(key = "section:${section.key}", contentType = "section-header") {
                TaskSectionHeader(
                    title = section.title,
                    count = section.items.size
                )
            }
            itemsIndexed(
                items = section.items,
                key = { _, item -> item.id },
                contentType = { _, _ -> "task" }
            ) { _, item ->
                val isDragging = draggingID == item.id
                val validTargetIDs = section.items.mapTo(mutableSetOf(), SlateTodoItem::id)
                val dragModifier = Modifier.pointerInput(item.id, validTargetIDs) {
                    detectDragGesturesAfterLongPress(
                        onDragStart = {
                            draggingID = item.id
                            lastTargetID = item.id
                            dragOffset = 0f
                            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                        },
                        onDragCancel = {
                            draggingID = null
                            lastTargetID = null
                            dragOffset = 0f
                        },
                        onDragEnd = {
                            val targetID = lastTargetID
                            if (targetID != null && targetID != item.id) {
                                onReorder(item.id, targetID)
                            }
                            draggingID = null
                            lastTargetID = null
                            dragOffset = 0f
                        },
                        onDrag = { change, amount ->
                            change.consume()
                            dragOffset += amount.y
                            val sourceInfo = listState.layoutInfo.visibleItemsInfo
                                .firstOrNull { it.key == item.id }
                                ?: return@detectDragGesturesAfterLongPress
                            val draggedCenter =
                                sourceInfo.offset + sourceInfo.size / 2f + dragOffset
                            val target = listState.layoutInfo.visibleItemsInfo.firstOrNull { visible ->
                                val key = visible.key as? String
                                key != item.id &&
                                    key in validTargetIDs &&
                                    draggedCenter >= visible.offset &&
                                    draggedCenter <= visible.offset + visible.size
                            }
                            val targetID = target?.key as? String
                            if (targetID != null && targetID != lastTargetID) {
                                displaySections = displaySections.moveTask(item.id, targetID)
                                lastTargetID = targetID
                                dragOffset = 0f
                                haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                            }
                        }
                    )
                }
                Box(
                    Modifier
                        .animateItem()
                        .zIndex(if (isDragging) 2f else 0f)
                        .graphicsLayer {
                            translationY = if (isDragging) dragOffset else 0f
                            scaleX = if (isDragging) 1.015f else 1f
                            scaleY = if (isDragging) 1.015f else 1f
                            alpha = if (isDragging) 0.96f else 1f
                        }
                ) {
                    SwipeTodoCard(
                        item = item,
                        onToggle = { onToggle(item.id) },
                        onDelete = { onDelete(item.id) },
                        onEdit = { onEdit(item) },
                        modifier = dragModifier
                    )
                }
            }
        }
    }
}

private fun List<SlateTaskSection>.moveTask(
    sourceID: String,
    targetID: String
): List<SlateTaskSection> = map { section ->
    val sourceIndex = section.items.indexOfFirst { it.id == sourceID }
    val targetIndex = section.items.indexOfFirst { it.id == targetID }
    if (sourceIndex < 0 || targetIndex < 0 || sourceIndex == targetIndex) {
        section
    } else {
        val reordered = section.items.toMutableList()
        val moved = reordered.removeAt(sourceIndex)
        reordered.add(targetIndex, moved)
        section.copy(items = reordered)
    }
}

@Composable
private fun TaskSectionHeader(title: String, count: Int) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(start = 4.dp, top = 12.dp, end = 4.dp, bottom = 2.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            title,
            modifier = Modifier.weight(1f),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold
        )
        Text(
            count.toString(),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontSize = 13.sp
        )
    }
}

@Composable
private fun SwipeTodoCard(
    item: SlateTodoItem,
    onToggle: () -> Unit,
    onDelete: () -> Unit,
    onEdit: () -> Unit,
    modifier: Modifier = Modifier
) {
    var actionLocked by remember(item.id) { mutableStateOf(false) }
    val triggerToggle = {
        if (!actionLocked) {
            actionLocked = true
            onToggle()
        }
    }
    LaunchedEffect(actionLocked) {
        if (actionLocked) {
            delay(650)
            actionLocked = false
        }
    }
    @Suppress("DEPRECATION")
    val dismissState = rememberSwipeToDismissBoxState(
        positionalThreshold = { distance -> distance * 0.34f },
        confirmValueChange = { value ->
            when (value) {
                SwipeToDismissBoxValue.StartToEnd -> {
                    triggerToggle()
                    false
                }
                SwipeToDismissBoxValue.EndToStart -> {
                    if (actionLocked) {
                        false
                    } else {
                        actionLocked = true
                        onDelete()
                        true
                    }
                }
                SwipeToDismissBoxValue.Settled -> true
            }
        }
    )

    SwipeToDismissBox(
        modifier = Modifier.semantics {
            customActions = listOf(
                CustomAccessibilityAction(
                    label = if (item.isCompleted) "恢复为待办" else "标记完成",
                    action = {
                        triggerToggle()
                        true
                    }
                ),
                CustomAccessibilityAction(
                    label = "删除任务",
                    action = {
                        onDelete()
                        true
                    }
                )
            )
        },
        state = dismissState,
        backgroundContent = {
            val direction = dismissState.dismissDirection
            val completing = direction == SwipeToDismissBoxValue.StartToEnd
            Box(
                Modifier
                    .fillMaxSize()
                    .clip(RoundedCornerShape(16.dp))
                    .background(
                        if (completing) {
                            MaterialTheme.colorScheme.primaryContainer
                        } else MaterialTheme.colorScheme.error.copy(alpha = 0.14f)
                    )
                    .padding(horizontal = 20.dp),
                contentAlignment = if (completing) {
                    Alignment.CenterStart
                } else Alignment.CenterEnd
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    if (completing) {
                        Icon(Icons.Default.Check, contentDescription = null)
                        Text(
                            if (item.isCompleted) "恢复待办" else "完成",
                            fontWeight = FontWeight.SemiBold
                        )
                    } else {
                        Text(
                            "删除",
                            color = MaterialTheme.colorScheme.error,
                            fontWeight = FontWeight.SemiBold
                        )
                        Icon(
                            Icons.Default.Delete,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.error
                        )
                    }
                }
            }
        }
    ) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .animateContentSize()
                .clickable(onClick = onEdit),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceContainer
            ),
            border = BorderStroke(
                1.dp,
                MaterialTheme.colorScheme.outline.copy(alpha = 0.78f)
            ),
            elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
            shape = RoundedCornerShape(16.dp)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .defaultMinSize(minHeight = 80.dp)
                    .padding(start = 10.dp, top = 12.dp, end = 20.dp, bottom = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(
                    onClick = triggerToggle,
                    modifier = Modifier.size(48.dp)
                ) {
                    Icon(
                        if (item.isCompleted) Icons.Default.CheckCircle
                        else Icons.Default.RadioButtonUnchecked,
                        contentDescription = if (item.isCompleted) "标为未完成" else "完成",
                        tint = if (item.isCompleted) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Spacer(Modifier.width(2.dp))
                Column(Modifier.weight(1f)) {
                    Text(
                        item.title,
                        fontWeight = FontWeight.Medium,
                        fontSize = 16.sp,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        textDecoration = if (item.isCompleted) {
                            TextDecoration.LineThrough
                        } else TextDecoration.None,
                        modifier = Modifier.alpha(if (item.isCompleted) 0.62f else 1f)
                    )
                    item.dueDate?.let {
                        DueDateText(dueDate = it, completed = item.isCompleted)
                    }
                }
                Icon(
                    Icons.Rounded.DragIndicator,
                    contentDescription = "长按拖动排序",
                    modifier = modifier
                        .size(48.dp)
                        .padding(12.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.72f)
                )
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun TaskEditorSheet(
    item: SlateTodoItem,
    groups: List<SlateTodoGroup>,
    onDismiss: () -> Unit,
    onSave: (String, Instant?, String) -> Unit,
    onToggle: () -> Unit,
    onDelete: () -> Unit
) {
    var title by rememberSaveable(item.id) { mutableStateOf(item.title) }
    var dueDate by rememberSaveable(item.id) { mutableStateOf(item.dueDate) }
    var groupID by rememberSaveable(item.id) {
        mutableStateOf(item.groupID ?: groups.first().id)
    }
    var showDatePicker by rememberSaveable { mutableStateOf(false) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .imePadding()
                .navigationBarsPadding()
                .padding(horizontal = 22.dp)
                .padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("任务详情", fontSize = 24.sp, fontWeight = FontWeight.Bold)
                    Text(
                        "修改标题、日期或所属分组",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontSize = 13.sp
                    )
                }
                IconButton(onClick = onDismiss, modifier = Modifier.size(48.dp)) {
                    Icon(Icons.Default.Close, contentDescription = "关闭")
                }
            }

            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("任务标题") },
                singleLine = false,
                maxLines = 3,
                shape = RoundedCornerShape(16.dp)
            )

            Text("到期日期", fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                FilledTonalButton(
                    onClick = { showDatePicker = true },
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                ) {
                    Icon(Icons.Default.CalendarMonth, null, Modifier.size(19.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(
                        dueDate?.atZone(ZoneId.systemDefault())?.toLocalDate()
                            ?.format(DateTimeFormatter.ofPattern("M月d日"))
                            ?: "设置日期"
                    )
                }
                if (dueDate != null) {
                    OutlinedButton(
                        onClick = { dueDate = null },
                        modifier = Modifier.height(48.dp)
                    ) {
                        Text("清除")
                    }
                }
            }

            if (groups.size > 1) {
                Text("所属分组", fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    groups.forEach { group ->
                        FilterChip(
                            selected = groupID == group.id,
                            onClick = { groupID = group.id },
                            label = { Text(group.name) },
                            leadingIcon = if (groupID == group.id) {
                                {
                                    Icon(
                                        Icons.Default.Check,
                                        contentDescription = null,
                                        Modifier.size(16.dp)
                                    )
                                }
                            } else null
                        )
                    }
                }
            }

            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                FilledTonalButton(
                    onClick = onToggle,
                    modifier = Modifier
                        .weight(1f)
                        .height(50.dp)
                ) {
                    Icon(
                        if (item.isCompleted) {
                            Icons.Default.RadioButtonUnchecked
                        } else Icons.Default.CheckCircle,
                        contentDescription = null,
                        modifier = Modifier.size(19.dp)
                    )
                    Spacer(Modifier.width(7.dp))
                    Text(if (item.isCompleted) "恢复待办" else "标记完成")
                }
                Button(
                    enabled = title.isNotBlank(),
                    onClick = { onSave(title.trim(), dueDate, groupID) },
                    modifier = Modifier
                        .weight(1f)
                        .height(50.dp)
                ) {
                    Text("保存修改")
                }
            }
            TextButton(
                onClick = onDelete,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp)
            ) {
                Icon(
                    Icons.Default.Delete,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.error,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(Modifier.width(7.dp))
                Text("删除任务", color = MaterialTheme.colorScheme.error)
            }
        }
    }

    if (showDatePicker) {
        SlateDatePickerDialog(
            initial = dueDate,
            allowClear = true,
            onDismiss = { showDatePicker = false },
            onConfirm = {
                dueDate = it
                showDatePicker = false
            }
        )
    }
}

@Composable
private fun DueDateText(dueDate: Instant, completed: Boolean) {
    val localDate = dueDate.atZone(ZoneId.systemDefault()).toLocalDate()
    val today = LocalDate.now()
    val label = when (localDate) {
        today -> "今天"
        today.plusDays(1) -> "明天"
        today.minusDays(1) -> "昨天"
        else -> localDate.format(DateTimeFormatter.ofPattern("M月d日"))
    }
    val overdue = localDate.isBefore(today) && !completed
    Text(
        label,
        color = if (overdue) SlateOrange else MaterialTheme.colorScheme.onSurfaceVariant,
        fontSize = 12.sp,
        fontWeight = if (overdue) FontWeight.SemiBold else FontWeight.Normal
    )
}

@Composable
private fun DueDateLabel(
    dueDate: Instant,
    modifier: Modifier = Modifier,
    onClear: () -> Unit
) {
    val localDate = dueDate.atZone(ZoneId.systemDefault()).toLocalDate()
    AssistChip(
        onClick = onClear,
        modifier = modifier,
        label = { Text(localDate.format(DateTimeFormatter.ofPattern("M月d日"))) },
        leadingIcon = { Icon(Icons.Default.CalendarMonth, null, Modifier.size(16.dp)) },
        trailingIcon = { Icon(Icons.Default.Close, "清除", Modifier.size(15.dp)) }
    )
}

@Composable
private fun SlateDatePickerDialog(
    initial: Instant?,
    allowClear: Boolean = false,
    onDismiss: () -> Unit,
    onConfirm: (Instant?) -> Unit
) {
    val initialMillis = initial
        ?.atZone(ZoneId.systemDefault())
        ?.toLocalDate()
        ?.atStartOfDay(ZoneOffset.UTC)
        ?.toInstant()
        ?.toEpochMilli()
    val pickerState = rememberDatePickerState(
        initialSelectedDateMillis = initialMillis,
        initialDisplayedMonthMillis = initialMillis
    )
    val selectedLabel = pickerState.selectedDateMillis
        ?.let(Instant::ofEpochMilli)
        ?.atZone(ZoneId.of("UTC"))
        ?.toLocalDate()
        ?.format(DateTimeFormatter.ofPattern("yyyy年M月d日"))
        ?: "尚未选择日期"

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            shape = RoundedCornerShape(28.dp),
            color = MaterialTheme.colorScheme.surface,
            tonalElevation = 6.dp
        ) {
            Column {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(start = 22.dp, top = 18.dp, end = 10.dp, bottom = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(
                            "选择日期",
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            selectedLabel,
                            color = MaterialTheme.colorScheme.primary,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                    IconButton(onClick = onDismiss, modifier = Modifier.size(48.dp)) {
                        Icon(Icons.Default.Close, contentDescription = "关闭日期选择")
                    }
                }
                DatePicker(
                    state = pickerState,
                    title = null,
                    headline = null,
                    showModeToggle = false,
                    colors = DatePickerDefaults.colors(
                        selectedDayContainerColor = MaterialTheme.colorScheme.primary,
                        selectedDayContentColor = MaterialTheme.colorScheme.onPrimary,
                        todayDateBorderColor = MaterialTheme.colorScheme.primary,
                        todayContentColor = MaterialTheme.colorScheme.primary
                    )
                )
                HorizontalDivider()
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    if (allowClear) {
                        TextButton(onClick = { onConfirm(null) }) {
                            Text("清除", color = MaterialTheme.colorScheme.error)
                        }
                    }
                    TextButton(onClick = onDismiss) { Text("取消") }
                    Button(
                        enabled = pickerState.selectedDateMillis != null,
                        onClick = {
                            onConfirm(
                                pickerState.selectedDateMillis?.let(Instant::ofEpochMilli)
                            )
                        },
                        modifier = Modifier.height(44.dp)
                    ) {
                        Text("确定")
                    }
                }
            }
        }
    }
}

@Composable
private fun TextEntryDialog(
    title: String,
    initialValue: String,
    confirmLabel: String,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit
) {
    var value by rememberSaveable(initialValue) { mutableStateOf(initialValue) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            OutlinedTextField(
                value = value,
                onValueChange = { value = it },
                singleLine = true,
                shape = RoundedCornerShape(14.dp)
            )
        },
        confirmButton = {
            TextButton(
                enabled = value.isNotBlank(),
                onClick = { onConfirm(value) }
            ) { Text(confirmLabel) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("取消") } }
    )
}

@Composable
private fun EmptyState(
    hasSearch: Boolean,
    modifier: Modifier = Modifier
) {
    Box(modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Box(
                Modifier
                    .size(70.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    if (hasSearch) Icons.Default.Search else Icons.Default.Check,
                    null,
                    Modifier.size(30.dp),
                    tint = MaterialTheme.colorScheme.primary
                )
            }
            Spacer(Modifier.height(14.dp))
            Text(
                if (hasSearch) "没有匹配的待办" else "记下每件事，按自己的节奏完成。",
                fontWeight = FontWeight.SemiBold,
                fontSize = 17.sp
            )
            Text(
                if (hasSearch) "换个关键词试试" else "在下方输入，记下下一件事",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = 13.sp
            )
        }
    }
}

@Composable
private fun SettingsSheet(
    state: SlateUiState,
    onDismiss: () -> Unit,
    onTheme: (SlateThemeMode) -> Unit,
    onReminders: (Boolean) -> Unit,
    onImport: () -> Unit,
    onExport: () -> Unit,
    onSyncSetup: () -> Unit,
    onSyncNow: () -> Unit,
    onSyncSignOut: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 22.dp)
                .padding(bottom = 28.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("设置", fontSize = 24.sp, fontWeight = FontWeight.Bold)
                    Text(
                        "外观、提醒与数据",
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                IconButton(onClick = onDismiss, modifier = Modifier.size(48.dp)) {
                    Icon(Icons.Default.Close, contentDescription = "关闭设置")
                }
            }
            Spacer(Modifier.height(22.dp))

            Text("外观", fontWeight = FontWeight.SemiBold)
            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                ThemeChoice(
                    "深色",
                    Icons.Default.DarkMode,
                    state.themeMode == SlateThemeMode.DARK,
                    Modifier.weight(1f)
                ) { onTheme(SlateThemeMode.DARK) }
                ThemeChoice(
                    "浅色",
                    Icons.Default.LightMode,
                    state.themeMode == SlateThemeMode.LIGHT,
                    Modifier.weight(1f)
                ) { onTheme(SlateThemeMode.LIGHT) }
                ThemeChoice(
                    "系统",
                    Icons.Default.Sync,
                    state.themeMode == SlateThemeMode.SYSTEM,
                    Modifier.weight(1f)
                ) { onTheme(SlateThemeMode.SYSTEM) }
            }

            HorizontalDivider(Modifier.padding(vertical = 20.dp))
            SettingRow(
                icon = Icons.Default.Notifications,
                title = "到期提醒",
                subtitle = "到期当天上午 9 点通知"
            ) {
                Switch(
                    checked = state.remindersEnabled,
                    onCheckedChange = onReminders,
                    colors = SwitchDefaults.colors(
                        uncheckedTrackColor = MaterialTheme.colorScheme.surfaceVariant,
                        uncheckedBorderColor = MaterialTheme.colorScheme.outline,
                        uncheckedThumbColor = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                )
            }

            HorizontalDivider(Modifier.padding(vertical = 20.dp))
            Text("数据", fontWeight = FontWeight.SemiBold)
            Text(
                "与 macOS 版共用序事（Slate v3）JSON 格式",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = 13.sp
            )
            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                OutlinedButton(onClick = onImport, modifier = Modifier.weight(1f)) {
                    Icon(Icons.Default.FileDownload, null, Modifier.size(18.dp))
                    Spacer(Modifier.width(7.dp))
                    Text("导入")
                }
                OutlinedButton(onClick = onExport, modifier = Modifier.weight(1f)) {
                    Icon(Icons.Default.FileUpload, null, Modifier.size(18.dp))
                    Spacer(Modifier.width(7.dp))
                    Text("导出")
                }
            }
            Spacer(Modifier.height(18.dp))
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(enabled = !state.sync.isSignedIn, onClick = onSyncSetup),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.72f)
                ),
                shape = RoundedCornerShape(18.dp)
            ) {
                if (state.sync.isSignedIn) {
                    SettingRow(
                        icon = Icons.Default.Sync,
                        title = "双端同步",
                        subtitle = state.sync.accountEmail ?: "已登录"
                    ) {
                        if (state.sync.isSyncing) {
                            CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.dp)
                        }
                    }
                    val lastSyncLabel = if (state.sync.lastSyncedAt == Instant.EPOCH) {
                        "尚未完成首次同步"
                    } else {
                        val local = state.sync.lastSyncedAt.atZone(ZoneId.systemDefault())
                        "上次同步 ${local.format(DateTimeFormatter.ofPattern("M月d日 HH:mm"))}"
                    }
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .padding(start = 52.dp, end = 12.dp, bottom = 14.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            lastSyncLabel,
                            modifier = Modifier.weight(1f),
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            fontSize = 12.sp
                        )
                    }
                    if (state.sync.isSyncing) {
                        LinearProgressIndicator(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 14.dp)
                        )
                    }
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .padding(start = 52.dp, end = 12.dp, bottom = 12.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Button(
                            onClick = onSyncNow,
                            enabled = !state.sync.isSyncing,
                            modifier = Modifier
                                .weight(1f)
                                .height(46.dp)
                        ) {
                            Icon(Icons.Default.Sync, null, Modifier.size(18.dp))
                            Spacer(Modifier.width(7.dp))
                            Text("立即同步")
                        }
                        TextButton(
                            onClick = onSyncSignOut,
                            enabled = !state.sync.isSyncing,
                            modifier = Modifier.height(46.dp)
                        ) {
                            Text(
                                "退出",
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                } else {
                    SettingRow(
                        icon = Icons.Default.Sync,
                        title = "双端同步",
                        subtitle = "Supabase 安全账户 · 冲突自动合并"
                    ) {
                        Text(
                            "配置",
                            color = MaterialTheme.colorScheme.primary,
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 13.sp
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SyncSetupDialog(
    initialURL: String,
    initialKey: String,
    onDismiss: () -> Unit,
    onSubmit: (String, String, String, String, Boolean) -> Unit
) {
    var projectURL by rememberSaveable { mutableStateOf(initialURL) }
    var publishableKey by rememberSaveable { mutableStateOf(initialKey) }
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    val canSubmit = SupabaseConfiguration(projectURL, publishableKey).isAllowedEndpoint &&
        publishableKey.isNotBlank() &&
        email.isNotBlank() &&
        password.length >= 6

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("配置双端同步") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    "序事云同步已配置，账户数据通过行级安全策略隔离。",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontSize = 12.sp
                )
                OutlinedTextField(
                    value = email,
                    onValueChange = { email = it },
                    label = { Text("同步账户邮箱") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                    singleLine = true
                )
                OutlinedTextField(
                    value = password,
                    onValueChange = { password = it },
                    label = { Text("密码") },
                    visualTransformation = PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    singleLine = true
                )
            }
        },
        confirmButton = {
            TextButton(
                enabled = canSubmit,
                onClick = {
                    onSubmit(projectURL, publishableKey, email, password, false)
                }
            ) { Text("登录") }
        },
        dismissButton = {
            Row {
                TextButton(
                    enabled = canSubmit,
                    onClick = {
                        onSubmit(projectURL, publishableKey, email, password, true)
                    }
                ) { Text("注册") }
                TextButton(onClick = onDismiss) { Text("取消") }
            }
        }
    )
}

@Composable
private fun ThemeChoice(
    label: String,
    icon: ImageVector,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    val color = if (selected) {
        MaterialTheme.colorScheme.primaryContainer
    } else MaterialTheme.colorScheme.surfaceVariant
    Surface(
        modifier = modifier
            .defaultMinSize(minHeight = 86.dp)
            .semantics {
                role = Role.RadioButton
                this.selected = selected
            }
            .clickable(onClick = onClick),
        color = color,
        shape = RoundedCornerShape(16.dp),
        border = if (selected) {
            BorderStroke(1.5.dp, MaterialTheme.colorScheme.primary)
        } else {
            BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.55f))
        }
    ) {
        Column(
            Modifier.padding(vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(icon, null, Modifier.size(20.dp))
            Spacer(Modifier.height(5.dp))
            Text(label, fontSize = 13.sp, fontWeight = FontWeight.Medium)
        }
    }
}

@Composable
private fun SettingRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    trailing: @Composable () -> Unit
) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp, horizontal = 2.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(icon, null, tint = MaterialTheme.colorScheme.primary)
        Spacer(Modifier.width(13.dp))
        Column(Modifier.weight(1f)) {
            Text(title, fontWeight = FontWeight.Medium)
            Text(
                subtitle,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = 12.sp
            )
        }
        trailing()
    }
}
