import XCTest
@testable import TacNet

// MARK: - OutputPostProcessor XCTest Suite
// Comprehensive tests for the 29 TTS hard-hooks enforced by OutputPostProcessor.

final class OutputPostProcessorTests: XCTestCase {

    private let processor = OutputPostProcessor()

    // ──────────────────────────────────────────────
    // MARK: HH-001 — Emoji Stripping
    // ──────────────────────────────────────────────

    func test_HH001_stripsEmoji() {
        let result = processor.process("Contact north 🔥", role: .leader)
        XCTAssertFalse(result.contains("🔥"), "Emoji should be stripped from output")
        XCTAssertTrue(result.lowercased().contains("contact"), "Tactical content must be preserved")
    }

    func test_HH001_stripsMultipleEmoji() {
        let result = processor.process("🚨 Contact 💀 north 🔥🔥", role: .leader)
        XCTAssertFalse(result.contains("🚨"))
        XCTAssertFalse(result.contains("💀"))
        XCTAssertFalse(result.contains("🔥"))
    }

    func test_HH001_noEmojiPassesThrough() {
        let result = processor.process("Contact north", role: .leader)
        XCTAssertTrue(result.lowercased().contains("contact north"))
    }

    // ──────────────────────────────────────────────
    // MARK: HH-002 — Markdown Stripping
    // ──────────────────────────────────────────────

    func test_HH002_stripsBoldMarkdown() {
        let result = processor.process("**CONTACT** north", role: .leader)
        XCTAssertFalse(result.contains("**"), "Bold markdown markers should be stripped")
        XCTAssertTrue(result.contains("CONTACT"), "Bold content text must be preserved")
    }

    func test_HH002_stripsItalicMarkdown() {
        let result = processor.process("*moving* north", role: .leader)
        XCTAssertFalse(result.contains("*"), "Italic markdown markers should be stripped")
        XCTAssertTrue(result.lowercased().contains("moving"), "Italic content text must be preserved")
    }

    func test_HH002_stripsHeaders() {
        let result = processor.process("## SITREP", role: .leader)
        XCTAssertFalse(result.contains("#"), "Markdown header markers should be stripped")
        XCTAssertTrue(result.contains("SITREP"), "Header text must be preserved")
    }

    func test_HH002_stripsMultipleLevelHeaders() {
        let result = processor.process("### Contact Report", role: .leader)
        XCTAssertFalse(result.contains("#"))
    }

    // ──────────────────────────────────────────────
    // MARK: HH-003 — Bullet List Joining
    // ──────────────────────────────────────────────

    func test_HH003_joinsBulletList() {
        let input = "- Floor 1 clear\n- Floor 2 contact"
        let result = processor.process(input, role: .leader)
        // Should be a single line joined with semicolons
        XCTAssertFalse(result.contains("\n"), "Bullet items should be joined into a single line")
        XCTAssertTrue(result.contains(";"), "Bullet items should be joined with semicolons")
        XCTAssertTrue(result.lowercased().contains("floor 1 clear"))
        XCTAssertTrue(result.lowercased().contains("floor 2 contact"))
    }

    func test_HH003_joinsNumberedList() {
        let input = "1. Alpha cleared\n2. Bravo holding"
        let result = processor.process(input, role: .leader)
        XCTAssertFalse(result.contains("\n"), "Numbered list items should be joined into a single line")
    }

    // ──────────────────────────────────────────────
    // MARK: HH-004 — Parenthetical Removal
    // ──────────────────────────────────────────────

    func test_HH004_removesParenthetical() {
        let result = processor.process("Moving (slowly) to north", role: .leader)
        XCTAssertFalse(result.contains("("), "Opening paren should be removed")
        XCTAssertFalse(result.contains(")"), "Closing paren should be removed")
        XCTAssertFalse(result.lowercased().contains("slowly"), "Parenthetical content should be removed")
        XCTAssertTrue(result.lowercased().contains("moving"))
        XCTAssertTrue(result.lowercased().contains("north"))
    }

