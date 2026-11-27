import Foundation

/// Searches shortcut actions across every language bundled in the app, with fuzzy matching for multi-word queries,
/// acronyms, subsequences, and typos.
public struct ShortcutSearch: Sendable {
    private struct IndexedText: Sendable {
        let normalized: String
        let characters: [Character]
        let words: [String]
        let wordCharacters: [[Character]]
        let isWordStart: [Bool]
        let isPrimary: Bool

        init(_ raw: String, isPrimary: Bool) {
            let normalized = ShortcutSearch.normalize(raw)
            let characters = Array(normalized)
            let words = normalized.split(whereSeparator: ShortcutSearch.isWordSeparator).map(String.init)
            var isWordStart = [Bool](repeating: false, count: characters.count)
            var previousWasSeparator = true
            for index in characters.indices {
                let isSeparator = ShortcutSearch.isWordSeparator(characters[index])
                if !isSeparator && previousWasSeparator {
                    isWordStart[index] = true
                }
                previousWasSeparator = isSeparator
            }
            self.normalized = normalized
            self.characters = characters
            self.words = words
            self.wordCharacters = words.map(Array.init)
            self.isWordStart = isWordStart
            self.isPrimary = isPrimary
        }
    }

    private struct PreparedQuery {
        let normalized: String
        let compactCharacters: [Character]
        let tokens: [String]

