import Testing
import Foundation
#if canImport(TodoList)
@testable import TodoList
#endif

/// ViewModel 测试：每个用例独立临时目录 store，互不影响
@MainActor
final class TodoViewModelTests {

    private var tempDirs: [URL] = []

    init() {}

    deinit {
        for dir in tempDirs {
            try? FileManager.default.removeItem(at: dir)
        }
    }

    // MARK: - 工具

    private func makeVM(now: @escaping () -> Date = Date.init) -> TodoViewModel {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("slate-vm-tests-\(UUID().uuidString)", isDirectory: true)
        tempDirs.append(dir)
        return TodoViewModel(store: TodoFileStore(baseDirectory: dir), now: now)
    }

    @discardableResult
    private func addTodos(_ vm: TodoViewModel, _ titles: [String]) -> [TodoItem] {
        for title in titles {
            vm.newTitle = title
            vm.addTodo()
        }
        return vm.items
    }

    // MARK: - CRUD

    @Test func addTodoTrimsAndAppends() {
        let vm = makeVM()
        vm.newTitle = "  买菜  "
        vm.addTodo()
        #expect(vm.items.count == 1)
        #expect(vm.items.first?.title == "买菜")
        #expect(vm.newTitle == "")
        #expect(vm.visibleItems.count == 1)
    }

    @Test func addTodoRejectsBlank() {
        let vm = makeVM()
        vm.newTitle = "   "
        vm.addTodo()
        #expect(vm.items.isEmpty)
        #expect(!vm.canAdd)
    }

    @Test func quickAddUsesExplicitDraftWithoutOverwritingMainWindowDraft() {
        let vm = makeVM()
        let dueDate = Date(timeIntervalSince1970: 1_800_000_000)
        vm.newTitle = "主窗口里尚未提交的内容"

        let added = vm.addTodo(title: "  菜单栏任务  ", dueDate: dueDate)

        #expect(added)
        #expect(vm.items.count == 1)
        #expect(vm.items[0].title == "菜单栏任务")
        #expect(vm.items[0].dueDate == dueDate)
        #expect(vm.newTitle == "主窗口里尚未提交的内容")
    }

    @Test func toggleCompletionSetsAndClearsTimestamp() {
        let fixed = Date(timeIntervalSince1970: 1_700_000_000)
        var useFixed = false
        let vm = makeVM(now: { useFixed ? fixed : Date() })
        let item = addTodos(vm, ["任务"])[0]

        useFixed = true
        vm.toggleCompletion(of: item)
        #expect(vm.items[0].isCompleted)
        #expect(vm.items[0].completedAt == fixed)

        vm.toggleCompletion(of: vm.items[0])
        #expect(!vm.items[0].isCompleted)
        #expect(vm.items[0].completedAt == nil)
    }

    @Test func settingCompletionIsIdempotent() {
        let fixed = Date(timeIntervalSince1970: 1_700_000_000)
        let vm = makeVM(now: { fixed })
        let item = addTodos(vm, ["任务"])[0]

        vm.setCompletion(true, for: item.id)
        vm.setCompletion(true, for: item.id)

        #expect(vm.items[0].isCompleted)
        #expect(vm.items[0].completedAt == fixed)

        vm.undo()
        #expect(!vm.items[0].isCompleted)
        vm.undo()
        #expect(vm.items.isEmpty, "重复设为完成不应产生额外撤销步骤")
    }

    // MARK: - moveItem 插入点

    @Test func moveItemDownward() {
        let vm = makeVM()
        let items = addTodos(vm, ["A", "B", "C"])
        // A 拖到 C → [B, C, A]
        vm.moveItem(withID: items[0].id, before: items[2].id)
        #expect(vm.visibleItems.map(\.title) == ["B", "C", "A"])
    }

    @Test func moveItemUpward() {
        let vm = makeVM()
        let items = addTodos(vm, ["A", "B", "C"])
        // C 拖到 A → [C, A, B]
        vm.moveItem(withID: items[2].id, before: items[0].id)
        #expect(vm.visibleItems.map(\.title) == ["C", "A", "B"])
    }