    func test_HH004_removesMultipleParentheticals() {
        let result = processor.process("Team (alpha) moving (fast) north", role: .leader)
        XCTAssertFalse(result.contains("("))
        XCTAssertFalse(result.contains(")"))
    }

    // ──────────────────────────────────────────────
    // MARK: HH-005 — Quote Removal (Contractions Preserved)
    // ──────────────────────────────────────────────

    func test_HH005_removesStrayQuotes() {
        let result = processor.process("He said \"contact\"", role: .leader)
        XCTAssertFalse(result.contains("\""), "Stray double quotes should be removed")
    }

    func test_HH005_preservesContractions() {
        let result = processor.process("don't stop", role: .leader)
        XCTAssertTrue(result.lowercased().contains("don't"), "Contractions must be preserved")
    }

    func test_HH005_removesSingleStrayQuotes() {
        let result = processor.process("the 'target' is north", role: .leader)
        // Single quotes used for quoting (not contractions) should be removed
        XCTAssertFalse(result.contains("'target'"), "Stray single quotes around words should be removed")
    }

    // ──────────────────────────────────────────────
    // MARK: HH-006 — Special Character Replacement
    // ──────────────────────────────────────────────

    func test_HH006_percentToWord() {
        let result = processor.process("50% complete", role: .leader)
        XCTAssertFalse(result.contains("%"), "Percent symbol should be replaced")
        XCTAssertTrue(result.lowercased().contains("50 percent"), "'%' should become ' percent'")
    }

    func test_HH006_atSignToWord() {
        let result = processor.process("@grid", role: .leader)
        XCTAssertFalse(result.contains("@"), "@ symbol should be replaced")
        XCTAssertTrue(result.lowercased().contains("at grid"), "'@' should become 'at '")
    }

    func test_HH006_ampersandToWord() {
        let result = processor.process("A & B", role: .leader)
        XCTAssertFalse(result.contains("&"), "Ampersand should be replaced")
        XCTAssertTrue(result.lowercased().contains("a and b"), "'&' should become 'and'")
    }

    // ──────────────────────────────────────────────
    // MARK: HH-007 — Leader Word Cap (18 words)
    // ──────────────────────────────────────────────

    func test_HH007_leaderWordCap() {
        // Build a 25-word input of clean tactical words (no filters will eat them)
        let words = (1...25).map { "word\($0)" }
        let input = words.joined(separator: " ")
        let result = processor.process(input, role: .leader)
        let outputWordCount = result.split(separator: " ").count
        XCTAssertLessThanOrEqual(outputWordCount, 18, "Leader output must be capped at 18 words")
    }

    func test_HH007_leaderCapNoEllipsis() {
        let words = (1...25).map { "word\($0)" }
        let input = words.joined(separator: " ")
        let result = processor.process(input, role: .leader)
        XCTAssertFalse(result.contains("…"), "Truncation must not add ellipsis")
        XCTAssertFalse(result.contains("..."), "Truncation must not add ellipsis dots")
    }

    // ──────────────────────────────────────────────
    // MARK: HH-008 — Peer Word Cap (12 words)
    // ──────────────────────────────────────────────

    func test_HH008_peerWordCap() {
        let words = (1...20).map { "word\($0)" }
        let input = words.joined(separator: " ")
        let result = processor.process(input, role: .peer)
        let outputWordCount = result.split(separator: " ").count
        XCTAssertLessThanOrEqual(outputWordCount, 12, "Peer output must be capped at 12 words")
    }

    func test_HH008_peerCapNoEllipsis() {
        let words = (1...20).map { "word\($0)" }
        let input = words.joined(separator: " ")
        let result = processor.process(input, role: .peer)
        XCTAssertFalse(result.contains("…"), "Truncation must not add ellipsis")
        XCTAssertFalse(result.contains("..."), "Truncation must not add ellipsis dots")
    }