        init?(_ raw: String) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let normalized = ShortcutSearch.normalize(trimmed)
            let compactCharacters = Array(normalized.filter { !$0.isWhitespace })
            guard !compactCharacters.isEmpty else { return nil }
            self.normalized = normalized
            self.compactCharacters = compactCharacters
            self.tokens = normalized.split(whereSeparator: \.isWhitespace).map(String.init)
        }
    }

    private enum Score {
        static let primaryBonus = 15
        static let exactTitle = 1000
        static let prefixTitle = 900
        static let wordStartTitle = 800
        static let substringTitle = 700
        static let exactWord = 640
        static let prefixWord = 600
        static let substringToken = 560
        static let exactChord = 950
        static let prefixChord = 850
        static let substringChord = 750
        static let subsequenceChord = 480
        static let boundaryStart = 500
        static let boundaryContiguousBonus = 8
        static let boundaryJumpPenalty = 2
        static let compactBase = 430
        static let compactGapPenalty = 10
        static let compactFloor = 300
        static let typoBase = 530
        static let typoDistancePenalty = 70
    }

    /// The default index built from the running app bundle's compiled localizations.
    public static let shared = ShortcutSearch(bundle: .main)

    private let titlesByAction: [ShortcutAction: [IndexedText]]

    /// Indexes every editable action's title in the current locale, English, and every localization in `bundle`.
    init(bundle: Bundle = .main) {
        let localizations: [(Locale, Bundle)] = Self.languages(in: bundle).map { language in
            let lproj = bundle.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? bundle
            return (Locale(identifier: language), lproj)
        }
        var indexed: [ShortcutAction: [IndexedText]] = [:]
        for action in ShortcutAction.editable {
            let primary = action.title
            var candidates: [String] = [primary]
            if let resource = action.titleResource {
                for (locale, lproj) in localizations {
                    candidates.append(
                        String(localized: resource.defaultValue, table: resource.table, bundle: lproj, locale: locale))
                }
            }
            indexed[action] = Self.deduplicate(candidates, primary: primary)
        }
        self.titlesByAction = indexed
    }

    /// Returns the actions matching `query`, ranked best match first with ties in `actions` order.
    /// An empty or whitespace-only query returns `actions` unchanged.
    public func filter(
        _ actions: [ShortcutAction], query: String, shortcuts: Shortcuts
    ) -> [ShortcutAction] {
        guard let prepared = PreparedQuery(query) else { return actions }
        var scored: [(action: ShortcutAction, score: Int, index: Int)] = []
        for (index, action) in actions.enumerated() {
            let titles = titlesByAction[action] ?? [IndexedText(action.title, isPrimary: true)]
            var best = titles.compactMap { Self.scoreTitle(prepared, against: $0) }.max()
            for chord in shortcuts.chords(for: action) {
                if let chordScore = Self.scoreChord(prepared, label: shortcuts.layout.label(for: chord)) {
                    best = max(best ?? Int.min, chordScore)
                }
            }
            if let best {
                scored.append((action, best, index))
            }
        }
        scored.sort { $0.score != $1.score ? $0.score > $1.score : $0.index < $1.index }
        return scored.map(\.action)
    }

    /// Returns the unlisted engine bindings matching `query`, ranked best match first with ties in file order.
    public func filterOthers(query: String, shortcuts: Shortcuts) -> [Shortcuts.OtherBinding] {
        guard let prepared = PreparedQuery(query) else { return shortcuts.others }
        var scored: [(other: Shortcuts.OtherBinding, score: Int, index: Int)] = []
        for (index, other) in shortcuts.others.enumerated() {
            var best = Self.scoreTitle(prepared, against: IndexedText(other.key, isPrimary: true))
            for chord in other.chords {
                if let chordScore = Self.scoreChord(prepared, label: shortcuts.layout.label(for: chord)) {
                    best = max(best ?? Int.min, chordScore)
                }
            }
            if let best {
                scored.append((other, best, index))
            }
        }
        scored.sort { $0.score != $1.score ? $0.score > $1.score : $0.index < $1.index }
        return scored.map(\.other)
    }

    // MARK: - Indexing

    private static func languages(in bundle: Bundle) -> [String] {
        // Not interface text
        var result = Set(bundle.localizations.filter { $0 != "Base" })
        // English is always included so English queries match even when the app runs in another language
        // or when a test bundle omits en.lproj.
        result.insert("en")
        return result.sorted()
    }

    private static func deduplicate(_ candidates: [String], primary: String) -> [IndexedText] {
        let primaryNormalized = normalize(primary)
        var seen = Set<String>()
        var result: [IndexedText] = []
        for candidate in candidates {
            let entry = IndexedText(candidate, isPrimary: normalize(candidate) == primaryNormalized)
            guard !entry.normalized.isEmpty, seen.insert(entry.normalized).inserted else { continue }
            result.append(entry)
        }
        return result
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            // Turkish dotless `ı` does not fold to `i` under non-Turkish locales, while uppercase `I` folds to `i`.
            .replacingOccurrences(of: "\u{0131}", with: "i")
    }

    private static func isWordSeparator(_ character: Character) -> Bool {
        character.isWhitespace || character == "-" || character == "_" || character == "/"
    }

    // MARK: - Scoring

    private static func scoreTitle(_ query: PreparedQuery, against title: IndexedText) -> Int? {
        let primaryBonus = title.isPrimary ? Score.primaryBonus : 0
        if title.normalized == query.normalized {
            return Score.exactTitle + primaryBonus
        }
        if title.normalized.hasPrefix(query.normalized) {
            return Score.prefixTitle + primaryBonus
        }
        if containsAtWordStart(query.normalized, in: title) {
            return Score.wordStartTitle + primaryBonus
        }
        if title.normalized.contains(query.normalized) {
            return Score.substringTitle + primaryBonus
        }

        if query.tokens.count > 1 {
            var tokenScores: [Int] = []
            for token in query.tokens {
                guard let score = scoreToken(token, in: title) else { return nil }
                tokenScores.append(score)
            }
            let minScore = tokenScores.min() ?? 0
            let avgScore = tokenScores.reduce(0, +) / tokenScores.count
            return (minScore * 2 + avgScore) / 3 + primaryBonus
        }

        let token = query.tokens[0]
        var best: Int?
        if let boundaryScore = matchWordBoundarySubsequence(query.compactCharacters, in: title) {
            best = max(best ?? Int.min, boundaryScore)
        }
        if let typoScore = matchWordTypo(token, in: title) {
            best = max(best ?? Int.min, typoScore)
        }
        if let compactScore = matchCompactSubsequence(query.compactCharacters, in: title.characters) {
            best = max(best ?? Int.min, compactScore)
        }
        return best.map { $0 + primaryBonus }
    }

    private static func scoreToken(_ token: String, in title: IndexedText) -> Int? {
        if title.words.contains(token) {
            return Score.exactWord
        }
        if title.words.contains(where: { $0.hasPrefix(token) }) {
            return Score.prefixWord
        }
        if title.normalized.contains(token) {
            return Score.substringToken
        }
        if let typoScore = matchWordTypo(token, in: title) {
            return typoScore
        }
        let tokenCharacters = Array(token)
        if tokenCharacters.count >= 2 {
            var best: Int?
            for word in title.wordCharacters {
                if let compact = matchCompactSubsequence(tokenCharacters, in: word) {
                    best = max(best ?? Int.min, compact)
                }
            }
            if best != nil {
                return best
            }
        }
        return nil
    }

    /// Shortcut labels are short (`⌃⌥H`, `⌃⌥J`), so they match by substring or subsequence only, never edit distance.
    private static func scoreChord(_ query: PreparedQuery, label: String) -> Int? {
        let normalizedLabel = normalize(label)
        if normalizedLabel == query.normalized {
            return Score.exactChord
        }
        if normalizedLabel.hasPrefix(query.normalized) {
            return Score.prefixChord
        }
        if normalizedLabel.contains(query.normalized) {
            return Score.substringChord
        }
        let labelCharacters = Array(normalizedLabel)
        if query.compactCharacters.count >= 2,
            isSubsequence(query.compactCharacters, of: labelCharacters)
        {
            return Score.subsequenceChord
        }
        return nil
    }

    private static func containsAtWordStart(_ needle: String, in title: IndexedText) -> Bool {
        var searchStart = title.normalized.startIndex
        while let range = title.normalized.range(of: needle, range: searchStart..<title.normalized.endIndex) {
            if range.lowerBound == title.normalized.startIndex {
                return true
            }
            let before = title.normalized[title.normalized.index(before: range.lowerBound)]
            if isWordSeparator(before) {
                return true
            }
            searchStart = title.normalized.index(after: range.lowerBound)
        }
        return false
    }

    /// Matches a query whose first character starts a word and each following character either continues immediately
    /// after the previous match or jumps to a later word start (e.g. "fcl" -> "Focus column left",
    /// "maxwin" -> "Maximize or restore window").
    private static func matchWordBoundarySubsequence(_ query: [Character], in title: IndexedText) -> Int? {
        guard query.count >= 2, query.count <= title.characters.count else { return nil }
        let chars = title.characters
        let starts = title.isWordStart
        let m = query.count
        let n = chars.count

        // `previous[j]` holds the best score ending at index `j` for the current query prefix, or nil if unreachable.
        var previous = [Int?](repeating: nil, count: n)
        var anyFirst = false
        for j in 0..<n where starts[j] && chars[j] == query[0] {
            previous[j] = Score.boundaryStart
            anyFirst = true
        }
        guard anyFirst else { return nil }

        for i in 1..<m {
            var current = [Int?](repeating: nil, count: n)
            var bestBefore: Int?
            var anyCurrent = false
            for j in 0..<n {
                if chars[j] == query[i] {
                    var best: Int?
                    if j > 0, let contiguous = previous[j - 1] {
                        best = contiguous + Score.boundaryContiguousBonus
                    }
                    if starts[j], let jumped = bestBefore {
                        best = max(best ?? Int.min, jumped - Score.boundaryJumpPenalty)
                    }
                    if let best {
                        current[j] = best
                        anyCurrent = true
                    }
                }
                if let prev = previous[j] {
                    bestBefore = max(bestBefore ?? Int.min, prev)
                }
            }
            guard anyCurrent else { return nil }
            previous = current
        }
        return previous.compactMap { $0 }.max()
    }

    /// Matches a query whose characters appear in order inside a tight span with no single gap wider than 3 characters
    /// (e.g. "聚焦列" -> "聚焦左侧列", "stck" -> "stack", "最大化窗口" -> "最大化或还原窗口").
    private static func matchCompactSubsequence(_ query: [Character], in target: [Character]) -> Int? {
        guard query.count >= 2, query.count <= target.count else { return nil }
        let maxGap = 3
        let maxSpan = query.count * 2 + 2
        var bestSpan: Int?

        for start in 0..<target.count where target[start] == query[0] {
            var position = start
            var matched = true
            for qIndex in 1..<query.count {
                let limit = min(target.count - 1, position + maxGap + 1)
                var found: Int?
                if position + 1 <= limit {
                    for candidate in (position + 1)...limit where target[candidate] == query[qIndex] {
                        found = candidate
                        break
                    }
                }
                guard let next = found else {
                    matched = false
                    break
                }
                position = next
            }
            if matched {
                let span = position - start + 1
                if span <= maxSpan {
                    bestSpan = min(bestSpan ?? Int.max, span)
                }
            }
        }
        guard let bestSpan else { return nil }
        let totalGaps = bestSpan - query.count
        return max(Score.compactFloor, Score.compactBase - totalGaps * Score.compactGapPenalty)
    }

    private static func matchWordTypo(_ token: String, in title: IndexedText) -> Int? {
        let tokenChars = Array(token)
        guard tokenChars.count >= 4 else { return nil }
        let maxEdits = tokenChars.count >= 7 ? 2 : 1
        let allowSubstrings = containsUnspacedScript(tokenChars)
        var bestDistance: Int?
        for wordChars in title.wordCharacters {
            if abs(wordChars.count - tokenChars.count) <= maxEdits,
                let distance = damerauLevenshtein(tokenChars, wordChars, maxDistance: maxEdits)
            {
                bestDistance = min(bestDistance ?? Int.max, distance)
            }
            if allowSubstrings, wordChars.count > tokenChars.count {
                // Unspaced scripts (Chinese, Japanese, Thai) pack whole phrases into one token even when punctuation
                // splits a title, so check bounded windows within each token.
                let minLen = max(1, tokenChars.count - maxEdits)
                let maxLen = min(wordChars.count, tokenChars.count + maxEdits)
                for start in 0..<(wordChars.count - minLen + 1) {
                    let upperLen = min(maxLen, wordChars.count - start)
                    for len in minLen...upperLen {
                        if let distance = damerauLevenshtein(
                            tokenChars, Array(wordChars[start..<(start + len)]), maxDistance: maxEdits)
                        {
                            bestDistance = min(bestDistance ?? Int.max, distance)
                        }
                    }
                }
            }
        }
        guard let bestDistance else { return nil }
        return Score.typoBase - bestDistance * Score.typoDistancePenalty
    }

    private static func containsUnspacedScript(_ characters: [Character]) -> Bool {
        characters.contains { character in
            character.unicodeScalars.contains { scalar in
                switch scalar.value {
                case 0x0E00...0x0E7F, 0x3040...0x30FF, 0x3400...0x9FFF, 0xF900...0xFAFF, 0x20000...0x2FA1F:
                    true
                default:
                    false
                }
            }
        }
    }

    private static func isSubsequence(_ needle: [Character], of haystack: [Character]) -> Bool {
        var index = 0
        for character in haystack {
            if character == needle[index] {
                index += 1
                if index == needle.count { return true }
            }
        }
        return false
    }

    private static func damerauLevenshtein(_ first: [Character], _ second: [Character], maxDistance: Int) -> Int? {
        let m = first.count
        let n = second.count
        if abs(m - n) > maxDistance { return nil }
        if m == 0 { return n <= maxDistance ? n : nil }
        if n == 0 { return m <= maxDistance ? m : nil }

        let width = n + 1
        var matrix = [Int](repeating: 0, count: (m + 1) * width)
        for i in 0...m { matrix[i * width] = i }
        for j in 0...n { matrix[j] = j }

        for i in 1...m {
            var rowMin = Int.max
            for j in 1...n {
                let cost = first[i - 1] == second[j - 1] ? 0 : 1
                var value = min(
                    matrix[(i - 1) * width + j] + 1,
                    matrix[i * width + (j - 1)] + 1,
                    matrix[(i - 1) * width + (j - 1)] + cost
                )
                if i > 1 && j > 1 && first[i - 1] == second[j - 2] && first[i - 2] == second[j - 1] {
                    value = min(value, matrix[(i - 2) * width + (j - 2)] + 1)
                }
                matrix[i * width + j] = value
                rowMin = min(rowMin, value)
            }
            if rowMin > maxDistance {
                return nil
            }
        }
        let distance = matrix[m * width + n]
        return distance <= maxDistance ? distance : nil
    }
}
