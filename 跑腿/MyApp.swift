import SwiftUI

@main
struct MyApp: App {
    @State private var store = WorkbenchStore()

    var body: some Scene {
        WindowGroup {
            RootTabs()
                .environment(store)
                .frame(minWidth: 1080, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 1440, height: 900)
        .commands {
            CommandGroup(after: .newItem) {
                Button("新建订单") {
                    store.activeSheet = .newOrder
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("重置演示数据") {
                    store.resetToDemo()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }
}