    // ──────────────────────────────────────────────
    // MARK: HH-009 — Summary Word Cap (20 words)
    // ──────────────────────────────────────────────

    func test_HH009_summaryWordCap() {
        let words = (1...30).map { "word\($0)" }
        let input = words.joined(separator: " ")
        let result = processor.process(input, role: .summary)
        let outputWordCount = result.split(separator: " ").count
        XCTAssertLessThanOrEqual(outputWordCount, 20, "Summary output must be capped at 20 words")
    }

    func test_HH009_summaryCapNoEllipsis() {
        let words = (1...30).map { "word\($0)" }
        let input = words.joined(separator: " ")
        let result = processor.process(input, role: .summary)
        XCTAssertFalse(result.contains("…"))
        XCTAssertFalse(result.contains("..."))
    }

    // ──────────────────────────────────────────────
    // MARK: HH-010 — Short Input Under Cap
    // ──────────────────────────────────────────────

    func test_HH010_shortInputUnderLeaderCap() {
        let result = processor.process("contact north", role: .leader)
        XCTAssertEqual(result, "contact north", "Short clean input should pass through unchanged")
    }

    func test_HH010_shortInputUnderPeerCap() {
        let result = processor.process("contact north", role: .peer)
        XCTAssertEqual(result, "contact north", "Short clean input should pass through unchanged")
    }

    func test_HH010_shortInputUnderSummaryCap() {
        let result = processor.process("contact north", role: .summary)
        XCTAssertEqual(result, "contact north", "Short clean input should pass through unchanged")
    }

    // ──────────────────────────────────────────────
    // MARK: HH-011 — Approved Acronyms Preserved
    // ──────────────────────────────────────────────

    func test_HH011_approvedAcronymEKIA() {
        let result = processor.process("EKIA confirmed", role: .leader)
        XCTAssertTrue(result.contains("EKIA"), "Approved acronym EKIA must be preserved in uppercase")
    }

    func test_HH011_approvedAcronymSITREP() {
        let result = processor.process("SITREP follows", role: .leader)
        XCTAssertTrue(result.contains("SITREP"), "Approved acronym SITREP must be preserved")
    }

    func test_HH011_approvedAcronymCASEVAC() {
        let result = processor.process("CASEVAC needed", role: .leader)
        XCTAssertTrue(result.contains("CASEVAC"), "Approved acronym CASEVAC must be preserved")
    }

    func test_HH011_unapprovedAcronymLowercased_YOLO() {
        let result = processor.process("YOLO approach", role: .leader)
        XCTAssertFalse(result.contains("YOLO"), "Unapproved acronym YOLO must not stay uppercase")
        XCTAssertTrue(result.lowercased().contains("yolo"), "Unapproved acronym should be lowercased")
    }

    func test_HH011_unapprovedAcronymLowercased_ASAP() {
        let result = processor.process("ASAP extraction", role: .leader)
        XCTAssertFalse(result.contains("ASAP"), "Unapproved acronym ASAP must not stay uppercase")
        XCTAssertTrue(result.lowercased().contains("asap"), "Unapproved acronym should be lowercased")
    }

    // ──────────────────────────────────────────────
    // MARK: HH-013 — Number-to-Word Conversion (1–9)
    // ──────────────────────────────────────────────

    func test_HH013_singleDigitToWord() {
        let result = processor.process("3 hostiles", role: .leader)
        XCTAssertTrue(result.lowercased().contains("three"), "Digit 3 should become 'three'")
        XCTAssertFalse(result.contains("3"), "Digit 3 should not remain as numeral")
    }

    func test_HH013_doubleDigitStaysNumeral() {
        let result = processor.process("15 meters", role: .leader)
        XCTAssertTrue(result.contains("15"), "Numbers >= 10 should stay as numerals")
    }

