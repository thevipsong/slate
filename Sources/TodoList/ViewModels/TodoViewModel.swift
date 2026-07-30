import Combine
import Foundation

@MainActor
protocol TodoReminderScheduling: AnyObject {
    func sync(items: [TodoItem])
}

@MainActor
final class TodoViewModel: ObservableObject {
    @Published private(set) var items: [TodoItem] = []
    @Published private(set) var groups: [TodoGroup] = []
    @Published var newTitle = ""
    @Published var filter: TodoFilter = .pending
    /// 标题搜索关键字（叠加在 filter 之上，作用于当前组）
    @Published var searchText = ""
    /// 添加新任务时附带的到期日（nil = 不设）
    @Published var newDueDate: Date? = nil
    @Published var editingItemID: UUID?
    @Published var editingTitle = ""
    @Published var selectedItemIDs: Set<UUID> = []
    @Published var selectedGroupID: UUID
    @Published private(set) var errorMessage: String?
    @Published var syncProjectURL = UserDefaults.standard.string(forKey: "sync.projectURL")
        ?? SlateCloudDefaults.projectURL
    @Published var syncPublishableKey = UserDefaults.standard.string(forKey: "sync.publishableKey")
        ?? SlateCloudDefaults.publishableKey
    @Published private(set) var syncAccountEmail: String?
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var syncStatusMessage: String?

    /// Shift 范围选择的锚点（最后一次无修饰点击的行）
    private var selectionAnchorID: UUID?

    private static let archiveVersion = TodoArchive.currentVersion

    private let store: TodoFileStore
    private let now: () -> Date
    private weak var reminderScheduler: TodoReminderScheduling?
    private let syncStateStore: SlateSyncStateStore
    private let syncCoordinator: SlateSyncCoordinator

    // 派生属性缓存
    private var itemsByGroup: [UUID: [TodoItem]] = [:]
    private var countsByGroup: [UUID: (total: Int, completed: Int)] = [:]
    /// 只缓存当前组+当前筛选的可见列表（其他组的数据读了也没用，不驻留）
    private var cachedVisibleItems: [TodoItem] = []

    // 防抖持久化
    private var persistTask: Task<Void, Never>?
    private var autoSyncTask: Task<Void, Never>?
    private var remoteRefreshTask: Task<Void, Never>?
    private var isRefreshingRemote = false
    private var persistGeneration: UInt64 = 0
    /// 所有落盘操作走这条串行队列：
    /// 防抖只能取消还在 sleep 的任务，已进入 save 的任务若与新任务并发，
    /// 备份轮转会交错、旧快照可能覆盖新快照。串行队列保证 FIFO 顺序。
    private let saveQueue = DispatchQueue(label: "slate.save")

    // 撤销栈
    private struct UndoSnapshot {
        let items: [TodoItem]
        let groups: [TodoGroup]
        let selectedGroupID: UUID
        let filter: TodoFilter
    }
    private var undoStack: [UndoSnapshot] = []
    private let maxUndoSteps = 30

    init(
        store: TodoFileStore = TodoFileStore(),
        now: @escaping () -> Date = Date.init,
        reminderScheduler: TodoReminderScheduling? = nil
    ) {
        self.store = store
        self.now = now
        self.reminderScheduler = reminderScheduler
        let syncBaseDirectory = store.fileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let stateStore = SlateSyncStateStore(baseDirectory: syncBaseDirectory)
        let sessionStore = SlateSecureSessionStore(namespace: store.fileURL.path)
        self.syncStateStore = stateStore
        self.syncCoordinator = SlateSyncCoordinator(
            stateStore: stateStore,
            sessionStore: sessionStore
        )
        let initial = TodoGroup.defaultGroup()
        self.selectedGroupID = initial.id
        self.groups = [initial]
        load()
        Task { [weak self] in
            guard let self else { return }
            let session = await self.syncCoordinator.storedSession()
            let syncState = await self.syncStateStore.load()
            self.syncAccountEmail = session?.email
            self.lastSyncedAt = syncState.lastSyncedAt == .distantPast
                ? nil
                : syncState.lastSyncedAt
            self.startAutomaticSync()
        }
    }

    // MARK: - 派生属性

