// OutputPostProcessor.swift
// TacNet
//
// Post-processes every Gemma 4 E4B SLM output before it reaches AVSpeechSynthesizer.
// Pipeline position: Cactus inference output → OutputPostProcessor → TextToSpeechService.
// Enforces 29 TTS hard hooks (HH-001 through HH-029) to ensure spoken output is
// optimized for audio intelligibility under combat conditions.
//
// The SLM acts as a relay/compactor — it listens to operator voice, compresses, and
// routes to other operators' earpieces via TTS. This processor strips formatting,
// enforces brevity, removes filler, and applies military phonetic conventions.

import Foundation

public struct OutputPostProcessor: Sendable {

    public static let version = "1.0.0"

    // MARK: - Types

    public enum EarpieceRole: Sendable {
        case leader   // 18-word cap
        case peer     // 12-word cap
        case summary  // 20-word cap

        var wordCap: Int {
            switch self {
            case .leader:  return 18
            case .peer:    return 12
            case .summary: return 20
            }
        }
    }

    // MARK: - Constants

    private static let approvedAcronyms: Set<String> = [
        "EKIA", "SITREP", "SALUTE", "CASEVAC", "MEDEVAC", "LACE", "ACE", "BDA",
        "CCIR", "PIR", "EEI", "PACE", "ROE", "SOP", "TTP", "CAS", "WIA", "PC",
        "HVT", "LZ", "PZ", "ORP", "SBF", "TRP", "PL", "LD", "SP", "RP", "NVG",
        "GPNVG", "BLE", "UNK", "RTN", "AI", "TL", "SL", "NCO", "CQB", "QRF",
        "TOC", "FLOT", "LOA", "TIC", "RPG", "IED", "EOF", "KIA", "MIA", "POW",
        "FRAGO", "OPORD", "WARNO", "IP", "IR", "NLT", "IOT", "ISO", "VIC", "IVO",
        "METT-TC", "CONTACT", "SPOTREP", "DMR", "SAW"
    ]

    private static let profanityWords: Set<String> = [
        "fuck", "shit", "damn", "ass", "bitch", "bastard", "crap",
        "fucking", "shitting", "damned", "asshole", "bullshit", "dumbass",
        "motherfucker", "dickhead", "piss"
    ]

    private static let phoneticAlphabetMap: [Character: String] = [
        "A": "Alpha",    "B": "Bravo",   "C": "Charlie", "D": "Delta",
        "E": "Echo",     "F": "Foxtrot", "G": "Golf",    "H": "Hotel",
        "I": "India",    "J": "Juliet",  "K": "Kilo",    "L": "Lima",
        "M": "Mike",     "N": "November","O": "Oscar",   "P": "Papa",
        "Q": "Quebec",   "R": "Romeo",   "S": "Sierra",  "T": "Tango",
        "U": "Uniform",  "V": "Victor",  "W": "Whiskey", "X": "X-ray",
        "Y": "Yankee",   "Z": "Zulu"
    ]

    private static let numberWords: [String: String] = [
        "1": "one", "2": "two", "3": "three", "4": "four", "5": "five",
        "6": "six", "7": "seven", "8": "eight", "9": "nine"
    ]

    private static let ordinalWords: [(String, String)] = [
        ("1st", "first"), ("2nd", "second"), ("3rd", "third"),
        ("4th", "fourth"), ("5th", "fifth"), ("6th", "sixth"),
        ("7th", "seventh"), ("8th", "eighth"), ("9th", "ninth")
    ]

    private static let digitSpoken: [Character: String] = [
        "0": "zero", "1": "one", "2": "two", "3": "three", "4": "four",
        "5": "five", "6": "six", "7": "seven", "8": "eight", "9": "niner"
    ]

    private static let specialCharReplacements: [(String, String)] = [
        ("@", " at "), ("&", " and "), ("%", " percent "),
        ("+", " plus "), ("=", " equals "),
        ("<", " less than "), (">", " greater than ")
    ]

