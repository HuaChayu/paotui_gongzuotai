import Foundation

/// UI 测试用的假数据。真实数据由 service/本地存储.swift 从 JSON 载入。
enum DemoData {
    static func makeWindows(now: Date = .now) -> [DeliveryWindow] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        func at(_ h: Int, _ m: Int = 0) -> Date {
            cal.date(byAdding: .minute, value: h * 60 + m, to: today) ?? now
        }
        return [
            DeliveryWindow(kind: .trash,
                           date: today,
                           start: at(9), end: at(10), capacity: 12),
            DeliveryWindow(kind: .parcel,
                           date: today,
                           start: at(10), end: at(11, 30), capacity: 8),
            DeliveryWindow(kind: .grocery,
                           date: today,
                           start: at(14), end: at(16), capacity: 6,
                           cutoff: at(21)),   // 晚上 21:00 截单
        ]
    }

    static func makeRiders() -> [Rider] {
        [
            Rider(name: "我", phone: "", zones: ["虹桥", "西城"],
                  isActive: true,
                  location: GeoPoint.cityCenter.offset(metersNorth: 300, metersEast: -200),
                  isOnline: true),
            Rider(name: "老陈（兼职）", phone: "", zones: ["金城", "华城"],
                  isActive: true,
                  location: GeoPoint.cityCenter.offset(metersNorth: -1200, metersEast: 1600),
                  isOnline: true),
        ]
    }

    static func makeOrders(windows: [DeliveryWindow], now: Date = .now) -> [Order] {
        let names = ["张女士", "李先生", "王阿姨", "刘同学", "陈先生", "赵女士", "周先生", "吴小姐", "郑先生", "孙阿姨"]
        // 同城模型：地址是"小区 + 门牌"，聚合靠经纬度而不是楼栋
        let buildings = ["虹桥新邨", "虹桥新邨", "文化新村", "春风小区", "文化新村",
                         "世纪华城", "世纪华城", "春风小区", "虹桥新邨", "文化新村"]
        let spots: [String: GeoPoint] = [
            "虹桥新邨": GeoPoint.cityCenter,
            "文化新村": GeoPoint.cityCenter.offset(metersNorth: 1200, metersEast: 900),
            "春风小区": GeoPoint.cityCenter.offset(metersNorth: -950, metersEast: -1600),
            "世纪华城": GeoPoint.cityCenter.offset(metersNorth: 2100, metersEast: -700),
        ]
        let statuses: [OrderStatus] = [.pending, .pending, .pending, .assigned, .assigned,
                                       .delivering, .delivering, .done, .done, .pending]

        guard let trash = windows.first(where: { $0.kind == .trash }),
              let parcel = windows.first(where: { $0.kind == .parcel }),
              let grocery = windows.first(where: { $0.kind == .grocery }) else { return [] }

        return (0..<10).map { i in
            let kind = OrderKind.allCases[i % 3]
            let windowID: UUID = switch kind {
            case .trash: trash.id
            case .parcel: parcel.id
            case .grocery: grocery.id
            }
            let status = statuses[i]
            var order = Order(
                kind: kind,
                status: .pending,
                windowID: windowID,
                building: buildings[i],
                unit: "\(10 + i)0\(i % 9 + 1)",
                contact: names[i],
                phone: "138****00\(10 + i)",
                pickupCode: kind == .parcel ? "8-2-\(1000 + i)" : nil,
                station: kind == .parcel ? "菜鸟驿站 3 号柜" : nil,
                items: kind == .grocery ? [OrderItem(name: "青菜", quantity: "1 把"),
                                           OrderItem(name: "番茄", quantity: "2 个")] : nil,
                itemBudget: kind == .grocery ? 18 : nil,
                note: i == 2 ? "轻拿轻放" : "",
                createdAt: now.addingTimeInterval(Double(-i * 600)),
                fee: Decimal(4 + i % 4),
                isMonthly: i == 2,
                location: (spots[buildings[i]] ?? GeoPoint.cityCenter)
                    .offset(metersNorth: Double((i % 3 - 1) * 90),
                            metersEast: Double((i % 4 - 2) * 70))
            )
            // 用状态机推进到目标态，保证 history 时间戳真实
            for step in OrderStatus.pending.transitPath(to: status) {
                order.status = step
                order.history.append(StatusStamp(status: step, at: now.addingTimeInterval(Double(-i * 500))))
            }
            return order
        }
    }

    static func makeCustomers() -> [Customer] {
        [
            Customer(name: "王阿姨", phone: "138****0012", building: "5栋", unit: "1203",
                     monthlyUntil: Calendar.current.date(byAdding: .day, value: 20, to: .now)),
            Customer(name: "刘同学", phone: "138****0013", building: "1栋", unit: "502"),
            Customer(name: "张女士", phone: "138****0014", building: "3栋", unit: "1101",
                     monthlyUntil: Calendar.current.date(byAdding: .day, value: 8, to: .now)),
        ]
    }
}