    var visibleItems: [TodoItem] {
        cachedVisibleItems
    }

    /// 指定分组的待完成数量（用于分组栏角标）
    func pendingCount(for groupID: UUID) -> Int {
        let counts = countsByGroup[groupID]
        return (counts?.total ?? 0) - (counts?.completed ?? 0)
    }

    /// 指定分组的总任务数（含已完成）
    func totalCount(for groupID: UUID) -> Int {
        countsByGroup[groupID]?.total ?? 0
    }

    /// 全量统计走缓存聚合（O(组数)），HeaderView 不要自己扫 items
    var totalItemCount: Int { countsByGroup.values.reduce(0) { $0 + $1.total } }
    var totalCompletedCount: Int { countsByGroup.values.reduce(0) { $0 + $1.completed } }
    var totalPendingCount: Int { countsByGroup.values.reduce(0) { $0 + $1.total - $1.completed } }
    var totalOverdueCount: Int {
        items.filter { !$0.isCompleted && (($0.dueDate ?? .distantFuture) < startOfToday()) }.count
    }

    var selectedCount: Int { selectedItemIDs.count }

    var hasEditableSelection: Bool { !selectedItemIDs.isEmpty }

    var canAdd: Bool { !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var canUndo: Bool { !undoStack.isEmpty }

    /// 在修改前压栈，供 Cmd+Z 回退
    private func pushUndo() {
        let snap = UndoSnapshot(
            items: items,
            groups: groups,
            selectedGroupID: selectedGroupID,
            filter: filter
        )
        undoStack.append(snap)
        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }
    }

    func undo() {
        guard let snap = undoStack.popLast() else { return }
        items = snap.items
        groups = snap.groups
        selectedGroupID = snap.selectedGroupID
        filter = snap.filter
        editingItemID = nil
        editingTitle = ""
        selectedItemIDs.removeAll()
        selectionAnchorID = nil
        rebuildAllCaches()
        refreshVisible()
        schedulePersist()
    }

    /// 设置筛选条件并立即刷新可见任务缓存
    func setFilter(_ filter: TodoFilter) {
        guard self.filter != filter else { return }
        self.filter = filter
        refreshVisible()
    }

    /// 设置搜索关键字（空串视为不过滤），叠加在 filter 之上
    func setSearch(_ text: String) {
        guard searchText != text else { return }
        searchText = text
        refreshVisible()
    }

    /// 清除搜索关键字
    func clearSearch() {
        guard !searchText.isEmpty else { return }
        searchText = ""
        refreshVisible()
    }

    // MARK: - 任务 CRUD

    @discardableResult
    func addTodo(title rawTitle: String, dueDate: Date? = nil) -> Bool {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        pushUndo()
        let creationDate = now()
        let nextOrder = nextSortOrder(for: selectedGroupID)
        let newItem = TodoItem(
            title: title,
            createdAt: creationDate,
            groupID: selectedGroupID,
            sortOrder: nextOrder,
            dueDate: dueDate
        )
        items.append(newItem)
        rebuildCacheForGroup(selectedGroupID)
        refreshVisible()
        schedulePersist()
        return true
    }

    func addTodo() {
        guard addTodo(title: newTitle, dueDate: newDueDate) else { return }
        newTitle = ""
        newDueDate = nil
    }

    func toggleCompletion(of item: TodoItem) {
        guard let current = items.first(where: { $0.id == item.id }) else { return }
        setCompletion(!current.isCompleted, for: current.id)
    }