    @Test func moveItemAdjacentAlwaysShiftsOneSlot() {
        let vm = makeVM()
        let items = addTodos(vm, ["A", "B", "C"])
        // A 拖到紧邻下方 B：必须产生 1 格位移，不能"什么都没发生"
        vm.moveItem(withID: items[0].id, before: items[1].id)
        #expect(vm.visibleItems.map(\.title) == ["B", "A", "C"])
    }

    @Test func moveItemRejectsCrossGroup() {
        let vm = makeVM()
        vm.addGroup(name: "工作")
        let workGroup = vm.groups.first { $0.name == "工作" }!
        let items = addTodos(vm, ["A", "B"])

        // 手动把 B 挪到工作组，再尝试跨组拖动 → 不应生效
        vm.moveItem(withID: items[1].id, toGroupID: workGroup.id)
        vm.moveItem(withID: items[1].id, before: items[0].id)
        #expect(vm.visibleItems.map(\.title) == ["A"])
        #expect(vm.items.first { $0.id == items[1].id }?.groupID == workGroup.id)
    }

    /// 嵌套排序：A,B,C,D → C 拖到 A 前 → C,A,B,D
    @Test func moveItemNestedReordering() {
        let vm = makeVM()
        let items = addTodos(vm, ["A", "B", "C", "D"])
        vm.moveItem(withID: items[2].id, before: items[0].id)
        #expect(vm.visibleItems.map(\.title) == ["C", "A", "B", "D"])
    }

    /// A,B,C,D → B 拖到 D 前 → A,C,D,B（source 在 target 上方时拖到下方）
    @Test func moveItemWithGapBetweenSourceAndTarget() {
        let vm = makeVM()
        let items = addTodos(vm, ["A", "B", "C", "D"])
        vm.moveItem(withID: items[1].id, before: items[3].id)
        #expect(vm.visibleItems.map(\.title) == ["A", "C", "D", "B"])
    }

    // MARK: - 选择模式

    @Test func selectionSingleSetsAnchor() {
        let vm = makeVM()
        let items = addTodos(vm, ["1", "2", "3"])
        vm.select(items[0], mode: .single)
        #expect(vm.selectedItemIDs == [items[0].id])

        // 有锚点后 Shift 范围选择生效
        vm.select(items[2], mode: .range)
        #expect(vm.selectedItemIDs == Set(items.map(\.id)))
    }

    @Test func repeatedSingleSelectionAlwaysReplacesPreviousSelection() {
        let vm = makeVM()
        let items = addTodos(vm, ["1", "2", "3"])
        vm.select(items[0], mode: .toggle)
        vm.select(items[1], mode: .toggle)
        #expect(vm.selectedItemIDs.count == 2)

        vm.select(items[2], mode: .single)
        #expect(vm.selectedItemIDs == [items[2].id])

        vm.select(items[0], mode: .single)
        #expect(vm.selectedItemIDs == [items[0].id])
    }

    @Test func selectionRangeAnchorStays() {
        let vm = makeVM()
        let items = addTodos(vm, ["1", "2", "3", "4", "5"])
        vm.select(items[0], mode: .single)
        vm.select(items[3], mode: .range)
        #expect(vm.selectedItemIDs.count == 4)

        // 锚点不动，再次 Shift 收缩范围
        vm.select(items[1], mode: .range)
        #expect(vm.selectedItemIDs == [items[0].id, items[1].id])
    }

    @Test func selectionRangeWithoutAnchorFallsBackToSingle() {
        let vm = makeVM()
        let items = addTodos(vm, ["1", "2", "3"])
        vm.select(items[2], mode: .range)
        #expect(vm.selectedItemIDs == [items[2].id])
    }

    @Test func selectionToggle() {
        let vm = makeVM()
        let items = addTodos(vm, ["1", "2", "3"])
        vm.select(items[0], mode: .toggle)
        vm.select(items[2], mode: .toggle)
        #expect(vm.selectedItemIDs == [items[0].id, items[2].id])
        vm.select(items[0], mode: .toggle)
        #expect(vm.selectedItemIDs == [items[2].id])
    }

    // MARK: - 分组

