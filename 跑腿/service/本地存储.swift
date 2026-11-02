import Foundation

/// 数据落盘：JSON 全量读写 + 原子替换。
/// 单小区日单量几十，没有必要上 SwiftData，JSON 反而方便手动改数据排障。
enum LocalStore {
    static var root: URL {
        let base = URL.applicationSupportDirectory.appending(path: "跑腿工资台", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static var stateFile: URL { root.appending(path: "state.json") }

    struct Snapshot: Codable {
        var orders: [Order]
        var windows: [DeliveryWindow]
        var riders: [Rider]
        var customers: [Customer]
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func load() -> Snapshot? {
        guard let data = try? Data(contentsOf: stateFile) else { return nil }
        return try? decoder.decode(Snapshot.self, from: data)
    }

    /// 原子写：先写临时文件再替换，避免中途崩溃把存档写坏
    static func save(_ snapshot: Snapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        let tmp = stateFile.appendingPathExtension("tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            _ = try FileManager.default.replaceItemAt(stateFile, withItemAt: tmp)
        } catch {
            try? data.write(to: stateFile, options: .atomic)
        }
    }

    static func reset() {
        try? FileManager.default.removeItem(at: stateFile)
    }
}
