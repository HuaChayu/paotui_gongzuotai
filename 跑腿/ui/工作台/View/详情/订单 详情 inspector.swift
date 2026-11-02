import SwiftUI

struct OrderInspector: View {
    let order: Order?
    @Environment(WorkbenchStore.self) private var store

    var body: some View {
        if let order {
            // 列宽统一由 WorkbenchScreen 的 detail 列声明，这里不再重复设置，
            // 避免内外两处约束打架导致中右分界漂移。
            OrderInspectorContent(order: order)
        } else {
            ContentUnavailableView(
                "未选择订单",
                systemImage: "rectangle.on.rectangle.slash",
                description: Text("点击看板里的卡片查看详情")
            )
        }
    }
}

struct OrderInspectorContent: View {
    let order: Order
    @Environment(WorkbenchStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                identity
                if let code = order.pickupCode { pickupBlock(code) }
                if let items = order.items, !items.isEmpty { groceryBlock(items) }
                if !order.note.isEmpty { noteBlock }
                flowBlock
                timelineBlock
            }
            .padding(Theme.screenPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(order.contact)
    }

    // MARK: 区块

    private var identity: some View {
        HStack(spacing: 12) {
            Image(systemName: order.kind.symbol)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 42, height: 42)
                .glassEffect(.regular.tint(order.status.tint.opacity(0.35)), in: .circle)

            VStack(alignment: .leading, spacing: 3) {
                Text(order.addressLine)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Text("\(order.contact)\(order.phone.isEmpty ? "" : " · \(order.phone)")")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(Theme.money(order.fee))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(order.isMonthly ? .secondary : .primary)
        }
    }

    private func pickupBlock(_ code: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            blockTitle("取件信息")
            Label(code, systemImage: "number")
                .font(.system(size: 13, design: .monospaced))
            if let station = order.station {
                Label(station, systemImage: "mappin.and.ellipse")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 10))
    }

    private func groceryBlock(_ items: [OrderItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            blockTitle("采购清单")
            ForEach(items) { item in
                HStack {
                    Text(item.name).font(.system(size: 13))
                    Spacer()
                    Text(item.quantity)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            if let budget = order.itemBudget {
                Divider()
                HStack {
                    Text("预估菜钱").font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Text(Theme.money(budget))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 10))
    }

    private var noteBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            blockTitle("备注")
            Text(order.note).font(.system(size: 13))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(.yellow.opacity(0.14)), in: .rect(cornerRadius: 10))
    }

    /// 流程：点击任意状态直接推进（跨列自动补中间态）
    private var flowBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            blockTitle("流程")

            ForEach(OrderStatus.flow) { status in
                let reached = reachedIndex >= (OrderStatus.flow.firstIndex(of: status) ?? 0)
                let isCurrent = order.status == status

                HStack(spacing: 9) {
                    Image(systemName: isCurrent ? "largecircle.fill.circle" : (reached ? "checkmark.circle.fill" : "circle"))
                        .foregroundStyle(isCurrent ? status.tint : (reached ? Color.secondary : Color.secondary.opacity(0.4)))
                    Text(status.title)
                        .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                    Spacer()
                    if isCurrent {
                        Text("当前").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { store.advance(order.id, to: status) }
            }

            if order.canCancel {
                Button(role: .destructive) {
                    store.advance(order.id, to: .canceled)
                } label: {
                    Label("取消这单", systemImage: "xmark.circle")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 10))
    }

    private var timelineBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            blockTitle("时间线")
            ForEach(order.history.reversed()) { stamp in
                HStack(spacing: 8) {
                    Circle().fill(stamp.status.tint).frame(width: 5, height: 5)
                    Text(stamp.status.title).font(.system(size: 11))
                    Spacer()
                    Text(stamp.at, format: .dateTime.hour().minute().second())
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 10))
    }

    private func blockTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private var reachedIndex: Int {
        OrderStatus.flow.firstIndex(of: order.status) ?? 0
    }
}

#Preview {
    let store = WorkbenchStore()
    return OrderInspector(order: store.orders.first)
        .environment(store)
        .frame(width: 340, height: 760)
}
