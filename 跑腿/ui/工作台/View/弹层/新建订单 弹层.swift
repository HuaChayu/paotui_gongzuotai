import SwiftUI

/// prominent Tab 的落地页：直接就是新建表单
struct NewOrderScreen: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Image(systemName: "shippingbox.and.arrow.backward")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(.tint)
                    Text("新建订单")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("手录单 / 电话单都从这里进")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                NewOrderForm()
                    .frame(maxWidth: 460)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.screenPadding + 8)
        }
    }
}

/// Sheet 版（⌘N / 工具栏加号触发）
struct NewOrderSheet: View {
    @Environment(WorkbenchStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            NewOrderForm()
                .padding(20)
        }
        .frame(width: 460)
    }
}

// MARK: - 表单

struct NewOrderForm: View {
    @Environment(WorkbenchStore.self) private var store

    @State private var kind: OrderKind = .trash
    @State private var building: String = "3栋"
    @State private var unit: String = ""
    @State private var contact: String = ""
    @State private var phone: String = ""
    @State private var fee: String = "5"
    @State private var note: String = ""
    @State private var isMonthly: Bool = false

    private var canSubmit: Bool {
        !building.trimmingCharacters(in: .whitespaces).isEmpty
            && !unit.trimmingCharacters(in: .whitespaces).isEmpty
            && !contact.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 品类选择
            HStack(spacing: 8) {
                ForEach(OrderKind.allCases) { k in
                    Button {
                        kind = k
                        fee = k == .grocery ? "8" : "5"
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: k.symbol)
                                .font(.system(size: 15, weight: .semibold))
                            Text(k.title).font(.system(size: 11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(
                        kind == k
                        ? .regular.tint(Color.accentColor.opacity(0.32)).interactive()
                        : .regular.interactive(),
                        in: .rect(cornerRadius: 10)
                    )
                }
            }

            field("楼栋", text: $building, prompt: "3栋")
            field("门牌", text: $unit, prompt: "1203")
            field("联系人", text: $contact, prompt: "张女士")
            field("电话", text: $phone, prompt: "选填")

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("跑腿费").font(.system(size: 11)).foregroundStyle(.secondary)
                    TextField("5", text: $fee)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                }
                Toggle("包月客户", isOn: $isMonthly)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("备注").font(.system(size: 11)).foregroundStyle(.secondary)
                TextField("轻拿轻放 / 放门口", text: $note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }

            if let window = suggestedWindow {
                Label {
                    Text("将进入 \(window.kind.title) · \(window.timeRange)（\(store.load(of: window).used)/\(window.capacity)）")
                        .font(.system(size: 11))
                } icon: {
                    Image(systemName: "calendar.badge.clock")
                }
                .foregroundStyle(.secondary)
            }

            Button {
                submit()
            } label: {
                Text("创建订单")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmit)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private func field(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var suggestedWindow: DeliveryWindow? {
        store.windows
            .filter { $0.kind == kind && $0.isOpen() }
            .sorted { $0.start < $1.start }
            .first ?? store.windows.first { $0.kind == kind }
    }

    private func submit() {
        store.createOrder(
            kind: kind,
            building: building.trimmingCharacters(in: .whitespaces),
            unit: unit.trimmingCharacters(in: .whitespaces),
            contact: contact.trimmingCharacters(in: .whitespaces),
            phone: phone,
            fee: Decimal(string: fee) ?? 5,
            note: note,
            isMonthly: isMonthly
        )
        store.activeSheet = nil
        unit = ""
        contact = ""
        phone = ""
        note = ""
    }
}

// MARK: - 改派

struct AssignSheet: View {
    let orderID: Order.ID
    @Environment(WorkbenchStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("改派").font(.system(size: 15, weight: .semibold))

            ForEach(store.riders) { rider in
                Button {
                    store.assign(orderID, to: rider)
                    store.activeSheet = nil
                } label: {
                    HStack {
                        Image(systemName: "figure.walk")
                        VStack(alignment: .leading, spacing: 1) {
                            Text(rider.name).font(.system(size: 13))
                            Text(rider.zones.joined(separator: " · "))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if isAssigned(rider) {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                    .padding(10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
            }

            Button("取消") { store.activeSheet = nil }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
        }
        .padding(18)
        .frame(width: 320)
    }

    private func isAssigned(_ rider: Rider) -> Bool {
        store.orders.first { $0.id == orderID }?.riderID == rider.id
    }
}