    func test_HH013_allSingleDigitsConverted() {
        for (digit, word) in [(1, "one"), (2, "two"), (3, "three"), (4, "four"),
                              (5, "five"), (6, "six"), (7, "seven"), (8, "eight"), (9, "nine")] {
            let result = processor.process("\(digit) targets", role: .leader)
            XCTAssertTrue(
                result.lowercased().contains(word),
                "Digit \(digit) should become '\(word)', got: \(result)"
            )
        }
    }

    // ──────────────────────────────────────────────
    // MARK: HH-014 — Grid Coordinate Formatting
    // ──────────────────────────────────────────────

    func test_HH014_gridCoordFormatted() {
        let result = processor.process("grid 12345678", role: .leader)
        // Grid coords should be broken into spoken digit groups
        XCTAssertTrue(result.lowercased().contains("grid"), "Grid keyword must be preserved")
        // The 8-digit grid should be split — not left as a raw number
        XCTAssertFalse(result.contains("12345678"), "Raw 8-digit grid should be split into spoken groups")
    }

    func test_HH014_gridCoordSixDigit() {
        let result = processor.process("grid 123456", role: .leader)
        XCTAssertFalse(result.contains("123456"), "Raw 6-digit grid should be split into spoken groups")
    }

    // ──────────────────────────────────────────────
    // MARK: HH-015 — Double Negative Simplification
    // ──────────────────────────────────────────────

    func test_HH015_notUnlikely() {
        let result = processor.process("not unlikely hostile", role: .leader)
        XCTAssertTrue(result.lowercased().contains("likely"), "'not unlikely' → 'likely'")
        XCTAssertFalse(result.lowercased().contains("not unlikely"), "Double negative should be simplified")
    }

    func test_HH015_notImpossible() {
        let result = processor.process("not impossible to breach", role: .leader)
        XCTAssertTrue(result.lowercased().contains("possible"), "'not impossible' → 'possible'")
        XCTAssertFalse(result.lowercased().contains("not impossible"), "Double negative should be simplified")
    }

    // ──────────────────────────────────────────────
    // MARK: HH-017 — Filler Stripping
    // ──────────────────────────────────────────────

    func test_HH017_rogerFillerStripped() {
        let result = processor.process("Roger, first floor clear", role: .leader)
        XCTAssertFalse(result.lowercased().contains("roger"), "'Roger' filler should be stripped")
        XCTAssertTrue(result.lowercased().contains("first floor clear"), "Tactical content preserved")
    }

    func test_HH017_copyThatFillerStripped() {
        let result = processor.process("Copy that, moving north", role: .leader)
        XCTAssertFalse(result.lowercased().contains("copy that"), "'Copy that' filler should be stripped")
        XCTAssertTrue(result.lowercased().contains("moving north"), "Tactical content preserved")
    }

    func test_HH017_standAloneFillerBecomesSilence() {
        let result = processor.process("I understand", role: .leader)
        XCTAssertEqual(result, "", "Standalone filler should produce empty string (silence)")
    }

    func test_HH017_understoodFillerBecomesSilence() {
        let result = processor.process("Understood", role: .leader)
        XCTAssertEqual(result, "", "Standalone 'Understood' should produce silence")
    }

    // ──────────────────────────────────────────────
    // MARK: HH-018 — Hedging Removal
    // ──────────────────────────────────────────────

    func test_HH018_iThinkRemoved() {
        let result = processor.process("I think there are three contacts", role: .leader)
        XCTAssertFalse(result.lowercased().contains("i think"), "'I think' hedging should be removed")
        XCTAssertTrue(result.lowercased().contains("three contacts") || result.lowercased().contains("contacts"),
                       "Tactical content preserved after hedging removal")
    }

    func test_HH018_probablyRemoved() {
        let result = processor.process("probably three hostiles north", role: .leader)
        XCTAssertFalse(result.lowercased().contains("probably"), "'probably' hedging should be removed")
    }

    func test_HH018_itSeemsRemoved() {
        let result = processor.process("it seems the building is clear", role: .leader)
        XCTAssertFalse(result.lowercased().contains("it seems"), "'it seems' hedging should be removed")
    }

