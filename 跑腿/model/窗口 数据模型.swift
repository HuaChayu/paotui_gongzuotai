import Foundation

// MARK: - 配送窗口

/// 窗口是一等公民：下单不是"随时下单"，而是"占用某个窗口的名额"。
struct DeliveryWindow: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var kind: OrderKind
    var date: Date
    var start: Date
    var end: Date
    var capacity: Int
    /// 买菜预售的截单时间（其它品类为 nil）
    var cutoff: Date?

    init(
        id: UUID = UUID(),
        kind: OrderKind,
        date: Date = .now,
        start: Date,
        end: Date,
        capacity: Int,
        cutoff: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.date = date
        self.start = start
        self.end = end
        self.capacity = capacity
        self.cutoff = cutoff
    }

    var timeRange: String {
        let f = Date.FormatStyle.dateTime.hour().minute()
        return "\(start.formatted(f))–\(end.formatted(f))"
    }

    func isOpen(at now: Date = .now) -> Bool {
        if let cutoff { return now < cutoff }
        return now < end
    }
}

// MARK: - 跑腿员

struct Rider: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var phone: String
    /// 负责的片区（同城模型下是街道/商圈，不是楼栋）
    var zones: [String]
    var isActive: Bool

    /// 实时位置（同城地图上用）
    var location: GeoPoint?
    /// 是否在线接单
    var isOnline: Bool

    init(id: UUID = UUID(), name: String, phone: String = "",
         zones: [String] = [], isActive: Bool = true,
         location: GeoPoint? = nil, isOnline: Bool = true) {
        self.id = id
        self.name = name
        self.phone = phone
        self.zones = zones
        self.isActive = isActive
        self.location = location
        self.isOnline = isOnline
    }

    var resolvedLocation: GeoPoint {
        location ?? GeoPoint.cityCenter.offset(metersNorth: 600, metersEast: -400)
    }
}

// MARK: - 客户

struct Customer: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var phone: String
    var building: String
    var unit: String
    /// 包月有效期截止日（nil 表示非包月客户）
    var monthlyUntil: Date?
    var note: String

    init(
        id: UUID = UUID(),
        name: String,
        phone: String = "",
        building: String,
        unit: String,
        monthlyUntil: Date? = nil,
        note: String = ""
    ) {
        self.id = id
        self.name = name
        self.phone = phone
        self.building = building
        self.unit = unit
        self.monthlyUntil = monthlyUntil
        self.note = note
    }

    var isMonthly: Bool {
        guard let monthlyUntil else { return false }
        return monthlyUntil > .now
    }

    var addressLine: String { "\(building) \(unit)" }
}
