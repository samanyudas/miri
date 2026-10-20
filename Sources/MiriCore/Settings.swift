/// Miri's user settings, read from and written to the `[miri]` section and the engine keys Miri owns.
public struct MiriSettings: Equatable, Sendable {
    /// Provisional range in points. The engine clamps per-window padding to 50, so larger inner gaps would be lost.
    public static let gapRange = 0...32
    public static let presetRange = 0.05...1.0
    public static let presetCountRange = 1...10
    /// The engine's exponential ease-out rate when animation is on. Unset in the engine means instant movement.
    public static let animationSpeed = 14.0
    public static let gapRuleName = "miri-gaps"
    public static let floatingRuleName = "miri-settings"

    public var innerGap = 8
    public var outerGap = 8
    public var widthPresets = [0.25, 0.33, 0.5, 0.66, 0.75]
    public var stackLimit = StackLimit.count(5)
    public var animations = true
    public var launchAtLogin = true
    public var stripGesture = StripGesture.off
    /// Reverses the strip swipe. Off means the strip follows the fingers.
    public var reverseSwipe = false

    public init() {}

    /// Reads settings from a document. Missing keys keep their defaults.
    public init(document: TOMLDocument) throws(ConfigurationIssue) {
        if let value = document.value(at: ["miri", "inner_gap"]) { innerGap = try Self.gap(value, key: "inner_gap") }
        if let value = document.value(at: ["miri", "outer_gap"]) { outerGap = try Self.gap(value, key: "outer_gap") }
        if let value = document.value(at: ["miri", "animations"]) {
            animations = try Self.boolean(value, key: "miri.animations")
        }
        if let value = document.value(at: ["miri", "launch_at_login"]) {
            launchAtLogin = try Self.boolean(value, key: "miri.launch_at_login")
        }
        if let value = document.value(at: ["miri", "strip_gesture"]) {
            guard case .string(let name) = value, let gesture = StripGesture(rawValue: name) else {
                throw .invalidValue(
                    key: "miri.strip_gesture", message: "miri.strip_gesture must be \"off\", \"three\", or \"four\".")
            }
            stripGesture = gesture
        }
        if let value = document.value(at: ["miri", "reverse_swipe"]) {
            reverseSwipe = try Self.boolean(value, key: "miri.reverse_swipe")
        }
        if let value = document.value(at: ["options", "preset_column_widths"]) {
            guard case .array(let items) = value else { throw Self.presetIssue }
            widthPresets = try items.map { item throws(ConfigurationIssue) in
                switch item {
                case .float(let ratio): ratio
                case .integer(let ratio): Double(ratio)
                default: throw Self.presetIssue
                }
            }
        }
        if let value = document.value(at: ["options", "stack_limit"]) {
            switch value {
            case .integer(let count) where count >= 1: stackLimit = .count(Int(clamping: count))
            case .string("fit"): stackLimit = .fit
            default: throw Self.stackLimitIssue
            }
        }
        try validate()
    }

    public func validate() throws(ConfigurationIssue) {
        for (key, gap) in [("inner_gap", innerGap), ("outer_gap", outerGap)] where !Self.gapRange.contains(gap) {
            throw Self.gapIssue(key)
        }
        guard Self.presetCountRange.contains(widthPresets.count),
            widthPresets.allSatisfy(Self.presetRange.contains),
            zip(widthPresets, widthPresets.dropFirst()).allSatisfy({ $0 < $1 })
        else { throw Self.presetIssue }
        if case .count(let count) = stackLimit, count < 1 { throw Self.stackLimitIssue }
    }

    /// Per-window padding. Adjacent windows each contribute it, so two of them make the inner gap.
    public var windowPadding: Int { innerGap / 2 }

    /// Display-edge padding. The edge window's own padding adds to it, so together they make the outer gap.
    public var edgePadding: Int { max(0, outerGap - windowPadding) }

    /// Writes these settings and the engine keys derived from them, changing only values that differ.
    /// `appBundleIdentifier` names Miri's own app, whose windows always float. `gestureFingers` is the strip swipe
    /// the engine intercepts, which is on only while it is tested or being tested. `nil` leaves macOS gestures alone.
    public func applied(
        to document: TOMLDocument, reduceMotion: Bool, appBundleIdentifier: String, layout: KeyLayout = .positional,
        gestureFingers: GestureFingers? = nil
    ) throws
        -> TOMLDocument
    {
        try applying(
            to: document, reduceMotion: reduceMotion, appBundleIdentifier: appBundleIdentifier, layout: layout,
            gestureFingers: gestureFingers
        ).document
    }

