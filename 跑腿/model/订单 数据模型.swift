import Foundation

// MARK: - 品类

enum OrderKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case trash      // 代丢垃圾
    case parcel     // 代取快递
    case grocery    // 代买菜

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trash: "丢垃圾"
        case .parcel: "取快递"
        case .grocery: "代买菜"
        }
    }

    var symbol: String {
        switch self {
        case .trash: "trash"
        case .parcel: "shippingbox"
        case .grocery: "carrot"
        }
    }

    /// 该品类是否走预售（截单后集中采购）
    var isPreOrder: Bool { self == .grocery }
}

// MARK: - 状态

enum OrderStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case pending     // 待派单
    case assigned    // 已派单
    case picked      // 已取货
    case delivering  // 配送中
    case done        // 已完成
    case canceled    // 已取消

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending: "待派单"
        case .assigned: "已派单"
        case .picked: "已取货"
        case .delivering: "配送中"
        case .done: "已完成"
        case .canceled: "已取消"
        }
    }

    /// 正向流程主干（看板列顺序即取此前 4 项）
    static let flow: [OrderStatus] = [.pending, .assigned, .picked, .delivering, .done]

    /// 看板展示列
    static let boardColumns: [OrderStatus] = [.pending, .assigned, .delivering, .done]

    /// 从当前状态推进到目标状态需要依次经过的中间态。
    /// 允许跨列拖拽（如 待派单 → 配送中），内部自动补齐中间态，保证时间戳完整。
    func transitPath(to next: OrderStatus) -> [OrderStatus] {
        guard next != .canceled else { return [.canceled] }
        guard let from = Self.flow.firstIndex(of: self),
              let to = Self.flow.firstIndex(of: next),
              to > from else { return [] }
        return Array(Self.flow[(from + 1)...to])
    }
}

// MARK: - 订单

struct Order: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var kind: OrderKind
    var status: OrderStatus
    var windowID: DeliveryWindow.ID

    // 地址：楼栋是派单聚合的依据，必须是独立字段而不是塞在字符串里
    var building: String
    var unit: String
    var contact: String
    var phone: String

    // 品类专属
    var pickupCode: String?
    var station: String?
    var items: [OrderItem]?
    var itemBudget: Decimal?

    // 履约
    var riderID: Rider.ID?
    var note: String
    var createdAt: Date
    var history: [StatusStamp]

    // 计费
    var fee: Decimal
    var isMonthly: Bool

    /// 地理落点。同城模型下"楼栋"不再是聚合依据，经纬度才是。
    /// 老数据没有这个字段，取 resolvedLocation 时按 id 稳定散点补齐。
    var location: GeoPoint?

    init(
        id: UUID = UUID(),
        kind: OrderKind,
        status: OrderStatus = .pending,
        windowID: DeliveryWindow.ID,
        building: String,
        unit: String,
        contact: String,
        phone: String = "",
        pickupCode: String? = nil,
        station: String? = nil,
        items: [OrderItem]? = nil,
        itemBudget: Decimal? = nil,
        riderID: Rider.ID? = nil,
        note: String = "",
        createdAt: Date = .now,
        fee: Decimal = 5,
        isMonthly: Bool = false,
        location: GeoPoint? = nil
    ) {
        self.id = id
        self.kind = kind
        self.status = status
        self.windowID = windowID
        self.building = building
        self.unit = unit
        self.contact = contact
        self.phone = phone
        self.pickupCode = pickupCode
        self.station = station
        self.items = items
        self.itemBudget = itemBudget
        self.riderID = riderID
        self.note = note
        self.createdAt = createdAt
        self.history = [StatusStamp(status: status, at: createdAt)]
        self.fee = fee
        self.isMonthly = isMonthly
        self.location = location
    }

    var addressLine: String { "\(building) \(unit)" }

    /// 地图落点：老数据没有经纬度时按 id 稳定散点，保证地图上不空
    var resolvedLocation: GeoPoint {
        if let location { return location }
        let hash = abs(id.uuidString.hashValue)
        let dLat = (Double(hash % 1000) / 1000.0 - 0.5) * 0.018
        let dLng = (Double((hash / 1000) % 1000) / 1000.0 - 0.5) * 0.022
        return GeoPoint(latitude: GeoPoint.cityCenter.latitude + dLat,
                        longitude: GeoPoint.cityCenter.longitude + dLng)
    }

    var canCancel: Bool { status != .done && status != .canceled }

    func stamped(at date: Date) -> Date { history.first { $0.status == status }?.at ?? date }
}

struct OrderItem: Codable, Equatable, Identifiable, Sendable {
    var id: UUID = UUID()
    var name: String
    var quantity: String
    var price: Decimal?
}

struct StatusStamp: Codable, Equatable, Identifiable, Sendable {
    var id: UUID = UUID()
    var status: OrderStatus
    var at: Date
}
