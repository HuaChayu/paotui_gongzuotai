import SwiftUI

/// App 主壳：macOS 27 浮动 Tab 栏 + prominent 新建入口
struct RootTabs: View {
    @Environment(WorkbenchStore.self) private var store
    @State private var tab: AppTab = .workbench

    var body: some View {
        @Bindable var store = store

        return TabView(selection: $tab) {
            Tab("工作台", systemImage: "square.grid.2x2", value: AppTab.workbench) {
                WorkbenchScreen()
            }
            Tab("客户", systemImage: "person.2", value: AppTab.customers) {
                CustomerScreen()
            }
            Tab("新建", systemImage: "plus", value: AppTab.create, role: .prominent) {
                NewOrderScreen()
            }
            Tab("调度", systemImage: "calendar.badge.clock", value: AppTab.dispatch) {
                DispatchScreen()
            }
        }
        .sheet(item: $store.activeSheet) { sheet in
            switch sheet {
            case .newOrder:
                NewOrderSheet()
            case let .assign(id):
                AssignSheet(orderID: id)
            case let .editCustomer(id):
                CustomerEditSheet(customerID: id)
            }
        }
    }
}

enum AppTab: Hashable {
    case workbench, customers, create, dispatch
}
