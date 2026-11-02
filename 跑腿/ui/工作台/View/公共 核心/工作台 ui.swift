import SwiftUI

/// 工作台主屏：三栏（窗口侧边栏 / 看板 / 订单详情）+ 底部窗口进度胶囊
struct WorkbenchScreen: View {
    @Environment(WorkbenchStore.self) private var store

    var body: some View {
        // 关键：整屏只有一个 NavigationSplitView。
        // 以前三个模式各自一套分栏，切 tab 时整棵树被替换，侧边栏/顶部切换条/搜索框
        // 都跟着做了一次"从左滑入"，看起来就是 tab 在跳、搜索图标跑位。
        //
        // 分段策略（严格三段，互不覆盖）：
        //   侧边栏 = NavigationSplitView 的 sidebar 列（唯一还能拖的列）
        //   中间内容 + 右侧属性面板 = detail 列内部的 HStack，
        //   右栏用固定 340 的 frame 占位，中间用 maxWidth: .infinity 吃掉剩余宽度。
        //   这样中间与右侧之间根本不存在的可拖拽 splitter，
        //   鼠标无法把属性面板拉宽、也就无法盖住中间内容。
        NavigationSplitView {
            WindowSidebar()
                .navigationSplitViewColumnWidth(min: 200, ideal: 232, max: 300)
        } detail: {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    // 顶部条留在外层，切模式时不重建、不参与过渡
                    modeHeader(hint: hintText)

                    contentBody
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        // 只有内容区从左侧滑入
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .opacity))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // 中栏硬边界：看板横向滚动 / 地图 / 分屏一律裁剪在本段内，
                // 任何子视图都不可能越界画到右栏身上。
                .clipped()

                Divider()

                OrderInspector(order: store.selectedOrder)
                    .frame(width: 340)
                    .frame(maxHeight: .infinity)
                    .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            if let window = currentWindow {
                WindowProgressBar(window: window)
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.bottom, 10)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.activeSheet = .newOrder
                } label: {
                    Label("新建订单", systemImage: "plus")
                }

                Button {
                    store.resetToDemo()
                } label: {
                    Label("重置演示数据", systemImage: "arrow.counterclockwise")
                }
            }
        }
    }

    /// 只切换内容本体，侧边栏 / 顶部条 / 搜索框 / 底部进度条全部复用
    @ViewBuilder
    private var contentBody: some View {
        switch store.boardMode {
        case .map: MapBoard()
        case .kanban: KanbanView()
        case .split: SplitBoard()
        }
    }

    /// 只有分屏需要提示；其余给空串，避免 Text 插入移除造成头部抖动
    private var hintText: String {
        store.boardMode == .split ? "拖动中间分隔条调整高度" : ""
    }

    /// 三种视图形态共用的顶部条：视图切换始终固定在左上，切 tab 不会跳位置
    private func modeHeader(hint: String) -> some View {
        HStack(spacing: 8) {
            Text("视图")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            BoardModeSwitch()

            Spacer()

            Text(hint)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.leading, Theme.screenPadding)
        .padding(.trailing, Theme.screenPadding)
        // 根是浮动 Tab 栏，内容 top 会被压住，这里让位
        .padding(.top, 44)
        .padding(.bottom, 2)
        // 撑满整行并左对齐，否则 HStack 按内容宽居中，切换控件看着像"跑到了中间"
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 底部条展示：当前有单的第一个窗口
    private var currentWindow: DeliveryWindow? {
        windowsWithOrders.first ?? store.windows.first
    }

    private var windowsWithOrders: [DeliveryWindow] {
        store.windows.filter { store.load(of: $0).used > 0 }
    }
}

// MARK: - 底部窗口进度条

struct WindowProgressBar: View {
    let window: DeliveryWindow
    @Environment(WorkbenchStore.self) private var store

    var body: some View {
        let load = store.load(of: window)
        let ratio = load.capacity == 0 ? 0 : Double(load.used) / Double(load.capacity)

        HStack(spacing: 12) {
            Image(systemName: window.kind.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(window.kind == .grocery ? .orange : .secondary)

            Text("\(window.timeRange) · \(window.kind.title)")
                .font(.system(size: 12, weight: .medium, design: .rounded))

            Text("\(load.used)/\(load.capacity)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [window.kind == .grocery ? .orange : .blue, .green],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(2, geo.size.width * ratio))
                }
            }
            .frame(height: 5)

            Text(ratio, format: .percent.precision(.fractionLength(0)))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .animation(.smooth(duration: 0.3), value: ratio)
    }
}

#Preview {
    WorkbenchScreen()
        .environment(WorkbenchStore())
        .frame(width: 1440, height: 900)
}

// MARK: - 视图形态切换

/// 卡片 / 地图 两段切换。放在内容区而不是 toolbar：
/// 根是 TabView，tab bar 会吃掉 toolbar 的位置。
struct BoardModeSwitch: View {
    @Environment(WorkbenchStore.self) private var store

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(BoardMode.allCases.enumerated()), id: \.element.id) { index, mode in
                let active = store.boardMode == mode
                Button {
                    withAnimation(.smooth(duration: 0.28)) { store.boardMode = mode }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.symbol)
                            .font(.system(size: 10, weight: .semibold))
                        Text(mode.title)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(active ? .primary : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background {
                        if active {
                            Capsule()
                                .fill(.background.opacity(0.85))
                                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
        }
        .padding(2)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}
