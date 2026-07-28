@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.thevipsong.slate.ui

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
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
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.FileDownload
import androidx.compose.material.icons.filled.FileUpload
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material.icons.filled.ViewList
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.thevipsong.slate.data.SlateThemeMode
import com.thevipsong.slate.data.SlateTodoGroup
import com.thevipsong.slate.data.SlateTodoItem
import com.thevipsong.slate.data.TodoFilter
import com.thevipsong.slate.sync.SupabaseConfiguration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

@Composable
fun SlateScreen(
    state: SlateUiState,
    viewModel: SlateViewModel
) {
    val snackbarHost = remember { SnackbarHostState() }
    var showSettings by rememberSaveable { mutableStateOf(false) }
    var showAddGroup by rememberSaveable { mutableStateOf(false) }
    var showSyncSetup by rememberSaveable { mutableStateOf(false) }
    var groupToManage by remember { mutableStateOf<SlateTodoGroup?>(null) }
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

    LaunchedEffect(state.message) {
        state.message?.let {
            snackbarHost.showSnackbar(it)
            viewModel.clearMessage()
        }
    }

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        containerColor = MaterialTheme.colorScheme.background,
        contentWindowInsets = WindowInsets(0),
        snackbarHost = { SnackbarHost(snackbarHost) }
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
                    .navigationBarsPadding()
                    .imePadding()
            ) {
                SlateHeader(
                    state = state,
                    onSettings = { showSettings = true }
                )
                GroupStrip(
                    groups = state.groups,
                    selectedID = state.selectedGroupID,
                    onSelect = viewModel::selectGroup,
                    onManage = { groupToManage = it },
                    onAdd = { showAddGroup = true }
                )
                TodoComposer(
                    onAdd = viewModel::addTodo
                )
                FilterAndSearch(
                    selected = state.filter,
                    search = state.search,
                    onFilter = viewModel::setFilter,
                    onSearch = viewModel::setSearch
                )

                if (state.visibleItems.isEmpty()) {
                    EmptyState(
                        hasSearch = state.search.isNotBlank(),
                        modifier = Modifier.weight(1f)
                    )
                } else {
                    TodoList(
                        items = state.visibleItems,
                        groups = state.groups,
                        selectedID = state.selectedItemID,
                        onSelect = viewModel::selectTodo,
                        onToggle = viewModel::toggleTodo,
                        onRename = viewModel::renameTodo,
                        onDate = viewModel::setDueDate,
                        onMove = viewModel::moveTodo,
                        onDelete = viewModel::deleteTodo,
                        onReorder = viewModel::reorderTodo,
                        modifier = Modifier.weight(1f)
                    )
                }
            }
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
    onSettings: () -> Unit
) {
    val date = remember {
        LocalDate.now().format(
            DateTimeFormatter.ofPattern("M月d日 EEEE", Locale.SIMPLIFIED_CHINESE)
        )
    }
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                "Slate",
                fontSize = 30.sp,
                lineHeight = 34.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = (-0.8).sp
            )
            Text(
                "熟能生巧。",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = 14.sp
            )
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(date, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
            Text(
                "${state.pendingCount} 项待办 · 共 ${state.totalCount} 项",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = 12.sp
            )
        }
        Spacer(Modifier.width(6.dp))
        IconButton(onClick = onSettings) {
            Icon(Icons.Default.Settings, contentDescription = "设置")
        }
    }
}

