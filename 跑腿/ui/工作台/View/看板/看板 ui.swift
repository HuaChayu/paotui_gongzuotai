import SwiftUI

/// 看板：四列横向排布，卡片拖拽跨列即改状态
/// 列宽随窗口自适应：窗口变宽时四列均分，变窄时保底 210 并允许横向滚动
struct KanbanView: View {
    var body: some View {
        GeometryReader { geo in
            let spacing = Theme.columnSpacing
            let padding = Theme.screenPadding
            let available = geo.size.width - padding * 2 - spacing * 3
            let columnWidth = max(210, available / 4)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(OrderStatus.boardColumns) { status in
                        KanbanColumn(status: status)
                            .frame(width: columnWidth,
                                   height: max(220, geo.size.height - padding * 2))
                    }
                }
                .padding(padding)
            }
            .scrollIndicators(.hidden)
        }
    }
}

struct KanbanColumn: View {
    let status: OrderStatus
    @Environment(WorkbenchStore.self) private var store
    @State private var isTargeted = false
    @Namespace private var glassNS

    var body: some View {
        let items = store.orders(in: status)

        VStack(alignment: .leading, spacing: 10) {
            header(count: items.count)

            ScrollView(.vertical) {
                VStack(spacing: 8) {
                    ForEach(items) { order in
                        OrderCard(order: order, showsStatus: false, glassNamespace: glassNS)
                            .onTapGesture { store.selectedOrderID = order.id }
                            .draggable(order.id.uuidString) {
                                OrderCard(order: order, showsStatus: false, glassNamespace: glassNS)
                                    .frame(width: 250)
                            }
                    }

                    if items.isEmpty {
                        emptyHint
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .glassEffect(
            isTargeted ? .regular.tint(status.tint.opacity(0.22)) : .regular,
            in: .rect(cornerRadius: Theme.columnRadius)
        )
        .dropDestination(for: String.self) { payload, _ in
            guard let raw = payload.first, let id = UUID(uuidString: raw) else { return false }
            return store.advance(id, to: status)
        } isTargeted: { isTargeted = $0 }
        .animation(.smooth(duration: 0.25), value: isTargeted)
    }

    private func header(count: Int) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.tint)
                .frame(width: 7, height: 7)
            Text(status.title)
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(.quaternary, in: Capsule())
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private var emptyHint: some View {
        Text("拖到这里")
            .font(.system(size: 11))
            .foregroundStyle(.secondary.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
    }
}

#Preview {
    KanbanView()
        .environment(WorkbenchStore())
        .frame(width: 1100, height: 700)
}