    @Test func deleteGroupMigratesItems() {
        let vm = makeVM()
        let defaultID = vm.selectedGroupID
        vm.addGroup(name: "工作")
        let workGroup = vm.groups.first { $0.name == "工作" }!
        vm.selectGroup(workGroup.id)
        addTodos(vm, ["合同", "报账"])
        #expect(vm.totalCount(for: workGroup.id) == 2)

        vm.deleteGroup(workGroup.id)
        #expect(vm.groups.count == 1)
        #expect(vm.selectedGroupID == defaultID)
        #expect(vm.totalCount(for: defaultID) == 2)
        #expect(vm.items.allSatisfy { $0.groupID == defaultID })
    }

    /// 逐个验证每个 item 的 groupID 都正确迁移
    @Test func deleteGroupVerifiesItemGroupIDMigration() {
        let vm = makeVM()
        let defaultID = vm.selectedGroupID
        vm.addGroup(name: "工作")
        let workGroup = vm.groups.first { $0.name == "工作" }!
        vm.selectGroup(workGroup.id)
        let items = addTodos(vm, ["合同", "报账", "电池"])

        vm.deleteGroup(workGroup.id)
        for itemID in items.map(\.id) {
            #expect(vm.items.first { $0.id == itemID }?.groupID == defaultID)
        }
    }

    /// 快速连续添加 10 个任务，sortOrder 应全部不同且严格递增
    @Test func concurrentAddTodosHaveUniqueSortOrders() {
        let vm = makeVM()
        for i in 1...10 {
            vm.newTitle = "任务\(i)"
            vm.addTodo()
        }
        let orders = vm.items.compactMap(\.sortOrder)
        #expect(orders.count == 10)
        #expect(Set(orders).count == 10, "所有 sortOrder 必须不同")
        #expect(orders.sorted() == orders, "sortOrder 必须递增")
    }

    @Test func deleteLastGroupRejected() {
        let vm = makeVM()
        #expect(vm.groups.count == 1)
        vm.deleteGroup(vm.groups[0].id)
        #expect(vm.groups.count == 1)
    }

    // MARK: - 缓存一致性

    /// 一系列操作后，所有派生统计必须与全量重算一致
    @Test func cacheConsistencyAfterMixedOperations() {
        let vm = makeVM()
        let items = addTodos(vm, ["A", "B", "C", "D"])
        vm.toggleCompletion(of: items[0])
        vm.toggleCompletion(of: items[1])
        vm.delete(items[2])

        let expectedTotal = vm.items.count
        let expectedCompleted = vm.items.filter(\.isCompleted).count
        let expectedPending = expectedTotal - expectedCompleted

        #expect(vm.totalItemCount == expectedTotal)
        #expect(vm.totalCompletedCount == expectedCompleted)
        #expect(vm.totalPendingCount == expectedPending)

        let groupID = vm.selectedGroupID
        #expect(vm.totalCount(for: groupID) == expectedTotal)
        #expect(vm.pendingCount(for: groupID) == expectedPending)
    }

    /// 多分组场景下 itemsByGroup 缓存与全量重算一致
    @Test func multiGroupCacheConsistency() {
        let vm = makeVM()
        let defaultID = vm.selectedGroupID
        vm.addGroup(name: "工作")
        let workID = vm.groups.first { $0.name == "工作" }!.id
        vm.addGroup(name: "个人")
        let personalID = vm.groups.first { $0.name == "个人" }!.id

        vm.selectGroup(defaultID)
        addTodos(vm, ["默认1", "默认2"])
        vm.selectGroup(workID)
        addTodos(vm, ["工作1", "工作2", "工作3"])
        vm.selectGroup(personalID)
        let personalItems = addTodos(vm, ["个人1"])
        vm.toggleCompletion(of: personalItems[0])

        // 全量重算验证
        for groupID in [defaultID, workID, personalID] {
            let fromCache = vm.totalCount(for: groupID)
            let fromItems = vm.items.filter { ($0.groupID ?? groupID) == groupID }.count
            #expect(fromCache == fromItems, "组 \(groupID) 缓存不一致: \(fromCache) vs \(fromItems)")
        }

        #expect(vm.totalItemCount == 6)
        #expect(vm.totalCompletedCount == 1)
    }

