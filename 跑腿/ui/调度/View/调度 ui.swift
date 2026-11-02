import SwiftUI

/// 调度页：今日收入 + 窗口负载 + 楼栋聚合（一次上楼送完）
struct DispatchScreen: View {
    @Environment(WorkbenchStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                statsStrip
                loadSection
                buildingSection
            }
            .padding(Theme.screenPadding + 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("调度")
    }

    // MARK: 收入

    private var statsStrip: some View {
        let today = store.todayStats
        return HStack(spacing: 12) {
            StatTile(title: "今日完成", value: "\(today.done)/\(today.total)", symbol: "checkmark.seal", tint: .green)
            StatTile(title: "今日收入", value: Theme.money(today.revenue), symbol: "yensign.circle", tint: .blue)
            StatTile(title: "本月收入", value: Theme.money(store.monthlyRevenue), symbol: "calendar", tint: .purple)
            StatTile(title: "包月客户", value: "\(store.customers.filter(\.isMonthly).count)", symbol: "star.circle", tint: .orange)
        }
    }

    // MARK: 窗口负载

    private var loadSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("窗口负载")

            ForEach(store.windows) { window in
                let load = store.load(of: window)
                let ratio = load.capacity == 0 ? 0 : Double(load.used) / Double(load.capacity)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Image(systemName: window.kind.symbol).font(.system(size: 12))
                        Text(window.kind.title).font(.system(size: 13, weight: .semibold))
                        Text(window.timeRange)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if ratio >= 1 {
                            Text("已满")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.red)
                        } else if let cutoff = window.cutoff {
                            Text("截单 \(cutoff, format: .dateTime.hour().minute())")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Text("\(load.used)/\(load.capacity)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.quaternary)
                            Capsule()
                                .fill(ratio >= 1 ? Color.red.gradient : Color.accentColor.gradient)
                                .frame(width: max(3, geo.size.width * min(1, ratio)))
                        }
                    }
                    .frame(height: 6)
                }
                .padding(12)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
            }
        }
    }

    // MARK: 楼栋聚合

    private var buildingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("楼栋聚合 · 待送")
            ForEach(buildingGroups, id: \.key) { group in
                HStack(spacing: 10) {
                    Text(group.key)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .frame(width: 48, alignment: .leading)

                    FlowTags(orders: group.value)

                    Spacer()

                    Text("\(group.value.count) 单")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 10))
            }

            if buildingGroups.isEmpty {
                Text("暂无待配送订单").font(.system(size: 12)).foregroundStyle(.tertiary)
            }
        }
    }

    /// 按楼栋聚合"待派单 + 已接单 + 配送中"
    private var buildingGroups: [(key: String, value: [Order])] {
        let active = store.orders.filter { [.pending, .assigned, .picked, .delivering].contains($0.status) }
        let grouped = Dictionary(grouping: active, by: \.building)
        return grouped
            .map { (key: $0.key, value: $0.value.sorted { $0.unit < $1.unit }) }
            .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(tint.opacity(0.16)), in: .rect(cornerRadius: 12))
    }
}

private struct FlowTags: View {
    let orders: [Order]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(orders.prefix(6)) { order in
                Text(order.unit)
                    .font(.system(size: 10, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(order.status.tint.opacity(0.18), in: Capsule())
            }
            if orders.count > 6 {
                Text("+\(orders.count - 6)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
