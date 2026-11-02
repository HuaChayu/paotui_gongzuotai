import SwiftUI

/// 客户页：左列表 + 右档案
struct CustomerScreen: View {
    @Environment(WorkbenchStore.self) private var store
    @State private var selectedID: Customer.ID?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedID) {
                Section("客户 \(store.customers.count)") {
                    ForEach(store.customers) { customer in
                        CustomerRow(customer: customer)
                            .tag(customer.id)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
            .toolbar {
                Button {
                    store.activeSheet = .editCustomer(UUID())
                } label: {
                    Label("新增客户", systemImage: "person.badge.plus")
                }
            }
        } detail: {
            if let customer = store.customers.first(where: { $0.id == selectedID }) {
                CustomerProfile(customer: customer)
            } else {
                ContentUnavailableView("未选择客户", systemImage: "person.crop.circle",
                                       description: Text("左侧选择一位客户"))
            }
        }
    }
}

private struct CustomerRow: View {
    let customer: Customer

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(customer.isMonthly ? .orange : .secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(customer.name).font(.system(size: 12, weight: .medium))
                Text(customer.addressLine)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if customer.isMonthly {
                Text("包月")
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.orange.opacity(0.18), in: Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}

struct CustomerProfile: View {
    let customer: Customer
    @Environment(WorkbenchStore.self) private var store

    private var orders: [Order] {
        store.orders.filter { $0.contact == customer.name && $0.addressLine == customer.addressLine }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(customer.isMonthly ? .orange : .secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(customer.name)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Text("\(customer.addressLine)\(customer.phone.isEmpty ? "" : " · \(customer.phone)")")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("编辑") {
                        store.activeSheet = .editCustomer(customer.id)
                    }
                }

                if let until = customer.monthlyUntil {
                    HStack {
                        Label("包月至", systemImage: "calendar")
                            .font(.system(size: 12))
                        Spacer()
                        Text(until, format: .dateTime.year().month().day())
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .padding(12)
                    .glassEffect(.regular.tint(.orange.opacity(0.18)), in: .rect(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("历史订单 \(orders.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(orders) { order in
                        HStack(spacing: 8) {
                            Image(systemName: order.kind.symbol)
                                .font(.system(size: 11))
                                .frame(width: 16)
                            Text(order.kind.title).font(.system(size: 12))
                            Spacer()
                            Text(order.status.title)
                                .font(.system(size: 10))
                                .foregroundStyle(order.status.tint)
                            Text(Theme.money(order.fee))
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 3)
                    }
                    if orders.isEmpty {
                        Text("还没有订单").font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 10))
            }
            .padding(Theme.screenPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(customer.name)
    }
}

// MARK: - 编辑

struct CustomerEditSheet: View {
    let customerID: UUID
    @Environment(WorkbenchStore.self) private var store

    @State private var name = ""
    @State private var phone = ""
    @State private var building = ""
    @State private var unit = ""
    @State private var note = ""
    @State private var isMonthly = false
    @State private var loaded = false

    private var existing: Customer? {
        store.customers.first { $0.id == customerID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(existing == nil ? "新增客户" : "编辑客户")
                .font(.system(size: 15, weight: .semibold))

            field("姓名", $name)
            field("电话", $phone)
            field("楼栋", $building)
            field("门牌", $unit)
            Toggle("包月客户（30 天）", isOn: $isMonthly)
                .toggleStyle(.switch)
                .controlSize(.small)

            HStack {
                Button("取消") { store.activeSheet = nil }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(existing == nil ? "添加" : "保存") { submit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || building.isEmpty || unit.isEmpty)
            }
        }
        .padding(18)
        .frame(width: 340)
        .onAppear(perform: preload)
    }

    private func field(_ title: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
            TextField(title, text: text).textFieldStyle(.roundedBorder)
        }
    }

    private func preload() {
        guard !loaded else { return }
        loaded = true
        if let c = existing {
            name = c.name
            phone = c.phone
            building = c.building
            unit = c.unit
            note = c.note
            isMonthly = c.isMonthly
        }
    }

    private func submit() {
        let monthlyUntil: Date? = isMonthly
            ? Calendar.current.date(byAdding: .day, value: 30, to: .now)
            : nil

        if let existing {
            var updated = existing
            updated.name = name
            updated.phone = phone
            updated.building = building
            updated.unit = unit
            updated.note = note
            updated.monthlyUntil = monthlyUntil
            store.updateCustomer(updated)
        } else {
            store.addCustomer(Customer(name: name, phone: phone,
                                       building: building, unit: unit,
                                       monthlyUntil: monthlyUntil, note: note))
        }
        store.activeSheet = nil
    }
}