    // MARK: - 筛选

    @Test func visibleItemsRespectFilter() {
        let vm = makeVM()
        let items = addTodos(vm, ["A", "B", "C"])
        vm.toggleCompletion(of: items[0])

        vm.setFilter(.pending)
        #expect(vm.visibleItems.map(\.title) == ["B", "C"])

        vm.setFilter(.completed)
        #expect(vm.visibleItems.map(\.title) == ["A"])

        vm.setFilter(.all)
        #expect(vm.visibleItems.count == 3)
    }

    // MARK: - 编辑

    @Test func commitEditingTrimsAndUpdates() {
        let vm = makeVM()
        let item = addTodos(vm, ["旧名"])[0]
        vm.beginEditing(item)
        vm.editingTitle = "  新名  "
        vm.commitEditing()
        #expect(vm.items[0].title == "新名")
        #expect(vm.editingItemID == nil)
    }

    @Test func commitEditingBlankKeepsOriginal() {
        let vm = makeVM()
        let item = addTodos(vm, ["旧名"])[0]
        vm.beginEditing(item)
        vm.editingTitle = "   "
        vm.commitEditing()
        #expect(vm.items[0].title == "旧名")
    }

    // MARK: - 持久化往返

    /// persistImmediately 后，新 VM 从同一 store 能读回全部状态
    @Test func persistRoundTrip() {
        let vm = makeVM()
        vm.addGroup(name: "工作")
        let workGroup = vm.groups.first { $0.name == "工作" }!
        vm.selectGroup(workGroup.id)
        addTodos(vm, ["合同"])
        vm.persistImmediately()

        let store = TodoFileStore(baseDirectory: tempDirs.last!)
        let vm2 = TodoViewModel(store: store)
        #expect(vm2.groups.count == 2)
        #expect(vm2.items.count == 1)
        #expect(vm2.items.first?.title == "合同")
        #expect(vm2.items.first?.groupID == workGroup.id)
    }

    // MARK: - 撤销

    @Test func undoAfterAddRestoresEmptyState() {
        let vm = makeVM()
        vm.newTitle = "测试"
        vm.addTodo()
        #expect(vm.items.count == 1)
        #expect(vm.canUndo)

        vm.undo()
        #expect(vm.items.isEmpty)
        #expect(!vm.canUndo)
    }

    @Test func undoAfterDeleteRestoresItem() {
        let vm = makeVM()
        let item = addTodos(vm, ["测试"])[0]
        vm.delete(item)
        #expect(vm.items.isEmpty)

        vm.undo()
        #expect(vm.items.count == 1)
        #expect(vm.items[0].title == "测试")
    }

    @Test func undoRespectsStackLimit() {
        let vm = makeVM()
        // 执行 35 次操作（超过 maxUndoSteps=30）
        for i in 1...35 {
            vm.newTitle = "第\(i)项"
            vm.addTodo()
        }
        // 只能撤销最近 30 步
        var count = 0
        while vm.canUndo {
            vm.undo()
            count += 1
        }
        #expect(count == 30)
        #expect(vm.items.count == 5) // 35 - 30 = 5 条最早的任务无法撤销
    }

    @Test func undoRestoresGroupState() {
        let vm = makeVM()
        vm.addGroup(name: "工作")
        vm.undo()
        #expect(vm.groups.count == 1)
        #expect(vm.groups[0].name == "待办")
    }

    // MARK: - 搜索

    @Test func searchFiltersVisibleItems() {
        let vm = makeVM()
        addTodos(vm, ["买菜", "买水果", "还书"])
        vm.setSearch("买")
        #expect(vm.visibleItems.map(\.title) == ["买菜", "买水果"])
        vm.setSearch("书")
        #expect(vm.visibleItems.map(\.title) == ["还书"])
        vm.clearSearch()
        #expect(vm.visibleItems.count == 3)
    }

    @Test func searchRespectsCurrentFilter() {
        let vm = makeVM()
        let items = addTodos(vm, ["买菜", "买水果", "还书"])
        vm.toggleCompletion(of: items[0]) // 买菜 完成
        vm.setFilter(.pending)
        vm.setSearch("买")
        #expect(vm.visibleItems.map(\.title) == ["买水果"])
    }

