import SwiftUI

/// 左侧：今日窗口 + 品类筛选。窗口失焦时整体淡化（macOS 27 的 appearsActive）
struct WindowSidebar: View {
    @Environment(WorkbenchStore.self) private var store

    var body: some View {
        List {
            Section("今日窗口") {
                ForEach(store.windows) { window in
                    WindowRow(window: window)
                }
            }

            Section("品类") {
                FilterRow(title: "全部", symbol: "line.3.horizontal.decrease", isOn: store.filterKind == nil) {
                    store.filterKind = nil
                }
                ForEach(OrderKind.allCases) { kind in
                    FilterRow(title: kind.title, symbol: kind.symbol, isOn: store.filterKind == kind) {
                        store.filterKind = store.filterKind == kind ? nil : kind
                    }
                }
            }

            Section("跑腿员") {
                ForEach(store.riders) { rider in
                    HStack(spacing: 8) {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(rider.name).font(.system(size: 12, weight: .medium))
                            Text(rider.zones.joined(separator: " · "))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Circle()
                            .fill(rider.isActive ? .green : .gray)
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: Binding(
            get: { store.searchText },
            set: { store.searchText = $0 }
        ), prompt: "搜楼栋 / 联系人 / 取件码")
    }
}

private struct WindowRow: View {
    let window: DeliveryWindow
    @Environment(WorkbenchStore.self) private var store

    var body: some View {
        let load = store.load(of: window)
        let full = load.used >= load.capacity

        HStack(spacing: 9) {
            Image(systemName: window.kind.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(window.kind == .grocery ? .orange : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(window.kind.title)
                    .font(.system(size: 12, weight: .semibold))
                Text(window.timeRange)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(load.used)/\(load.capacity)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(full ? .orange : .secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}

private struct FilterRow: View {
    let title: String
    let symbol: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol).frame(width: 18)
                Text(title).font(.system(size: 12))
                Spacer()
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