    /// 将任务设为明确的完成状态。与 toggle 不同，重复调用不会反向切换，
    /// 适合菜单栏延迟确认、同步回写等可能与其他更新并发的场景。
    func setCompletion(_ completed: Bool, for itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }),
              items[index].isCompleted != completed else {
            return
        }
        pushUndo()
        items[index].isCompleted = completed
        items[index].completedAt = completed ? now() : nil
        rebuildCacheForGroup(items[index].groupID ?? selectedGroupID)
        refreshVisible()
        schedulePersist()
    }

    /// 修改已有任务的到期日；传 nil 表示清除。
    func setDueDate(_ dueDate: Date?, for itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }),
              items[index].dueDate != dueDate else {
            return
        }
        pushUndo()
        items[index].dueDate = dueDate
        let groupID = items[index].groupID ?? selectedGroupID
        rebuildCacheForGroup(groupID)
        refreshVisible()
        schedulePersist()
    }

    func setSelectedCompleted(_ completed: Bool) {
        var changed = false
        pushUndo()
        let stamp = now()
        for index in items.indices where selectedItemIDs.contains(items[index].id) {
            guard items[index].isCompleted != completed else { continue }
            items[index].isCompleted = completed
            items[index].completedAt = completed ? stamp : nil
            changed = true
        }
        if changed {
            rebuildAllCaches()
            refreshVisible()
            schedulePersist()
        }
        clearSelection()
    }

    func delete(_ item: TodoItem) {
        pushUndo()
        items.removeAll { $0.id == item.id }
        selectedItemIDs.remove(item.id)
        if editingItemID == item.id {
            cancelEditing()
        }
        rebuildAllCaches()
        refreshVisible()
        schedulePersist()
    }

    func deleteSelected() {
        guard !selectedItemIDs.isEmpty else { return }
        pushUndo()
        items.removeAll { selectedItemIDs.contains($0.id) }
        selectedItemIDs.removeAll()
        rebuildAllCaches()
        refreshVisible()
        schedulePersist()
    }

    func moveItem(withID sourceID: UUID, before targetID: UUID) {
        guard sourceID != targetID,
              let source = items.first(where: { $0.id == sourceID }),
              let target = items.first(where: { $0.id == targetID }),
              source.groupID == target.groupID,
              let targetGroupID = source.groupID else {
            return
        }

        pushUndo()

        let groupItems = itemsByGroup[targetGroupID] ?? []
        guard let sourceIdx = groupItems.firstIndex(where: { $0.id == sourceID }),
              let targetIdxInFull = groupItems.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        // 直接在原始 groupItems 上操作：
        // 移除 source 后，若 target 原来在 source 后面则在 reordered 中位置 -1
        var reordered = groupItems
        reordered.remove(at: sourceIdx)
        let adjustedTarget = sourceIdx < targetIdxInFull
            ? targetIdxInFull - 1
            : targetIdxInFull

        // 把 source 插入到 adjustedTarget 位置——
        // source 在 target 上方 → 插到 target 后面（adjustedTarget + 1）
        // source 在 target 下方 → 插到 target 前面（adjustedTarget）
        // 相邻行拖动也能产生 1 格位移，不会"A拖到A正下方什么都没发生"
        let insertIndex: Int
        if sourceIdx < targetIdxInFull {
            insertIndex = min(adjustedTarget + 1, reordered.count)
        } else {
            insertIndex = adjustedTarget
        }
        reordered.insert(source, at: insertIndex)

        for (order, item) in reordered.enumerated() {
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index].sortOrder = Double(order)
            }
        }
        rebuildCacheForGroup(targetGroupID)
        refreshVisible()
        schedulePersist()
    }

    func moveItem(withID sourceID: UUID, toGroupID targetGroupID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == sourceID }),
              let oldGroupID = items[index].groupID,
              oldGroupID != targetGroupID else {
            return
        }
        pushUndo()
        let nextOrder = ((itemsByGroup[targetGroupID] ?? []).compactMap(\.sortOrder).max() ?? -1) + 1
        items[index].groupID = targetGroupID
        items[index].sortOrder = nextOrder
        rebuildCacheForGroup(oldGroupID)
        rebuildCacheForGroup(targetGroupID)
        refreshVisible()
        schedulePersist()
    }

    func beginEditing(_ item: TodoItem) {
        editingItemID = item.id
        editingTitle = item.title
    }

    func beginEditingSelectedItem() {
        guard selectedItemIDs.count == 1,
              let selectedID = selectedItemIDs.first,
              let item = items.first(where: { $0.id == selectedID }) else {
            return
        }
        beginEditing(item)
    }

    func commitEditing() {
        guard let editingID = editingItemID,
              let index = items.firstIndex(where: { $0.id == editingID }) else {
            cancelEditing()
            return
        }
        let title = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty, title != items[index].title {
            pushUndo()
            items[index].title = title
            schedulePersist()
        }
        cancelEditing()
    }

    func cancelEditing() {
        editingItemID = nil
        editingTitle = ""
    }

    enum SelectionMode {
        case single  // 无修饰：单选并重置锚点
        case range   // Shift：锚点到当前行的范围选择（锚点不动，支持连续调整）
        case toggle  // Cmd：切换单个
    }

    func select(_ item: TodoItem, mode: SelectionMode) {
        switch mode {
        case .single:
            selectedItemIDs = [item.id]
            selectionAnchorID = item.id
        case .toggle:
            if selectedItemIDs.contains(item.id) {
                selectedItemIDs.remove(item.id)
            } else {
                selectedItemIDs.insert(item.id)
            }
            selectionAnchorID = item.id
        case .range:
            let visible = visibleItems
            guard let anchorID = selectionAnchorID,
                  let anchorIdx = visible.firstIndex(where: { $0.id == anchorID }),
                  let targetIdx = visible.firstIndex(where: { $0.id == item.id }) else {
                // 没有有效锚点时退化为单选
                selectedItemIDs = [item.id]
                selectionAnchorID = item.id
                return
            }
            let range = min(anchorIdx, targetIdx)...max(anchorIdx, targetIdx)
            selectedItemIDs = Set(visible[range].map(\.id))
        }
    }

    func clearSelection() {
        selectedItemIDs.removeAll()
        selectionAnchorID = nil
    }

    func selectGroup(_ groupID: UUID) {
        guard groupID != selectedGroupID else { return }
        selectedGroupID = groupID
        cancelEditing()
        clearSelection()
        refreshVisible()
    }

    // MARK: - 分组管理

    func addGroup(name: String, systemImage: String = "folder") {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pushUndo()
        let nextOrder = (groups.compactMap(\.sortOrder).max() ?? -1) + 1
        let group = TodoGroup(name: trimmed, sortOrder: nextOrder, systemImage: systemImage)
        groups.append(group)
        schedulePersist()
    }

    func renameGroup(_ groupID: UUID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = groups.firstIndex(where: { $0.id == groupID }) else { return }
        pushUndo()
        groups[index].name = trimmed
        schedulePersist()
    }

    func updateGroupSymbol(_ groupID: UUID, systemImage: String) {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else { return }
        pushUndo()
        groups[index].systemImage = systemImage
        schedulePersist()
    }

    func deleteGroup(_ groupID: UUID) {
        guard groups.count > 1,
              let index = groups.firstIndex(where: { $0.id == groupID }) else { return }
        pushUndo()
        // 把组内任务移到第一个保留的组
        let keepID = groups.first(where: { $0.id != groupID })!.id
        for itemIndex in items.indices where items[itemIndex].groupID == groupID {
            items[itemIndex].groupID = keepID
        }
        groups.remove(at: index)
        if selectedGroupID == groupID {
            selectedGroupID = keepID
        }
        rebuildAllCaches()
        refreshVisible()
        schedulePersist()
    }

    // MARK: - 数据交换

    func exportArchiveData() throws -> Data {
        try store.encode(makeArchiveSnapshot())
    }

    /// 使用导入文件整体替换当前数据。调用方必须先向用户确认。
    func importArchiveData(_ data: Data) throws {
        let imported = try store.decode(data)
        pushUndo()

        var importedGroups = imported.groups.sorted { $0.sortOrder < $1.sortOrder }
        if importedGroups.isEmpty {
            importedGroups = [TodoGroup.defaultGroup()]
        }
        let fallbackGroupID = importedGroups[0].id
        let validGroupIDs = Set(importedGroups.map(\.id))
        let importedItems = imported.items
            .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { item in
                var repaired = item
                if repaired.groupID == nil || !validGroupIDs.contains(repaired.groupID!) {
                    repaired.groupID = fallbackGroupID
                }
                return repaired
            }

        groups = importedGroups
        items = importedItems
        selectedGroupID = fallbackGroupID
        editingItemID = nil
        editingTitle = ""
        selectedItemIDs.removeAll()
        selectionAnchorID = nil
        rebuildAllCaches()
        refreshVisible()
        persistImmediately()
        Task { await syncStateStore.markLocalChange() }
        scheduleAutoSync()
    }

    // MARK: - 双端同步

    var isSyncConfigured: Bool {
        SupabaseConfiguration(
            projectURL: syncProjectURL,
            publishableKey: syncPublishableKey
        ).isAllowedEndpoint && !syncPublishableKey.isEmpty
    }

    var isSyncSignedIn: Bool {
        syncAccountEmail != nil
    }

    func configureAndAuthenticateSync(
        email: String,
        password: String,
        createAccount: Bool
    ) {
        let configuration = SupabaseConfiguration(
            projectURL: syncProjectURL,
            publishableKey: syncPublishableKey
        )
        guard configuration.isAllowedEndpoint,
              !syncPublishableKey.isEmpty,
              !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              password.count >= 6 else {
            errorMessage = "请填写有效的项目 URL、publishable key、邮箱和至少 6 位密码。"
            return
        }

        isSyncing = true
        syncStatusMessage = "正在连接同步账户…"
        UserDefaults.standard.set(
            syncProjectURL.trimmingCharacters(in: .whitespacesAndNewlines),
            forKey: "sync.projectURL"
        )
        UserDefaults.standard.set(
            syncPublishableKey.trimmingCharacters(in: .whitespacesAndNewlines),
            forKey: "sync.publishableKey"
        )

        Task { [weak self] in
            guard let self else { return }
            do {
                let session: StoredSupabaseSession?
                if createAccount {
                    session = try await syncCoordinator.signUp(
                        configuration: configuration,
                        email: email,
                        password: password
                    )
                } else {
                    session = try await syncCoordinator.signIn(
                        configuration: configuration,
                        email: email,
                        password: password
                    )
                }
                isSyncing = false
                if let session {
                    syncAccountEmail = session.email
                    syncStatusMessage = "同步账户已登录。"
                    startAutomaticSync()
                    syncNow()
                } else {
                    syncStatusMessage = "注册成功，请验证邮件后再登录。"
                }
            } catch {
                isSyncing = false
                errorMessage = "同步账户操作失败：\(error.localizedDescription)"
                syncStatusMessage = nil
            }
        }
    }

    func syncNow() {
        performSync(announcesSuccess: true)
    }

    private func performSync(announcesSuccess: Bool) {
        guard isSyncConfigured,
              isSyncSignedIn,
              !isSyncing,
              !isRefreshingRemote else {
            if !isSyncSignedIn {
                errorMessage = "请先配置并登录同步账户。"
            }
            return
        }
        let configuration = SupabaseConfiguration(
            projectURL: syncProjectURL,
            publishableKey: syncPublishableKey
        )
        let startingSnapshot = makeArchiveSnapshot()
        isSyncing = true
        syncStatusMessage = "正在同步…"

        Task { [weak self] in
            guard let self else { return }
            do {
                let outcome = try await syncCoordinator.sync(
                    localArchive: startingSnapshot,
                    configuration: configuration
                )
                applySyncOutcome(
                    outcome,
                    startingSnapshot: startingSnapshot,
                    announcesSuccess: announcesSuccess
                )
            } catch {
                isSyncing = false
                errorMessage = "同步失败：\(error.localizedDescription)"
                syncStatusMessage = nil
            }
        }
    }

    func syncIfConfigured() {
        if isSyncConfigured, isSyncSignedIn {
            startAutomaticSync()
            performSync(announcesSuccess: false)
        }
    }

    func startAutomaticSync() {
        guard isSyncConfigured, isSyncSignedIn, remoteRefreshTask == nil else {
            return
        }
        remoteRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                self?.refreshFromRemote()
            }
        }
    }

    func stopAutomaticSync() {
        remoteRefreshTask?.cancel()
        remoteRefreshTask = nil
    }

    private func refreshFromRemote() {
        guard isSyncConfigured,
              isSyncSignedIn,
              !isSyncing,
              !isRefreshingRemote else {
            return
        }
        let configuration = SupabaseConfiguration(
            projectURL: syncProjectURL,
            publishableKey: syncPublishableKey
        )
        let startingSnapshot = makeArchiveSnapshot()
        isRefreshingRemote = true

        Task { [weak self] in
            guard let self else { return }
            defer { isRefreshingRemote = false }
            do {
                guard let outcome = try await syncCoordinator.refreshIfRemoteChanged(
                    localArchive: startingSnapshot,
                    configuration: configuration
                ) else {
                    return
                }
                applySyncOutcome(
                    outcome,
                    startingSnapshot: startingSnapshot,
                    announcesSuccess: false
                )
            } catch {
                // Background refresh is intentionally quiet. The next foreground
                // tick retries, while a manual sync still surfaces the full error.
            }
        }
    }

    private func applySyncOutcome(
        _ outcome: SlateSyncOutcome,
        startingSnapshot: TodoArchive,
        announcesSuccess: Bool
    ) {
        let current = makeArchiveSnapshot()
        let finalArchive: TodoArchive
        if current == startingSnapshot {
            finalArchive = outcome.archive
        } else {
            finalArchive = SlateMergeEngine.merge(
                base: startingSnapshot,
                local: current,
                remote: outcome.archive,
                preferLocalOnConflict: true
            ).archive
        }
        if finalArchive != current {
            replaceArchiveFromSync(finalArchive)
        }
        lastSyncedAt = outcome.syncedAt
        isSyncing = false
        if announcesSuccess {
            syncStatusMessage = outcome.conflictCount == 0
                ? "同步完成。"
                : "同步完成，已自动处理 \(outcome.conflictCount) 处冲突。"
        }
    }

    func signOutSync() {
        stopAutomaticSync()
        Task { [weak self] in
            guard let self else { return }
            do {
                try await syncCoordinator.signOut()
                syncAccountEmail = nil
                lastSyncedAt = nil
                syncStatusMessage = "已退出同步账户，本地待办不会删除。"
            } catch {
                errorMessage = "退出同步账户失败：\(error.localizedDescription)"
            }
        }
    }

    private func replaceArchiveFromSync(_ archive: TodoArchive) {
        groups = archive.groups.isEmpty ? [TodoGroup.defaultGroup()] : archive.groups
        let fallbackGroupID = groups[0].id
        let validGroupIDs = Set(groups.map(\.id))
        items = archive.items.map { item in
            var repaired = item
            if repaired.groupID == nil || !validGroupIDs.contains(repaired.groupID!) {
                repaired.groupID = fallbackGroupID
            }
            return repaired
        }
        if !validGroupIDs.contains(selectedGroupID) {
            selectedGroupID = fallbackGroupID
        }
        selectedItemIDs.removeAll()
        editingItemID = nil
        rebuildAllCaches()
        refreshVisible()
        persistImmediately()
    }

    // MARK: - 错误与持久化

    func clearError() {
        errorMessage = nil
    }

    func setError(_ message: String) {
        errorMessage = message
    }

    private func load() {
        do {
            let archive = try store.load()
            items = archive.items
            // 老数据兜底：groupID 为 nil 的任务统一分配到默认组
            let fallbackGroupID = archive.groups.first?.id ?? TodoGroup.defaultGroup().id
            var migrated = false
            for index in items.indices where items[index].groupID == nil {
                items[index].groupID = fallbackGroupID
                migrated = true
            }
            if archive.groups.isEmpty {
                let def = TodoGroup.defaultGroup()
                groups = [def]
                selectedGroupID = def.id
            } else {
                groups = archive.groups.sorted { $0.sortOrder < $1.sortOrder }
                if !groups.contains(where: { $0.id == selectedGroupID }) {
                    selectedGroupID = groups[0].id
                }
            }
            rebuildAllCaches()
            refreshVisible()
            reminderScheduler?.sync(items: items)
            if migrated {
                // 启动时同步立即落盘，确保老数据迁移生效，不要被后续 schedulePersist 覆盖延迟
                persistImmediately()
            }
        } catch {
            errorMessage = "读取待办数据失败：\(error.localizedDescription)"
        }
    }

    func schedulePersist(delay: Duration = .milliseconds(250)) {
        reminderScheduler?.sync(items: items)
        Task { await syncStateStore.markLocalChange() }
        scheduleAutoSync()
        persistTask?.cancel()
        persistGeneration &+= 1
        let generation = persistGeneration
        let snapshot = makeArchiveSnapshot()
        let store = self.store
        let saveQueue = self.saveQueue

        persistTask = Task.detached(priority: .utility) { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            do {
                // 后台线程 sync 到串行队列：与 persistImmediately 互斥，顺序 FIFO
                try saveQueue.sync { try store.save(snapshot) }
            } catch {
                let message = "保存待办数据失败：\(error.localizedDescription)"
                await self?.handleSaveError(message, generation: generation)
            }
        }
    }

    private func scheduleAutoSync() {
        guard isSyncConfigured, isSyncSignedIn else { return }
        autoSyncTask?.cancel()
        autoSyncTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            while self.isSyncing || self.isRefreshingRemote {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
            }
            self.performSync(announcesSuccess: false)
        }
    }

    @MainActor
    private func handleSaveError(_ message: String, generation: UInt64) {
        if persistGeneration == generation {
            errorMessage = message
        }
    }

    func persistImmediately() {
        reminderScheduler?.sync(items: items)
        persistTask?.cancel()
        persistTask = nil
        persistGeneration &+= 1
        do {
            // 主线程 sync 到串行队列：等队列里排队的旧 save 写完再写当前快照，
            // 保证退出前最后落盘的一定是最新数据
            try saveQueue.sync { try store.save(makeArchiveSnapshot()) }
        } catch {
            errorMessage = "保存待办数据失败：\(error.localizedDescription)"
        }
    }

    private func makeArchiveSnapshot() -> TodoArchive {
        TodoArchive(version: Self.archiveVersion, items: items, groups: groups)
    }

    // MARK: - 缓存

    private func rebuildAllCaches() {
        itemsByGroup.removeAll(keepingCapacity: true)
        countsByGroup.removeAll(keepingCapacity: true)
        for group in groups {
            rebuildCacheForGroup(group.id)
        }
    }

    private func rebuildCacheForGroup(_ groupID: UUID) {
        // 用稳定的第一个组 id 作为 fallback，避免每次调用都生成新 UUID
        let fallbackGroupID = groups.first?.id ?? groupID
        let groupItems = items
            .filter { ($0.groupID ?? fallbackGroupID) == groupID }
            .sorted { sortKey($0) < sortKey($1) }
        itemsByGroup[groupID] = groupItems
        let completed = groupItems.lazy.filter(\.isCompleted).count
        countsByGroup[groupID] = (groupItems.count, completed)
    }

    private func refreshVisible() {
        let base = itemsByGroup[selectedGroupID] ?? []
        let filtered: [TodoItem]
        switch filter {
        case .all:
            filtered = base
        case .pending:
            filtered = base.filter { !$0.isCompleted }
        case .completed:
            filtered = base.filter { $0.isCompleted }
        case .overdue:
            filtered = base.filter { isOverdue($0) }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        cachedVisibleItems = query.isEmpty
            ? filtered
            : filtered.filter { $0.title.localizedLowercase.contains(query) }
    }

    // MARK: - 到期日

    /// 今天 0 点（基于注入的 now，便于测试）
    private func startOfToday() -> Date {
        Calendar.current.startOfDay(for: now())
    }

    /// 是否逾期：有到期日、未完成、且早于今天 0 点
    func isOverdue(_ item: TodoItem) -> Bool {
        guard let due = item.dueDate, !item.isCompleted else { return false }
        return due < startOfToday()
    }

    /// 列表展示用的到期文案：今天 / 昨天 / 逾期 / M/D；已完成或无到期日返回 nil
    func dueLabel(_ item: TodoItem) -> String? {
        guard let due = item.dueDate else { return nil }
        let cal = Calendar.current
        if cal.isDateInToday(due) { return "今天" }
        if cal.isDateInYesterday(due) { return "昨天" }
        if due < startOfToday(), !item.isCompleted { return "逾期" }
        return "\(cal.component(.month, from: due))/\(cal.component(.day, from: due))"
    }

    private func nextSortOrder(for groupID: UUID) -> Double {
        let groupItems = itemsByGroup[groupID] ?? []
        let max = groupItems.compactMap(\.sortOrder).max() ?? -1
        return max + 1
    }

    private func sortKey(_ item: TodoItem) -> Double {
        item.sortOrder ?? item.createdAt.timeIntervalSinceReferenceDate
    }
}