    // ──────────────────────────────────────────────
    // MARK: HH-019 — Pleasantry Removal
    // ──────────────────────────────────────────────

    func test_HH019_thankYouRemoved() {
        let result = processor.process("Thank you, moving to extract", role: .leader)
        XCTAssertFalse(result.lowercased().contains("thank you"), "'Thank you' pleasantry should be removed")
        XCTAssertTrue(result.lowercased().contains("moving to extract"), "Tactical content preserved")
    }

    func test_HH019_pleaseRemoved() {
        let result = processor.process("Please move to extraction point", role: .leader)
        XCTAssertFalse(result.lowercased().contains("please"), "'Please' pleasantry should be removed")
    }

    func test_HH019_staySafeRemoved() {
        let result = processor.process("Fall back to rally point. Stay safe!", role: .leader)
        XCTAssertFalse(result.lowercased().contains("stay safe"), "'Stay safe' pleasantry should be removed")
    }

    // ──────────────────────────────────────────────
    // MARK: HH-020 — Self-Reference Removal
    // ──────────────────────────────────────────────

    func test_HH020_asYourAIRemoved() {
        let result = processor.process("As your AI, I detect three contacts", role: .leader)
        XCTAssertFalse(result.lowercased().contains("as your ai"), "'As your AI' self-reference should be removed")
        XCTAssertTrue(result.lowercased().contains("detect") || result.lowercased().contains("contacts"),
                       "Tactical content preserved after self-reference removal")
    }

    func test_HH020_asAnAIRemoved() {
        let result = processor.process("As an AI assistant, three contacts north", role: .leader)
        XCTAssertFalse(result.lowercased().contains("as an ai"), "'As an AI' self-reference should be removed")
    }

    // ──────────────────────────────────────────────
    // MARK: HH-024 — Profanity Filtering
    // ──────────────────────────────────────────────

    func test_HH024_profanityStripped() {
        let result = processor.process("damn it, contact north", role: .leader)
        XCTAssertFalse(result.lowercased().contains("damn"), "Profanity should be stripped from output")
        XCTAssertTrue(result.lowercased().contains("contact north"), "Tactical content preserved")
    }

    func test_HH024_profanityStrippedHell() {
        let result = processor.process("What the hell is that contact", role: .leader)
        XCTAssertFalse(result.lowercased().contains("hell"), "Mild profanity should be stripped")
    }

    // ──────────────────────────────────────────────
    // MARK: HH-028 — Single Letter → Phonetic Alphabet
    // ──────────────────────────────────────────────

    func test_HH028_singleLetterA_toAlpha() {
        let result = processor.process("Team A", role: .leader)
        XCTAssertTrue(result.contains("Alpha"), "Standalone 'A' should become 'Alpha'")
        XCTAssertFalse(
            result.components(separatedBy: " ").contains("A"),
            "Standalone letter 'A' should not remain"
        )
    }

    func test_HH028_singleLetterB_toBravo() {
        let result = processor.process("Point B", role: .leader)
        XCTAssertTrue(result.contains("Bravo"), "Standalone 'B' should become 'Bravo'")
    }

    func test_HH028_singleLetterC_toCharlie() {
        let result = processor.process("sector C clear", role: .leader)
        XCTAssertTrue(result.contains("Charlie"), "Standalone 'C' should become 'Charlie'")
    }

    func test_HH028_wordALPHANotConverted() {
        let result = processor.process("ALPHA team moving", role: .leader)
        // ALPHA is an approved military term / word, not a standalone single letter
        XCTAssertTrue(result.contains("ALPHA") || result.contains("Alpha") || result.contains("alpha"),
                       "Full word 'ALPHA' should not be converted to phonetic; it's already a word")
    }

    func test_HH028_letterInsideWordNotConverted() {
        let result = processor.process("BRAVO element advance", role: .leader)
        // The letters inside "BRAVO" should not each be converted
        XCTAssertTrue(result.lowercased().contains("bravo"), "Letters inside words must not be converted to phonetic")
    }