@Composable
private fun GroupStrip(
    groups: List<SlateTodoGroup>,
    selectedID: String,
    onSelect: (String) -> Unit,
    onManage: (SlateTodoGroup) -> Unit,
    onAdd: () -> Unit
) {
    LazyRow(
        modifier = Modifier.fillMaxWidth(),
        contentPadding = PaddingValues(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(groups, key = SlateTodoGroup::id) { group ->
            val selected = group.id == selectedID
            FilterChip(
                selected = selected,
                onClick = { onSelect(group.id) },
                label = {
                    Text(
                        group.name,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium
                    )
                },
                leadingIcon = {
                    Icon(
                        Icons.Default.Folder,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp)
                    )
                },
                trailingIcon = if (selected) {
                    {
                        Icon(
                            Icons.Default.MoreHoriz,
                            contentDescription = "管理分组",
                            modifier = Modifier
                                .size(18.dp)
                                .clickable { onManage(group) }
                        )
                    }
                } else null
            )
        }
        item {
            FilledIconButton(
                onClick = onAdd,
                modifier = Modifier.size(40.dp)
            ) {
                Icon(Icons.Default.Add, contentDescription = "添加分组")
            }
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
private fun TodoComposer(onAdd: (String, Instant?) -> Unit) {
    val focusManager = LocalFocusManager.current
    var title by rememberSaveable { mutableStateOf("") }
    var dueDate by rememberSaveable { mutableStateOf<Instant?>(null) }
    var showDatePicker by rememberSaveable { mutableStateOf(false) }

    fun submit() {
        if (title.isBlank()) return
        onAdd(title, dueDate)
        title = ""
        dueDate = null
        focusManager.clearFocus()
    }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 14.dp),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.92f)
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            Modifier.padding(start = 16.dp, top = 6.dp, end = 8.dp, bottom = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                modifier = Modifier.weight(1f),
                placeholder = { Text("添加新任务…") },
                singleLine = true,
                shape = RoundedCornerShape(14.dp),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = { submit() })
            )
            IconButton(onClick = { showDatePicker = true }) {
                Icon(
                    Icons.Default.CalendarMonth,
                    contentDescription = "设置日期",
                    tint = if (dueDate == null) {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    } else MaterialTheme.colorScheme.primary
                )
            }
            Button(
                enabled = title.isNotBlank(),
                onClick = { submit() },
                contentPadding = PaddingValues(horizontal = 15.dp)
            ) {
                Text("添加")
            }
        }
        dueDate?.let {
            DueDateLabel(
                dueDate = it,
                modifier = Modifier.padding(start = 18.dp, bottom = 10.dp),
                onClear = { dueDate = null }
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
private fun FilterAndSearch(
    selected: TodoFilter,
    search: String,
    onFilter: (TodoFilter) -> Unit,
    onSearch: (String) -> Unit
) {
    Column(Modifier.padding(horizontal = 20.dp)) {
        LazyRow(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
            val filters = listOf(
                TodoFilter.ALL to "全部",
                TodoFilter.PENDING to "待完成",
                TodoFilter.COMPLETED to "已完成",
                TodoFilter.OVERDUE to "逾期"
            )
            items(filters) { (filter, label) ->
                FilterChip(
                    selected = selected == filter,
                    onClick = { onFilter(filter) },
                    label = { Text(label) },
                    leadingIcon = if (selected == filter) {
                        { Icon(Icons.Default.Check, null, Modifier.size(16.dp)) }
                    } else null
                )
            }
        }
        OutlinedTextField(
            value = search,
            onValueChange = onSearch,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 6.dp, bottom = 10.dp),
            placeholder = { Text("搜索当前分组") },
            leadingIcon = { Icon(Icons.Default.Search, null) },
            trailingIcon = if (search.isNotBlank()) {
                {
                    IconButton(onClick = { onSearch("") }) {
                        Icon(Icons.Default.Close, contentDescription = "清除搜索")
                    }
                }
            } else null,
            singleLine = true,
            shape = RoundedCornerShape(16.dp)
        )
    }
}

@Composable
private fun TodoList(
    items: List<SlateTodoItem>,
    groups: List<SlateTodoGroup>,
    selectedID: String?,
    onSelect: (String) -> Unit,
    onToggle: (String) -> Unit,
    onRename: (String, String) -> Unit,
    onDate: (String, Instant?) -> Unit,
    onMove: (String, String) -> Unit,
    onDelete: (String) -> Unit,
    onReorder: (String, String) -> Unit,
    modifier: Modifier = Modifier
) {
    LazyColumn(
        modifier = modifier.fillMaxWidth(),
        contentPadding = PaddingValues(start = 20.dp, end = 20.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(9.dp)
    ) {
        items(items, key = SlateTodoItem::id) { item ->
            val index = items.indexOfFirst { it.id == item.id }
            TodoCard(
                item = item,
                groups = groups,
                selected = selectedID == item.id,
                canMoveUp = index > 0,
                canMoveDown = index < items.lastIndex,
                onSelect = { onSelect(item.id) },
                onToggle = { onToggle(item.id) },
                onRename = { onRename(item.id, it) },
                onDate = { onDate(item.id, it) },
                onMove = { onMove(item.id, it) },
                onDelete = { onDelete(item.id) },
                onMoveUp = { onReorder(item.id, items[index - 1].id) },
                onMoveDown = { onReorder(item.id, items[index + 1].id) }
            )
        }
    }
}

@Composable
private fun TodoCard(
    item: SlateTodoItem,
    groups: List<SlateTodoGroup>,
    selected: Boolean,
    canMoveUp: Boolean,
    canMoveDown: Boolean,
    onSelect: () -> Unit,
    onToggle: () -> Unit,
    onRename: (String) -> Unit,
    onDate: (Instant?) -> Unit,
    onMove: (String) -> Unit,
    onDelete: () -> Unit,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit
) {
    var showEdit by rememberSaveable { mutableStateOf(false) }
    var showDate by rememberSaveable { mutableStateOf(false) }
    var showMove by rememberSaveable { mutableStateOf(false) }
    val container by animateColorAsState(
        if (selected) MaterialTheme.colorScheme.primaryContainer
        else MaterialTheme.colorScheme.surface,
        label = "selection"
    )
    val elevation by animateFloatAsState(if (selected) 4f else 0f, label = "elevation")

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onSelect),
        colors = CardDefaults.cardColors(containerColor = container),
        border = BorderStroke(
            1.dp,
            if (selected) MaterialTheme.colorScheme.primary
            else MaterialTheme.colorScheme.outline.copy(alpha = 0.55f)
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = elevation.dp),
        shape = RoundedCornerShape(17.dp)
    ) {
        Column {
            Row(
                modifier = Modifier.padding(horizontal = 14.dp, vertical = 13.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(
                    onClick = onToggle,
                    modifier = Modifier.size(38.dp)
                ) {
                    Icon(
                        if (item.isCompleted) Icons.Default.CheckCircle
                        else Icons.Default.RadioButtonUnchecked,
                        contentDescription = if (item.isCompleted) "标为未完成" else "完成",
                        tint = if (item.isCompleted) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Spacer(Modifier.width(4.dp))
                Column(Modifier.weight(1f)) {
                    Text(
                        item.title,
                        fontWeight = FontWeight.SemiBold,
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
                    Icons.Default.MoreHoriz,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.alpha(if (selected) 1f else 0.3f)
                )
            }
            AnimatedVisibility(visible = selected) {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(start = 12.dp, end = 12.dp, bottom = 10.dp),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    CompactAction(
                        Icons.Default.KeyboardArrowUp,
                        "上移",
                        enabled = canMoveUp,
                        onClick = onMoveUp
                    )
                    CompactAction(
                        Icons.Default.KeyboardArrowDown,
                        "下移",
                        enabled = canMoveDown,
                        onClick = onMoveDown
                    )
                    CompactAction(Icons.Default.CalendarMonth, "日期") { showDate = true }
                    CompactAction(Icons.Default.Edit, "编辑") { showEdit = true }
                    if (groups.size > 1) {
                        CompactAction(Icons.Default.SwapHoriz, "移动") { showMove = true }
                    }
                    CompactAction(Icons.Default.Delete, "删除", tint = MaterialTheme.colorScheme.error) {
                        onDelete()
                    }
                }
            }
        }
    }

    if (showEdit) {
        TextEntryDialog(
            title = "编辑任务",
            initialValue = item.title,
            confirmLabel = "保存",
            onDismiss = { showEdit = false },
            onConfirm = {
                onRename(it)
                showEdit = false
            }
        )
    }
    if (showDate) {
        SlateDatePickerDialog(
            initial = item.dueDate,
            allowClear = true,
            onDismiss = { showDate = false },
            onConfirm = {
                onDate(it)
                showDate = false
            }
        )
    }
    if (showMove) {
        MoveGroupDialog(
            groups = groups.filter { it.id != item.groupID },
            onDismiss = { showMove = false },
            onSelect = {
                onMove(it)
                showMove = false
            }
        )
    }
}

@Composable
private fun CompactAction(
    icon: ImageVector,
    label: String,
    enabled: Boolean = true,
    tint: Color = MaterialTheme.colorScheme.onSurfaceVariant,
    onClick: () -> Unit
) {
    IconButton(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.size(38.dp)
    ) {
        Icon(
            icon,
            contentDescription = label,
            tint = if (enabled) tint else tint.copy(alpha = 0.28f),
            modifier = Modifier.size(19.dp)
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
    val initialMillis = initial?.toEpochMilli()
    val pickerState = rememberDatePickerState(initialSelectedDateMillis = initialMillis)
    DatePickerDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(
                onClick = {
                    val instant = pickerState.selectedDateMillis?.let(Instant::ofEpochMilli)
                    onConfirm(instant)
                }
            ) { Text("确定") }
        },
        dismissButton = {
            Row {
                if (allowClear) {
                    TextButton(onClick = { onConfirm(null) }) { Text("清除") }
                }
                TextButton(onClick = onDismiss) { Text("取消") }
            }
        }
    ) {
        val selectedLabel = pickerState.selectedDateMillis
            ?.let(Instant::ofEpochMilli)
            ?.atZone(ZoneId.of("UTC"))
            ?.toLocalDate()
            ?.format(DateTimeFormatter.ofPattern("yyyy年M月d日"))
            ?: "请选择日期"
        DatePicker(
            state = pickerState,
            title = { Text("选择日期") },
            headline = { Text(selectedLabel) }
        )
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
private fun MoveGroupDialog(
    groups: List<SlateTodoGroup>,
    onDismiss: () -> Unit,
    onSelect: (String) -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("移动到分组") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                groups.forEach { group ->
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onSelect(group.id) },
                        shape = RoundedCornerShape(12.dp),
                        color = MaterialTheme.colorScheme.surfaceVariant
                    ) {
                        Row(
                            Modifier.padding(14.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.Folder, null, Modifier.size(20.dp))
                            Spacer(Modifier.width(10.dp))
                            Text(group.name, fontWeight = FontWeight.Medium)
                        }
                    }
                }
            }
        },
        confirmButton = {},
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
                if (hasSearch) "没有匹配的待办" else "都处理好了",
                fontWeight = FontWeight.SemiBold,
                fontSize = 17.sp
            )
            Text(
                if (hasSearch) "换个关键词试试" else "添加下一件要做的事吧",
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
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 22.dp)
                .padding(bottom = 28.dp)
        ) {
            Text("设置", fontSize = 24.sp, fontWeight = FontWeight.Bold)
            Text(
                "外观、提醒与数据",
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
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
                    onCheckedChange = onReminders
                )
            }

            HorizontalDivider(Modifier.padding(vertical = 20.dp))
            Text("数据", fontWeight = FontWeight.SemiBold)
            Text(
                "与 macOS 版共用 Slate v3 JSON 格式",
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
                Button(onClick = onExport, modifier = Modifier.weight(1f)) {
                    Icon(Icons.Default.FileUpload, null, Modifier.size(18.dp))
                    Spacer(Modifier.width(7.dp))
                    Text("导出")
                }
            }
            Spacer(Modifier.height(18.dp))
            OutlinedCard(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(enabled = !state.sync.isSignedIn, onClick = onSyncSetup)
            ) {
                if (state.sync.isSignedIn) {
                    SettingRow(
                        icon = Icons.Default.Sync,
                        title = "双端同步",
                        subtitle = state.sync.accountEmail ?: "已登录"
                    ) {
                        if (state.sync.isSyncing) {
                            CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.dp)
                        } else {
                            TextButton(onClick = onSyncNow) { Text("立即同步") }
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
                            .padding(start = 52.dp, end = 12.dp, bottom = 10.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            lastSyncLabel,
                            modifier = Modifier.weight(1f),
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            fontSize = 12.sp
                        )
                        TextButton(onClick = onSyncSignOut) { Text("退出") }
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
                    "Slate Cloud 已配置，账户数据通过行级安全策略隔离。",
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
        modifier = modifier.clickable(onClick = onClick),
        color = color,
        shape = RoundedCornerShape(14.dp),
        border = if (selected) BorderStroke(1.dp, MaterialTheme.colorScheme.primary) else null
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