    private static let fillerPhrases: [String] = [
        "just to clarify", "in other words", "so basically",
        "let me check", "let me think", "okay so",
        "copy that", "i understand",
        "acknowledged", "understood", "actually", "basically",
        "alright", "okay", "roger", "copy", "sure", "well"
    ]

    private static let hedgingPhrases: [String] = [
        "it seems like", "it appears that", "it looks like", "it could be",
        "i think", "i believe", "might be", "may be",
        "probably", "perhaps", "possibly", "likely", "arguably", "seemingly"
    ]

    private static let pleasantryPhrases: [String] = [
        "you're welcome", "thank you", "good luck", "be safe",
        "stay safe", "take care", "please", "thanks", "sorry"
    ]

    private static let selfReferencePhrases: [String] = [
        // Identity / persona leaks
        "as your ai", "as an ai", "i'm here to help", "let me help",
        "i can assist", "my purpose is", "i'm designed to", "as tacnet",
        // Chatbot "ready" stalls
        "i'm ready to assist you", "i'm ready to assist", "ready to assist you",
        "ready to help you", "how can i help", "how can i assist",
        "please provide the text", "please provide", "what can i help you with",
        "what would you like", "feel free to ask", "don't hesitate to ask",
        "i'd be happy to", "i'll do my best", "let me know if",
        "is there anything else", "if you have any questions",
        // Retrieval-specific chatbot fallbacks
        "this is an open-ended", "open-ended prompt", "open-ended question",
        "waiting for a question", "waiting for your question",
        "please ask a specific", "please ask a question", "please be more specific",
        "i need more context", "i need more information",
        "could you clarify", "can you clarify", "could you be more specific",
        "what specifically", "what exactly would you like",
        "i don't have enough information", "i don't have enough context",
        "based on the information provided", "based on the context provided",
        "i'm not sure what you're asking", "i'm not sure what you mean",
        "here's what i can tell you", "here is what i can tell you",
        "let me summarize", "to summarize", "in summary"
    ]

    private static let doubleNegatives: [(String, String)] = [
        ("not unlikely", "likely"),
        ("not uncommon", "common"),
        ("not unreasonable", "reasonable"),
        ("not unimportant", "important"),
        ("not unnecessary", "necessary"),
        ("not unclear", "clear"),
        ("not unsure", "sure"),
        ("not impossible", "possible"),
        ("not improbable", "probable"),
        ("not insignificant", "significant"),
        ("not ineffective", "effective"),
        ("not inadequate", "adequate"),
        ("not inactive", "active"),
        ("not incomplete", "complete"),
        ("not inaccurate", "accurate")
    ]

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    @inlinable
    public func process(_ raw: String, role: EarpieceRole) -> String {
        _applyAllHooks(raw, role: role)
    }

    // MARK: - Implementation Bridge

    /// Internal entry point that chains all 29 hooks plus final cleanup.
    /// Separated from `process` to satisfy @inlinable visibility requirements
    /// while keeping individual hook methods private.
    @usableFromInline
    internal func _applyAllHooks(_ raw: String, role: EarpieceRole) -> String {
        var text = raw

        // ── FORMATTING (HH-001 to HH-006) ──
        text = stripEmoji(text)
        text = stripMarkdown(text)
        text = stripBulletPoints(text)
        text = stripParentheticals(text)
        text = stripStrayQuotes(text)
        text = stripSpecialChars(text)

        // ── LENGTH (HH-007 to HH-010) ──
        text = enforceWordCap(text, role: role)

        // ── SPOKEN CLARITY (HH-011 to HH-016) ──
        text = gateAcronyms(text)
        text = fixHomophones(text)
        text = normalizeNumbers(text)
        text = formatGridCoords(text)
        text = fixDoubleNegatives(text)
        text = preferCardinalDirections(text)

        // ── NOISE DISCIPLINE (HH-017 to HH-020) ──
        text = stripFiller(text)
        text = stripHedging(text)
        text = stripPleasantries(text)
        text = stripSelfReference(text)

        // ── SAFETY (HH-021 to HH-024) ──
        text = flagFabrication(text)
        text = qualifyBareNumbers(text)
        text = preserveClassification(text)
        text = stripProfanity(text)

        // ── TEMPORAL (HH-025 to HH-026) ──
        text = flagAbsoluteTime(text)
        // HH-026: Present-tense urgency is a soul.md behavioral rule;
        // cannot be reliably enforced programmatically — pass through.

        // ── PHONETIC (HH-027 to HH-029) ──
        text = enforceCallsigns(text)
        text = phoneticAlphabet(text)
        text = ninerConvention(text)

        // ── FINAL CLEANUP ──
        text = collapseWhitespace(text)

        return text.isEmpty ? "" : text
    }

