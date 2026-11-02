import SwiftUI

/// 订单卡片：玻璃材质 + 按状态染色，同一窗口的卡片会被 glassEffectUnion 融成一块
struct OrderCard: View {
    let order: Order
    var showsStatus: Bool = true
    var glassNamespace: Namespace.ID?

    @Environment(WorkbenchStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            header

            Text(order.addressLine)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .lineLimit(1)

            footer
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(CardGlass(order: order, namespace: glassNamespace))
        .animation(.smooth(duration: 0.3), value: order.status)
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: order.kind.symbol)
                .font(.system(size: 12, weight: .semibold))
            Text(order.kind.title)
                .font(.system(size: 12, weight: .semibold))

            if showsStatus {
                Text(order.status.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(order.status.tint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(order.status.tint.opacity(0.16), in: Capsule())
            }

            Spacer()

            Text(Theme.money(order.fee))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(order.isMonthly ? .secondary : .primary)
                .strikethrough(order.isMonthly, color: .secondary)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text(order.contact)
                .lineLimit(1)

            if let code = order.pickupCode {
                Text(code)
                    .font(.system(size: 10, design: .monospaced))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            }

            Spacer()

            if order.isMonthly {
                Text("包月")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }

            if let window = store.window(for: order) {
                Text(window.timeRange)
                    .font(.system(size: 10, design: .rounded))
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
}

/// 玻璃修饰器：有 namespace 才参与 union / id 动画
private struct CardGlass: ViewModifier {
    let order: Order
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let ns = namespace {
            content
                .glassEffect(
                    .regular.tint(order.status.tint.opacity(Theme.tintAlpha)).interactive(),
                    in: .rect(cornerRadius: Theme.cardRadius)
                )
                .glassEffectID(order.id, in: ns)
        } else {
            content
                .glassEffect(
                    .regular.tint(order.status.tint.opacity(Theme.tintAlpha)).interactive(),
                    in: .rect(cornerRadius: Theme.cardRadius)
                )
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        OrderCard(order: DemoData.makeOrders(windows: DemoData.makeWindows())[0])
        OrderCard(order: DemoData.makeOrders(windows: DemoData.makeWindows())[1])
    }
    .padding()
    .environment(WorkbenchStore())
    .frame(width: 300)
}