    // ──────────────────────────────────────────────
    // MARK: HH-029 — "nine" → "niner"
    // ──────────────────────────────────────────────

    func test_HH029_nineToNiner() {
        // Note: digit 9 first becomes "nine" via HH-013, then "nine" → "niner" via HH-029
        let result = processor.process("nine hostiles", role: .leader)
        XCTAssertTrue(result.lowercased().contains("niner"), "'nine' should become 'niner'")
        // Make sure it's "niner" not "nine " leftover
        XCTAssertFalse(
            result.lowercased().replacingOccurrences(of: "niner", with: "").contains("nine"),
            "No leftover 'nine' should remain after niner conversion"
        )
    }

    func test_HH029_digit9BecomesNiner() {
        let result = processor.process("9 hostiles", role: .leader)
        XCTAssertTrue(result.lowercased().contains("niner"),
                       "Digit 9 should first become 'nine' then 'niner'")
    }

    func test_HH029_nineteenStays() {
        let result = processor.process("nineteen meters", role: .leader)
        XCTAssertTrue(result.lowercased().contains("nineteen"), "'nineteen' must NOT become 'ninerteen'")
        XCTAssertFalse(result.lowercased().contains("ninerteen"),
                        "'nineteen' should not be mangled by niner replacement")
    }

    func test_HH029_ninetyStays() {
        let result = processor.process("ninety meters", role: .leader)
        XCTAssertTrue(result.lowercased().contains("ninety"), "'ninety' must NOT become 'ninerty'")
    }

    // ──────────────────────────────────────────────
    // MARK: Integration — Full Pipeline Tests
    // ──────────────────────────────────────────────

    func test_integration_realisticSLMOutput() {
        let input = "**Roger**, I think there are probably 3 hostiles 🔥 moving (quickly) north. Stay safe!"
        let result = processor.process(input, role: .leader)

        // No markdown
        XCTAssertFalse(result.contains("**"), "Markdown should be stripped")
        // No emoji
        XCTAssertFalse(result.contains("🔥"), "Emoji should be stripped")
        // No hedging
        XCTAssertFalse(result.lowercased().contains("i think"), "Hedging removed")
        XCTAssertFalse(result.lowercased().contains("probably"), "Hedging removed")
        // No filler
        XCTAssertFalse(result.lowercased().contains("roger"), "Filler removed")
        // No pleasantries
        XCTAssertFalse(result.lowercased().contains("stay safe"), "Pleasantry removed")
        // No parenthetical
        XCTAssertFalse(result.contains("("), "Parenthetical removed")
        XCTAssertFalse(result.lowercased().contains("quickly"), "Parenthetical content removed")
        // Number converted
        XCTAssertTrue(result.lowercased().contains("three"), "Digit 3 should become 'three'")
        // Word cap enforced
        let wordCount = result.split(separator: " ").count
        XCTAssertLessThanOrEqual(wordCount, 18, "Leader cap at 18 words")
        // Core tactical content preserved
        XCTAssertTrue(result.lowercased().contains("hostiles"), "Tactical content preserved")
        XCTAssertTrue(result.lowercased().contains("north"), "Direction preserved")
    }

    func test_integration_emptyInput() {
        let result = processor.process("", role: .leader)
        XCTAssertEqual(result, "", "Empty input must produce empty output")
    }

    func test_integration_whitespaceOnlyInput() {
        let result = processor.process("   \t\n  ", role: .leader)
        XCTAssertEqual(result, "", "Whitespace-only input must produce empty output")
    }

    func test_integration_allFillerInput() {
        let result = processor.process("Roger, copy that, understood", role: .leader)
        XCTAssertEqual(result, "", "All-filler input should produce empty output (silence)")
    }

    func test_integration_cleanTacticalPassthrough() {
        // A clean tactical message that requires minimal filtering
        // Note: "three" is already a word so HH-013 won't change it;
        // these are all clean tactical words
        let result = processor.process("two hostiles moving north", role: .leader)
        XCTAssertEqual(result, "two hostiles moving north",
                        "Clean tactical input should pass through with minimal changes")
    }

