import Foundation
import Observation

/// 工作台唯一 Store。业务真值 + 纯 UI 状态都在这里，
/// View 只读它、只调它的 action，不写业务判断。
@Observable
final class WorkbenchStore {

    // MARK: 业务真值

    var orders: [Order] = []
    var windows: [DeliveryWindow] = []
    var riders: [Rider] = []
    var customers: [Customer] = []

    // MARK: 纯 UI 状态

    var selectedOrderID: Order.ID?
    var filterKind: OrderKind?
    var searchText: String = ""
    var activeSheet: WorkbenchSheet?

    /// 工作台主视图形态：卡片看板 / 地图调度。记住上次选择，重开 App 不跳回默认。
    var boardMode: BoardMode = BoardMode.stored {
        didSet { UserDefaults.standard.set(boardMode.rawValue, forKey: BoardMode.storageKey) }
    }

    // MARK: 初始化

    init(seedWithDemoData: Bool = true) {
        if let snapshot = LocalStore.load() {
            orders = snapshot.orders
            windows = snapshot.windows
            riders = snapshot.riders
            customers = snapshot.customers
        } else if seedWithDemoData {
            windows = DemoData.makeWindows()
            riders = DemoData.makeRiders()
            orders = DemoData.makeOrders(windows: windows)
            customers = DemoData.makeCustomers()
            persist()
        }
    }

    // MARK: 查询（派生一律 computed，不缓存）

    var selectedOrder: Order? {
        guard let selectedOrderID else { return nil }
        return orders.first { $0.id == selectedOrderID }
    }

    func orders(in status: OrderStatus) -> [Order] {
        orders
            .filter { $0.status == status }
            .filter { filterKind == nil || $0.kind == filterKind }
            .filter { searchText.isEmpty || matches($0, searchText) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func matches(_ order: Order, _ text: String) -> Bool {
        let q = text.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        return order.addressLine.localizedContains(q)
            || order.contact.localizedContains(q)
            || (order.pickupCode?.localizedContains(q) ?? false)
    }

    func load(of window: DeliveryWindow) -> (used: Int, capacity: Int) {
        let used = orders.filter { $0.windowID == window.id && $0.status != .canceled }.count
        return (used, window.capacity)
    }

    func window(for order: Order) -> DeliveryWindow? {
        windows.first { $0.id == order.windowID }
    }

    var todayStats: (done: Int, total: Int, revenue: Decimal) {
        let active = orders.filter { $0.status != .canceled }
        let done = active.filter { $0.status == .done }
        return (done.count, active.count, done.reduce(0) { $0 + $1.fee })
    }

    var monthlyRevenue: Decimal {
        let formatter = Calendar.current
        let now = Date.now
        return orders
            .filter { $0.status == .done && formatter.isDate($0.createdAt, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.fee }
    }

    // MARK: 动作（Domain 层唯一写入口）

    func add(_ order: Order) {
        orders.insert(order, at: 0)
        selectedOrderID = order.id
        persist()
    }

    func createOrder(kind: OrderKind, building: String, unit: String,
                     contact: String, phone: String,
                     fee: Decimal, note: String = "", isMonthly: Bool = false) {
        // 自动挑该品类最近的可用窗口
        let window = windows
            .filter { $0.kind == kind && $0.isOpen() }
            .sorted { $0.start < $1.start }
            .first ?? windows.first { $0.kind == kind }
        guard let window else { return }

        let order = Order(
            kind: kind,
            windowID: window.id,
            building: building,
            unit: unit,
            contact: contact,
            phone: phone,
            note: note,
            fee: fee,
            isMonthly: isMonthly
        )
        add(order)
    }

    /// 推进状态。允许跨列，内部补中间态。
    /// 非法目标（如已完成回到待派单）直接忽略，不写脏数据。
    @discardableResult
    func advance(_ id: Order.ID, to next: OrderStatus) -> Bool {
        guard let index = orders.firstIndex(where: { $0.id == id }) else { return false }
        let current = orders[index].status
        guard current != next else { return true }

        if next == .canceled {
            guard orders[index].canCancel else { return false }
            orders[index].status = .canceled
            orders[index].history.append(StatusStamp(status: .canceled, at: .now))
            persist()
            return true
        }

        let path = current.transitPath(to: next)
        guard !path.isEmpty else { return false }

        let now = Date.now
        for step in path {
            orders[index].status = step
            orders[index].history.append(StatusStamp(status: step, at: now))
        }
        persist()
        return true
    }

    func assign(_ id: Order.ID, to rider: Rider?) {
        guard let index = orders.firstIndex(where: { $0.id == id }) else { return }
        orders[index].riderID = rider?.id
        persist()
    }

    func delete(_ id: Order.ID) {
        orders.removeAll { $0.id == id }
        if selectedOrderID == id { selectedOrderID = nil }
        persist()
    }

    func addCustomer(_ customer: Customer) {
        customers.insert(customer, at: 0)
        persist()
    }

    func updateCustomer(_ customer: Customer) {
        guard let index = customers.firstIndex(where: { $0.id == customer.id }) else { return }
        customers[index] = customer
        persist()
    }

    // MARK: 持久化

    func persist() {
        LocalStore.save(.init(orders: orders, windows: windows, riders: riders, customers: customers))
    }

    func resetToDemo() {
        LocalStore.reset()
        windows = DemoData.makeWindows()
        riders = DemoData.makeRiders()
        orders = DemoData.makeOrders(windows: windows)
        customers = DemoData.makeCustomers()
        selectedOrderID = nil
        persist()
    }
}

// MARK: - 主视图形态

enum BoardMode: String, CaseIterable, Identifiable {
    // 顺序即按钮排列：地图 / 卡片 / 分屏
    case map
    case kanban
    case split

    static let storageKey = "workbench.boardMode"

    /// 上次用过的形态，没有就默认「上卡片下地图」
    static var stored: BoardMode {
        guard let raw = UserDefaults.standard.string(forKey: storageKey),
              let mode = BoardMode(rawValue: raw) else { return .split }
        return mode
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .split: "分屏"
        case .kanban: "卡片"
        case .map: "地图"
        }
    }

    var symbol: String {
        switch self {
        case .split: "rectangle.split.1x2"
        case .kanban: "rectangle.split.3x1"
        case .map: "map"
        }
    }
}

// MARK: - 浮层枚举（互斥由枚举天然保证，不生造 8 个布尔）

enum WorkbenchSheet: Identifiable {
    case newOrder
    case assign(Order.ID)
    case editCustomer(Customer.ID)

    var id: String {
        switch self {
        case .newOrder: "newOrder"
        case let .assign(id): "assign-\(id)"
        case let .editCustomer(id): "customer-\(id)"
        }
    }
}

// MARK: - 小工具

extension String {
    func localizedContains(_ other: String) -> Bool {
        range(of: other, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