    // MARK: - 到期日

    @Test func addTodoCapturesDueDate() {
        let vm = makeVM()
        let due = Date(timeIntervalSinceNow: 86400)
        vm.newTitle = "合同"
        vm.newDueDate = due
        vm.addTodo()
        #expect(vm.items.count == 1)
        #expect(vm.items.first?.dueDate == due)
        #expect(vm.newDueDate == nil) // 添加后清零
    }

    @Test func existingTodoDueDateCanBeUpdatedClearedAndUndone() {
        let vm = makeVM()
        let item = addTodos(vm, ["合同"])[0]
        let due = Date(timeIntervalSince1970: 1_800_000_000)

        vm.setDueDate(due, for: item.id)
        #expect(vm.items.first?.dueDate == due)

        vm.setDueDate(nil, for: item.id)
        #expect(vm.items.first?.dueDate == nil)

        vm.undo()
        #expect(vm.items.first?.dueDate == due)
    }

    @Test func completedTodoStillDisplaysItsDueDate() {
        let fixed = Date(timeIntervalSince1970: 1_700_000_000)
        let vm = makeVM(now: { fixed })
        let item = addTodos(vm, ["已完成任务"])[0]
        let due = Date(timeInterval: 2 * 86400, since: fixed)
        vm.setDueDate(due, for: item.id)
        vm.toggleCompletion(of: vm.items[0])

        #expect(vm.items[0].isCompleted)
        #expect(vm.dueLabel(vm.items[0]) != nil)
    }

    @Test func isOverdueDetected() {
        let fixed = Date(timeIntervalSince1970: 1_700_000_000)
        let vm = makeVM(now: { fixed })
        vm.newTitle = "过期任务"
        vm.newDueDate = Date(timeInterval: -10 * 86400, since: fixed) // 远早于今天
        vm.addTodo()
        #expect(vm.isOverdue(vm.items[0]))
        #expect(vm.dueLabel(vm.items[0]) == "逾期")
        #expect(vm.totalOverdueCount == 1)
    }

    @Test func overdueFilterShowsOnlyOverdue() {
        let fixed = Date(timeIntervalSince1970: 1_700_000_000)
        let vm = makeVM(now: { fixed })
        vm.newTitle = "过期"
        vm.newDueDate = Date(timeInterval: -10 * 86400, since: fixed)
        vm.addTodo()
        vm.newTitle = "未到期"
        vm.newDueDate = Date(timeInterval: 86400, since: fixed)
        vm.addTodo()
        vm.newTitle = "无到期"
        vm.newDueDate = nil
        vm.addTodo()

        vm.setFilter(.overdue)
        #expect(vm.visibleItems.map(\.title) == ["过期"])
        vm.setFilter(.all)
        #expect(vm.visibleItems.count == 3)
    }

    // MARK: - 大数据量

    @Test func thousandItemFilteringAndSearchStayResponsive() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("slate-vm-perf-\(UUID().uuidString)", isDirectory: true)
        tempDirs.append(dir)
        let store = TodoFileStore(baseDirectory: dir)
        let group = TodoGroup.defaultGroup()
        let items = (0..<1_000).map { index in
            TodoItem(
                title: "任务 \(index)",
                isCompleted: index.isMultiple(of: 3),
                createdAt: Date(timeIntervalSince1970: Double(index)),
                groupID: group.id,
                sortOrder: Double(index)
            )
        }
        try store.save(TodoArchive(items: items, groups: [group]))

        let clock = ContinuousClock()
        let start = clock.now
        let vm = TodoViewModel(store: store)
        for index in 0..<100 {
            vm.setSearch(index.isMultiple(of: 2) ? "任务 9" : "任务")
            vm.setFilter(index.isMultiple(of: 3) ? .completed : .pending)
        }
        vm.setSearch("")
        vm.setFilter(.all)
        let elapsed = start.duration(to: clock.now)

        #expect(vm.visibleItems.count == 1_000)
        #expect(elapsed < .seconds(2), "千条任务的加载与 100 轮筛选应在 2 秒内完成")
    }
}