    func test_integration_leaderVsPeerWordCap() {
        let words = (1...25).map { "word\($0)" }
        let input = words.joined(separator: " ")

        let leaderResult = processor.process(input, role: .leader)
        let peerResult = processor.process(input, role: .peer)
        let summaryResult = processor.process(input, role: .summary)

        let leaderWords = leaderResult.split(separator: " ").count
        let peerWords = peerResult.split(separator: " ").count
        let summaryWords = summaryResult.split(separator: " ").count

        XCTAssertLessThanOrEqual(leaderWords, 18)
        XCTAssertLessThanOrEqual(peerWords, 12)
        XCTAssertLessThanOrEqual(summaryWords, 20)

        // Peer should be shorter than or equal to leader
        XCTAssertLessThanOrEqual(peerWords, leaderWords,
                                  "Peer cap (12) is stricter than leader cap (18)")
    }

    func test_integration_allRolesProduceDeterministicOutput() {
        let input = "SITREP two contacts east"
        let result1 = processor.process(input, role: .leader)
        let result2 = processor.process(input, role: .leader)
        XCTAssertEqual(result1, result2, "Same input and role must produce identical output (deterministic)")
    }

    func test_integration_multipleFiltersChained() {
        // Combines: emoji + markdown + hedging + number conversion + phonetic
        let input = "## I think Team A has 3 contacts 🔥"
        let result = processor.process(input, role: .peer)

        XCTAssertFalse(result.contains("#"))
        XCTAssertFalse(result.lowercased().contains("i think"))
        XCTAssertFalse(result.contains("🔥"))
        XCTAssertTrue(result.lowercased().contains("three") || !result.contains("3"),
                       "Digit 3 should be converted to 'three'")
        XCTAssertTrue(result.contains("Alpha"),
                       "Standalone 'A' should become 'Alpha'")
        let wordCount = result.split(separator: " ").count
        XCTAssertLessThanOrEqual(wordCount, 12, "Peer word cap enforced")
    }

    // ──────────────────────────────────────────────
    // MARK: Edge Cases
    // ──────────────────────────────────────────────

    func test_edge_singleWord() {
        let result = processor.process("contact", role: .leader)
        XCTAssertEqual(result, "contact", "Single clean word should pass through")
    }

    func test_edge_onlyEmoji() {
        let result = processor.process("🔥🔥🔥", role: .leader)
        XCTAssertEqual(result, "", "Input that is only emoji should produce empty output")
    }

    func test_edge_onlyMarkdown() {
        let result = processor.process("## **", role: .leader)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespaces), "",
                        "Input that is only markdown syntax should produce empty or near-empty output")
    }

    func test_edge_veryLongInput() {
        let words = (1...100).map { "word\($0)" }
        let input = words.joined(separator: " ")
        let result = processor.process(input, role: .peer)
        let outputWordCount = result.split(separator: " ").count
        XCTAssertLessThanOrEqual(outputWordCount, 12,
                                  "Even very long input must respect peer word cap")
    }

    func test_edge_mixedCaseApprovedAcronym() {
        // Approved acronyms are typically all-caps; mixed case should be handled
        let result = processor.process("Sitrep follows", role: .leader)
        // Implementation may uppercase or preserve — just check it doesn't crash
        XCTAssertFalse(result.isEmpty, "Mixed case input should produce non-empty output")
    }

    func test_edge_consecutiveSpaces() {
        let result = processor.process("contact   north", role: .leader)
        XCTAssertFalse(result.contains("  "), "Consecutive spaces should be normalized to single space")
    }

    func test_edge_trailingLeadingWhitespace() {
        let result = processor.process("  contact north  ", role: .leader)
        XCTAssertEqual(result, result.trimmingCharacters(in: .whitespaces),
                        "Output should have no leading/trailing whitespace")
    }
}