    // MARK: - FORMATTING (HH-001 to HH-006)

    /// HH-001: Remove all Unicode emoji characters.
    private func stripEmoji(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if scalar.properties.isEmoji && scalar.properties.isEmojiPresentation {
                continue
            }
            // Strip Variation Selector-16 (U+FE0F) which forces emoji presentation
            if scalar.value == 0xFE0F {
                continue
            }
            scalars.append(scalar)
        }
        return String(scalars)
    }

    /// HH-002: Remove markdown syntax characters, preserving text content.
    private func stripMarkdown(_ text: String) -> String {
        var result = text

        // Handle markdown image syntax: ![alt](url) → alt
        if let regex = try? NSRegularExpression(pattern: "!\\[([^\\]]*)\\]\\([^)]*\\)") {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1"
            )
        }

        // Handle markdown link syntax: [text](url) → text
        if let regex = try? NSRegularExpression(pattern: "\\[([^\\]]*)\\]\\([^)]*\\)") {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1"
            )
        }

        // Strip code blocks (triple backtick)
        result = result.replacingOccurrences(of: "```", with: "")
        // Strip inline code (single backtick)
        result = result.replacingOccurrences(of: "`", with: "")

        // Strip bold/italic markers (longest patterns first)
        result = result.replacingOccurrences(of: "***", with: "")
        result = result.replacingOccurrences(of: "**", with: "")
        result = result.replacingOccurrences(of: "__", with: "")
        result = result.replacingOccurrences(of: "~~", with: "")

        // Strip heading markers at line start
        if let regex = try? NSRegularExpression(pattern: "^#{1,6}\\s*", options: .anchorsMatchLines) {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result), withTemplate: ""
            )
        }

        // Strip blockquote markers at line start
        if let regex = try? NSRegularExpression(pattern: "^>\\s?", options: .anchorsMatchLines) {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result), withTemplate: ""
            )
        }

        // Strip remaining single * (emphasis marker)
        result = result.replacingOccurrences(of: "*", with: "")

        // Strip remaining _ (emphasis marker) — replace with space to avoid joining words
        result = result.replacingOccurrences(of: "_", with: " ")

        return result
    }

    /// HH-003: Replace bullet/numbered list patterns with semicolons for spoken flow.
    private func stripBulletPoints(_ text: String) -> String {
        var result = text

        // Replace bullet markers at line start with semicolons
        // Handles: - item, * item, • item, 1. item, 2. item, etc.
        if let regex = try? NSRegularExpression(
            pattern: "^\\s*(?:[-*•]|\\d+\\.)\\s+",
            options: .anchorsMatchLines
        ) {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "; "
            )
        }

        // Replace newlines with spaces
        result = result.replacingOccurrences(of: "\r\n", with: " ")
        result = result.replacingOccurrences(of: "\n", with: " ")
        result = result.replacingOccurrences(of: "\r", with: " ")

        // Clean up leading semicolons from first list item
        let trimmed = result.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix(";") {
            return String(trimmed.drop(while: { $0 == ";" || $0 == " " }))
        }
        return result
    }

    /// HH-004: Remove text inside parentheses including the parens.
    private func stripParentheticals(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\\([^)]*\\)") else { return text }
        return regex.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text), withTemplate: ""
        )
    }

    /// HH-005: Remove quote characters unless part of a contraction.
    private func stripStrayQuotes(_ text: String) -> String {
        var result = ""
        let chars = Array(text)
        for i in 0..<chars.count {
            let c = chars[i]

            // Strip all double quotes (straight and curly)
            if c == "\"" || c == "\u{201C}" || c == "\u{201D}" {
                continue
            }

            // Handle single quotes / apostrophes (straight and curly)
            if c == "'" || c == "\u{2018}" || c == "\u{2019}" {
                // Keep if part of a contraction: letter on both sides
                let hasBefore = i > 0 && chars[i - 1].isLetter
                let hasAfter = i < chars.count - 1 && chars[i + 1].isLetter
                if !(hasBefore && hasAfter) {
                    continue // Strip non-contraction single quotes
                }
            }

            result.append(c)
        }
        return result
    }

    /// HH-006: Replace special characters with spoken equivalents; strip remaining non-standard chars.
    private func stripSpecialChars(_ text: String) -> String {
        var result = text

        // Replace known special characters with spoken equivalents
        for (char, replacement) in Self.specialCharReplacements {
            result = result.replacingOccurrences(of: char, with: replacement)
        }

        // Remove any remaining non-alphanumeric, non-space, non-basic-punctuation characters
        // Keep: letters, digits, whitespace, period, comma, semicolon, colon, exclamation,
        //       question mark, apostrophe, hyphen
        if let regex = try? NSRegularExpression(pattern: "[^a-zA-Z0-9\\s.,;:!?'\\-]") {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result), withTemplate: ""
            )
        }

        return result
    }

    // MARK: - LENGTH (HH-007 to HH-010)

    /// HH-007 through HH-010: Enforce word cap based on earpiece role.
    /// Leader = 18 words, Peer = 12 words, Summary = 20 words.
    /// Truncates without ellipsis.
    private func enforceWordCap(_ text: String, role: EarpieceRole) -> String {
        let words = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let cap = role.wordCap
        guard words.count > cap else { return text }
        return words.prefix(cap).joined(separator: " ")
    }

    // MARK: - SPOKEN CLARITY (HH-011 to HH-016)

    /// HH-011: Gate acronyms against the pre-approved military set.
    /// Unapproved all-caps words (2+ letters) are lowercased.
    /// Single uppercase letters are preserved for phonetic alphabet conversion.
    private func gateAcronyms(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "\\b([A-Z]{2,}(?:-[A-Z]+)*)\\b"
        ) else { return text }

        var result = text
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))

        // Process in reverse to maintain valid ranges after replacement
        for match in matches.reversed() {
            guard let range = Range(match.range(at: 1), in: result) else { continue }
            let acronym = String(result[range])
            if !Self.approvedAcronyms.contains(acronym) {
                result.replaceSubrange(range, with: acronym.lowercased())
            }
        }

        return result
    }

    /// HH-012: Fix homophones.
    /// When "right" appears alone, leave as-is — too risky to auto-correct without
    /// spatial context. This is primarily a soul.md behavioral rule.
    private func fixHomophones(_ text: String) -> String {
        return text
    }

    /// HH-013: Normalize small numbers to words. Digits 1–9 → words, 10+ stay as digits.
    /// Also handles ordinals: 1st → first, 2nd → second, etc.
    private func normalizeNumbers(_ text: String) -> String {
        var result = text

        // Handle ordinals first (before simple digits, since "1st" contains "1")
        for (pattern, word) in Self.ordinalWords {
            let escaped = NSRegularExpression.escapedPattern(for: pattern)
            if let regex = try? NSRegularExpression(
                pattern: "\\b\(escaped)\\b",
                options: .caseInsensitive
            ) {
                result = regex.stringByReplacingMatches(
                    in: result, range: NSRange(result.startIndex..., in: result), withTemplate: word
                )
            }
        }

        // Handle standalone single digits 1-9 → words
        // Negative lookbehind/lookahead for digits ensures we only match standalone digits
        for (digit, word) in Self.numberWords {
            if let regex = try? NSRegularExpression(pattern: "(?<!\\d)\(digit)(?!\\d)") {
                result = regex.stringByReplacingMatches(
                    in: result, range: NSRange(result.startIndex..., in: result), withTemplate: word
                )
            }
        }

        return result
    }

    /// HH-014: Format grid coordinate patterns (6–8 digit sequences) as spoken digit groups.
    /// "12345678" → "one two three four, five six seven eight"
    private func formatGridCoords(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\\b(\\d{6,8})\\b") else { return text }

        var result = text
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))

        for match in matches.reversed() {
            guard let range = Range(match.range(at: 1), in: result) else { continue }
            let digits = String(result[range])
            let midpoint = digits.count / 2
            let firstHalf = digits.prefix(midpoint)
            let secondHalf = digits.suffix(digits.count - midpoint)

            let spokenFirst = firstHalf.map { Self.digitSpoken[$0] ?? String($0) }.joined(separator: " ")
            let spokenSecond = secondHalf.map { Self.digitSpoken[$0] ?? String($0) }.joined(separator: " ")
            let spoken = spokenFirst + ", " + spokenSecond

            result.replaceSubrange(range, with: spoken)
        }

        return result
    }

    /// HH-015: Simplify double negatives.
    /// "not unlikely" → "likely", "not impossible" → "possible", etc.
    private func fixDoubleNegatives(_ text: String) -> String {
        var result = text

        for (search, replacement) in Self.doubleNegatives {
            let escaped = NSRegularExpression.escapedPattern(for: search)
            if let regex = try? NSRegularExpression(
                pattern: "\\b\(escaped)\\b",
                options: .caseInsensitive
            ) {
                result = regex.stringByReplacingMatches(
                    in: result, range: NSRange(result.startIndex..., in: result), withTemplate: replacement
                )
            }
        }

        return result
    }

    /// HH-016: Prefer cardinal directions over relative "left"/"right".
    /// When "left side" or "right side" appears, leave as-is — we cannot determine
    /// the cardinal equivalent without spatial context. Enforced by soul.md.
    private func preferCardinalDirections(_ text: String) -> String {
        return text
    }

    // MARK: - NOISE DISCIPLINE (HH-017 to HH-020)

    /// HH-017: Strip filler words and acknowledgment phrases.
    private func stripFiller(_ text: String) -> String {
        var result = text

        // Strip leading "Roger, " or "Copy, " when followed by actual content
        if let regex = try? NSRegularExpression(
            pattern: "^(?:Roger|Copy),?\\s+",
            options: .caseInsensitive
        ) {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result), withTemplate: ""
            )
        }

        // Strip filler phrases (sorted longest-first to avoid partial matches)
        result = removePhrases(result, phrases: Self.fillerPhrases)

        return result
    }

    /// HH-018: Strip hedging language.
    private func stripHedging(_ text: String) -> String {
        return removePhrases(text, phrases: Self.hedgingPhrases)
    }

    /// HH-019: Strip pleasantries.
    private func stripPleasantries(_ text: String) -> String {
        return removePhrases(text, phrases: Self.pleasantryPhrases)
    }

    /// HH-020: Strip self-referential AI phrases.
    private func stripSelfReference(_ text: String) -> String {
        return removePhrases(text, phrases: Self.selfReferencePhrases)
    }

    // MARK: - SAFETY (HH-021 to HH-024)

    /// HH-021: Flag fabricated grid coordinates.
    /// NOTE: This hook requires the original input text to detect fabrication
    /// (i.e., the output contains a grid coordinate that the input never mentioned).
    /// Currently a pass-through. Future enhancement: accept input text as parameter
    /// and compare grid references between input and output.
    private func flagFabrication(_ text: String) -> String {
        return text
    }

    /// HH-022: Qualify bare numbers (e.g., enemy counts) with confirmed/estimated.
    /// NOTE: This hook requires the original input text to verify whether counts
    /// are confirmed or estimated. Currently a pass-through. Future enhancement:
    /// accept input context and cross-reference numeric claims.
    private func qualifyBareNumbers(_ text: String) -> String {
        return text
    }

    /// HH-023: Preserve classification markings.
    /// NOTE: This hook requires the original input context to verify classification
    /// levels are preserved correctly. Currently a pass-through.
    private func preserveClassification(_ text: String) -> String {
        return text
    }

    /// HH-024: Strip profanity.
    private func stripProfanity(_ text: String) -> String {
        var result = text
        for word in Self.profanityWords {
            let escaped = NSRegularExpression.escapedPattern(for: word)
            if let regex = try? NSRegularExpression(
                pattern: "\\b\(escaped)\\b",
                options: .caseInsensitive
            ) {
                result = regex.stringByReplacingMatches(
                    in: result, range: NSRange(result.startIndex..., in: result), withTemplate: ""
                )
            }
        }
        return result
    }

    // MARK: - TEMPORAL (HH-025 to HH-026)

    /// HH-025: Flag absolute time references.
    /// Replaces HH:MM or HH:MM:SS patterns with "time reference" as a conservative fallback.
    /// Absolute times can be stale or misleading in relay; soul.md enforces relative time usage.
    private func flagAbsoluteTime(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "\\b\\d{1,2}:\\d{2}(?::\\d{2})?\\b"
        ) else { return text }
        return regex.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "time reference"
        )
    }

    // HH-026: Present-tense urgency is a soul.md behavioral rule.
    // Cannot be reliably enforced programmatically — no hook needed.

    // MARK: - PHONETIC (HH-027 to HH-029)

    /// HH-027: Enforce callsign usage.
    /// NOTE: Name detection requires a roster of known operators/callsigns.
    /// Currently a pass-through. Future enhancement: accept a roster and replace
    /// real names with their assigned callsigns.
    private func enforceCallsigns(_ text: String) -> String {
        return text
    }

    /// HH-028: Replace single uppercase letters with NATO phonetic alphabet.
    /// A → Alpha, B → Bravo, etc. Only matches isolated letters (not part of a word).
    private func phoneticAlphabet(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "(?<![A-Za-z])([A-Z])(?![A-Za-z])"
        ) else { return text }

        var result = text
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))

        // Process in reverse to maintain valid ranges after replacement
        for match in matches.reversed() {
            guard let range = Range(match.range(at: 1), in: result) else { continue }
            guard let letter = result[range].first,
                  let phonetic = Self.phoneticAlphabetMap[letter] else { continue }
            result.replaceSubrange(range, with: phonetic)
        }

        return result
    }

    /// HH-029: Replace "nine" with "niner" per military radio convention.
    /// Also handles standalone digit "9" not part of a larger number.
    private func ninerConvention(_ text: String) -> String {
        var result = text

        // Replace spoken "nine" (word boundary) with "niner"
        if let regex = try? NSRegularExpression(pattern: "\\bnine\\b", options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "niner"
            )
        }

        // Replace standalone digit "9" (not part of a larger number) with "niner"
        if let regex = try? NSRegularExpression(pattern: "(?<!\\d)9(?!\\d)") {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "niner"
            )
        }

        return result
    }

    // MARK: - FINAL CLEANUP

    /// Collapse multiple whitespace characters into a single space and trim.
    private func collapseWhitespace(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\\s+") else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let collapsed = regex.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " "
        )
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Shared Helpers

    /// Remove a list of phrases from text using word-boundary matching.
    /// Phrases are processed longest-first to avoid partial matches.
    private func removePhrases(_ text: String, phrases: [String]) -> String {
        var result = text
        let sorted = phrases.sorted { $0.count > $1.count }

        for phrase in sorted {
            let escaped = NSRegularExpression.escapedPattern(for: phrase)
            if let regex = try? NSRegularExpression(
                pattern: "\\b\(escaped)\\b,?\\s*",
                options: .caseInsensitive
            ) {
                result = regex.stringByReplacingMatches(
                    in: result, range: NSRange(result.startIndex..., in: result), withTemplate: ""
                )
            }
        }

        return result
    }
}
