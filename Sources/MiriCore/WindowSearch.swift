import Foundation

public struct WindowSearch: Sendable {
    public struct Window: Decodable, Identifiable, Sendable {
        public let windowId: Int32
        public let bundleId: String
        public let appName: String
        public let title: String
        let focused: Bool
        let floating: Bool
        let column: UInt32?

        public var id: Int32 { windowId }
    }

    private struct Snapshot: Decodable {
        struct Workspace: Decodable {
            let windows: [Window]
        }
        let virtualWorkspaces: [Workspace]
    }

    private let windows: [Window]

    public init(json: Data, excludingBundle bundleId: String?) throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let snapshot = try decoder.decode(Snapshot.self, from: json)
        var seen: Set<Int32> = []
        windows = snapshot.virtualWorkspaces.flatMap(\.windows)
            .filter { ($0.column != nil || $0.floating) && $0.bundleId != bundleId && seen.insert($0.id).inserted }
            .sorted {
                if $0.focused != $1.focused { return $0.focused }
                let appOrder = $0.appName.localizedStandardCompare($1.appName)
                if appOrder != .orderedSame { return appOrder == .orderedAscending }
                let titleOrder = $0.title.localizedStandardCompare($1.title)
                if titleOrder != .orderedSame { return titleOrder == .orderedAscending }
                return $0.id < $1.id
            }
    }

    public func matching(_ query: String) -> [Window] {
        ShortcutSearch.rank(windows, query: query) { [$0.title, $0.appName, "\($0.appName) \($0.title)"] }
    }
}
