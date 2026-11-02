import SwiftUI

// MARK: - 状态语义色

extension OrderStatus {
    var tint: Color {
        switch self {
        case .pending: .orange
        case .assigned: .blue
        case .picked: .indigo
        case .delivering: .green
        case .done: .gray
        case .canceled: .red
        }
    }

    var symbol: String {
        switch self {
        case .pending: "tray.full"
        case .assigned: "person.badge.clock"
        case .picked: "hand.raised"
        case .delivering: "figure.walk.motion"
        case .done: "checkmark.seal"
        case .canceled: "xmark.circle"
        }
    }
}

// MARK: - 设计令牌

enum Theme {
    /// 卡片圆角
    static let cardRadius: CGFloat = 14
    /// 列容器圆角
    static let columnRadius: CGFloat = 18
    /// 内边距
    static let cardPadding: CGFloat = 14
    static let screenPadding: CGFloat = 16
    /// 列间距
    static let columnSpacing: CGFloat = 12
    /// 玻璃染色浓度（超过 0.4 会脏，低于 0.15 看不出状态）
    static let tintAlpha: Double = 0.30

    static func money(_ value: Decimal) -> String {
        value.formatted(.currency(code: "CNY").precision(.fractionLength(0)))
    }
}