    /// Like `applied`, but leaves each key the file defines in a form Miri does not rewrite, such as an inline table,
    /// and returns each of those keys in `skipped` with the value Miri wanted there, or `nil` to remove it.
    func applying(
        to document: TOMLDocument, reduceMotion: Bool, appBundleIdentifier: String, layout: KeyLayout = .positional,
        gestureFingers: GestureFingers? = nil
    ) throws
        -> (document: TOMLDocument, skipped: [String: TOMLValue?])
    {
        try validate()
        var result = document
        var skipped: [String: TOMLValue?] = [:]
        func edit(_ wanted: TOMLValue?, _ change: () throws -> TOMLDocument) throws {
            do { result = try change() } catch TOMLEditError.notEditable(let path) { skipped[path] = wanted }
        }
        func set(_ value: TOMLValue, _ table: [String], _ key: String) throws {
            if result.value(at: table + [key]) != value {
                try edit(value) { try result.setting(value, table: table, key: key) }
            }
        }
        try set(.integer(Int64(innerGap)), ["miri"], "inner_gap")
        try set(.integer(Int64(outerGap)), ["miri"], "outer_gap")
        try set(.boolean(animations), ["miri"], "animations")
        try set(.boolean(launchAtLogin), ["miri"], "launch_at_login")
        try set(.string(stripGesture.rawValue), ["miri"], "strip_gesture")
        try set(.boolean(reverseSwipe), ["miri"], "reverse_swipe")
        try set(.array(widthPresets.map(TOMLValue.float)), ["options"], "preset_column_widths")
        try set(stackLimit.tomlValue, ["options"], "stack_limit")
        if animations && !reduceMotion {
            if result.value(at: ["options", "animation_speed"]) == nil {
                try set(.float(Self.animationSpeed), ["options"], "animation_speed")
            }
        } else {
            try edit(nil) { try result.removing(table: ["options"], key: "animation_speed") }
        }
        for side in ["top", "right", "bottom", "left"] {
            try set(.integer(Int64(edgePadding)), ["padding"], side)
        }
        let rule = ["windows", Self.gapRuleName]
        try set(.string(".*"), rule, "title")
        try set(.integer(Int64(windowPadding)), rule, "horizontal_padding")
        try set(.integer(Int64(windowPadding)), rule, "vertical_padding")
        // Miri's own menu bar item replaces the engine's.
        try set(.boolean(false), ["decorations", "menu"], "visible")
        let floating = ["windows", Self.floatingRuleName]
        try set(.string(".*"), floating, "title")
        try set(.string(appBundleIdentifier), floating, "bundle_id")
        try set(.boolean(true), floating, "floating")
        let gesture = ["swipe", "gesture"]
        if let gestureFingers {
            try set(.integer(Int64(gestureFingers.rawValue)), gesture, "fingers_count")
        } else {
            try edit(nil) { try result.removing(table: gesture, key: "fingers_count") }
        }
        try set(.string(reverseSwipe ? "Reversed" : "Natural"), gesture, "direction")
        // V1 strip swipes are horizontal. The engine otherwise takes vertical swipes with the same finger count,
        // which macOS uses for Mission Control and App Exposé.
        try set(.boolean(false), gesture, "vertical")
        // The engine falls back to these deprecated keys, which would keep a swipe on that Miri turned off.
        for legacy in ["swipe_gesture_fingers", "swipe_gesture_direction"] {
            try edit(nil) { try result.removing(table: ["options"], key: legacy) }
        }
        return (try DefaultBinding.adding(to: result, layout: layout), skipped)
    }

    private static func gap(_ value: TOMLValue, key: String) throws(ConfigurationIssue) -> Int {
        guard case .integer(let gap) = value, gapRange.contains(Int(clamping: gap)) else { throw gapIssue(key) }
        return Int(gap)
    }

    private static func boolean(_ value: TOMLValue, key: String) throws(ConfigurationIssue) -> Bool {
        guard case .boolean(let flag) = value else {
            throw .invalidValue(key: key, message: "\(key) must be true or false.")
        }
        return flag
    }

    private static func gapIssue(_ key: String) -> ConfigurationIssue {
        .invalidValue(
            key: "miri.\(key)",
            message:
                "miri.\(key) must be a whole number of points from \(gapRange.lowerBound) to \(gapRange.upperBound).")
    }

    private static let presetIssue = ConfigurationIssue.invalidValue(
        key: "options.preset_column_widths",
        message:
            "options.preset_column_widths must list 1 to 10 increasing ratios from 0.05 to 1, such as [0.33, 0.5, 0.66]."
    )

    private static let stackLimitIssue = ConfigurationIssue.invalidValue(
        key: "options.stack_limit",
        message: "options.stack_limit must be a whole number from 1 or \"fit\"."
    )
}

/// How many windows one stack holds. The engine caps a count at what fits on the display the stack is on.
public enum StackLimit: Hashable, Sendable {
    /// As many windows as fit in a column at the engine's minimum window height.
    case fit
    case count(Int)

    /// The engine's `MIN_WINDOW_HEIGHT` in points.
    public static let minimumWindowHeight = 200

    /// How many windows fit in a column `columnHeight` points tall, counted as the engine counts them.
    public static func fitCount(columnHeight: Double) -> Int {
        max(1, Int(columnHeight) / minimumWindowHeight)
    }

    var tomlValue: TOMLValue {
        switch self {
        case .fit: .string("fit")
        case .count(let count): .integer(Int64(count))
        }
    }
}

/// A problem that stops Miri from using or changing its configuration file. Miri keeps the last valid settings.
public enum ConfigurationIssue: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidTOML(TOMLError)
    case invalidValue(key: String, message: String)
    case unreadable(String)
    case unwritable(String)
    case notEditable(String)

    public var description: String {
        switch self {
        case .invalidTOML(let error): "The configuration file is not valid TOML. \(error)"
        case .invalidValue(_, let message): message
        case .unreadable(let reason): "Miri cannot read the configuration file. \(reason)"
        case .unwritable(let reason): "Miri cannot save the configuration file. \(reason)"
        case .notEditable(let reason): reason
        }
    }
}
