#!/usr/bin/env python3
"""
TacNet TTS PostProcessor — Reference Implementation

Every filter from TTS_HARD_HOOKS.md (HH-001 through HH-029) is implemented as
a pure Python function. The `run_chain(text, role)` function applies all filters
in the specified order.

This is the reference implementation for testing/validation before the Swift port.

Architecture reminder: The SLM is a RELAY AND COMPACTOR. It listens to operator
voice input, compresses/summarizes, and forwards via TTS to earpieces. It never
"replies" conversationally. These filters clean the SLM output before TTS synthesis.
"""

from __future__ import annotations

import re
from typing import Optional

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

APPROVED_ACRONYMS: set[str] = {
    "EKIA", "SITREP", "SALUTE", "CASEVAC", "MEDEVAC", "LACE", "ACE", "BDA",
    "CCIR", "PIR", "EEI", "PACE", "ROE", "METT-TC", "SOP", "TTP", "CAS",
    "WIA", "PC", "HVT", "LZ", "PZ", "ORP", "SBF", "TRP", "PL", "LD", "SP",
    "RP", "NVG", "GPNVG", "BLE", "UNK", "RTN",
    # Tactical terms added to match Swift implementation
    "CONTACT", "SPOTREP", "KIA", "MIA", "POW", "FRAGO", "OPORD", "WARNO",
    "RPG", "IED", "TIC", "QRF", "TOC", "FLOT", "LOA", "EOF", "NLT", "IOT",
    "ISO", "IVO", "DMR", "SAW",
}

# Classification markers and structural keywords that look like acronyms but
# must pass through HH-011 unmodified. They are preserved/enforced by HH-023.
ACRONYM_PASSTHROUGH: set[str] = {
    "SECRET", "CONFIDENTIAL", "UNCLASSIFIED", "FOUO", "NOFORN", "AI",
    "TOP",  # part of "TOP SECRET"
}

NATO_PHONETIC: dict[str, str] = {
    "A": "Alpha", "B": "Bravo", "C": "Charlie", "D": "Delta", "E": "Echo",
    "F": "Foxtrot", "G": "Golf", "H": "Hotel", "I": "India", "J": "Juliet",
    "K": "Kilo", "L": "Lima", "M": "Mike", "N": "November", "O": "Oscar",
    "P": "Papa", "Q": "Quebec", "R": "Romeo", "S": "Sierra", "T": "Tango",
    "U": "Uniform", "V": "Victor", "W": "Whiskey", "X": "X-ray",
    "Y": "Yankee", "Z": "Zulu",
}

DIGIT_WORDS: dict[str, str] = {
    "1": "one", "2": "two", "3": "three", "4": "four", "5": "five",
    "6": "six", "7": "seven", "8": "eight", "9": "niner",
}

DIGIT_SPOKEN: dict[str, str] = {
    "0": "zero", "1": "one", "2": "two", "3": "three", "4": "four",
    "5": "five", "6": "six", "7": "seven", "8": "eight", "9": "niner",
}

FILLER_PHRASES: list[str] = [
    "I understand", "Copy that", "Roger let me think", "Understood",
    "Acknowledged", "Let me check", "Sure", "Okay so", "Alright", "OK",
    "Well", "So", "Basically", "Actually", "Right so", "Yeah", "Yes sir",
    "Got it", "Affirmative", "Roger", "Copy",
]

HEDGE_PHRASES: list[str] = [
    "it seems like", "it seems", "probably", "I think", "might be",
    "perhaps", "possibly", "likely", "arguably", "it appears",
    "it looks like", "it could be", "there may be", "I believe",
    "I suspect", "it's possible", "potentially", "presumably",
    "supposedly", "apparently",
]

PLEASANTRY_PHRASES: list[str] = [
    "please", "thank you", "thanks", "good luck", "be safe", "stay safe",
    "take care", "you're welcome", "no problem", "my pleasure",
    "Godspeed", "God speed",
]

SELF_REF_PHRASES: list[str] = [
    "As your AI", "I'm here to help", "Let me help", "I can assist",
    "My purpose is", "As an AI", "I'm designed to", "My role is",
    "I'm programmed to", "Allow me to", "I'd be happy to", "I'm able to",
]

DOUBLE_NEGATIVE_MAP: dict[str, str] = {
    "not unlikely": "likely",
    "not impossible": "possible",
    "not without risk": "risky",
    "not without": "with",
    "not unable": "able",
    "not uncertain": "certain",
    "not uncommon": "common",
    "not unreasonable": "reasonable",
    "not insignificant": "significant",
    "not unimportant": "important",
    "never not": "always",
}

PROFANITY_BLOCKLIST: list[str] = [
    "hell", "damn", "shit", "fuck", "ass", "bastard", "crap",
    "dammit", "goddamn", "bullshit", "freakin", "fking",
]

# Common first names blocklist (abbreviated — extend for production)
COMMON_FIRST_NAMES: set[str] = {
    "james", "john", "robert", "michael", "david", "william", "richard",
    "joseph", "thomas", "charles", "chris", "daniel", "matthew", "anthony",
    "mark", "donald", "steven", "paul", "andrew", "joshua", "kenneth",
    "kevin", "brian", "george", "timothy", "ronald", "edward", "jason",
    "jeff", "ryan", "jacob", "gary", "nicholas", "eric", "jonathan",
    "stephen", "larry", "justin", "scott", "brandon", "benjamin", "samuel",
    "frank", "alex", "patrick", "jack", "dennis", "jerry", "tyler",
    "mary", "patricia", "jennifer", "linda", "sarah", "jessica", "emily",
    "ashley", "amanda", "michelle", "nicole", "lisa", "laura", "anna",
    "mike", "steve", "tom", "bob", "bill", "joe", "jim", "dan",
    "dave", "pete", "tony", "sam", "ben", "matt", "nick", "jake",
    "chad", "kyle", "sean", "troy", "brad", "derek", "travis", "cody",
    "smitty", "johnny", "bobby", "billy", "tommy", "jimmy", "danny",
}

CLASSIFICATION_MARKERS: list[str] = [
    "TOP SECRET", "SECRET", "CONFIDENTIAL", "UNCLASSIFIED", "FOUO", "NOFORN",
]

# Warnings accumulator (module-level for simplicity; reset per run_chain call)
_warnings: list[str] = []


def _warn(hook_id: str, message: str) -> None:
    """Append an advisory warning."""
    _warnings.append(f"{hook_id}: {message}")


def _clean_spaces(text: str) -> str:
    """Collapse multiple spaces, strip leading/trailing whitespace and punctuation artifacts."""
    text = re.sub(r"  +", " ", text)
    text = re.sub(r"\s+([,;.!?])", r"\1", text)
    text = re.sub(r"^[,;.\s]+", "", text)
    text = re.sub(r"[,;\s]+$", "", text)
    return text.strip()


# ===========================================================================
# CATEGORY 1: FORMATTING (HH-001 → HH-006)
# ===========================================================================


def hh_001_strip_emojis(text: str) -> str:
    """HH-001 — Strip all Unicode emoji codepoints.

    Test:
        >>> hh_001_strip_emojis("Foyer clear 👍, 1 EKIA 🔥")
        'Foyer clear , 1 EKIA'
    """
    # Broad emoji pattern covering common Unicode emoji ranges
    emoji_pattern = re.compile(
        "["
        "\U0001F600-\U0001F64F"  # emoticons
        "\U0001F300-\U0001F5FF"  # symbols & pictographs
        "\U0001F680-\U0001F6FF"  # transport & map
        "\U0001F1E0-\U0001F1FF"  # flags
        "\U0001F900-\U0001F9FF"  # supplemental symbols
        "\U0001FA00-\U0001FA6F"  # chess symbols
        "\U0001FA70-\U0001FAFF"  # symbols extended-A
        "\U00002702-\U000027B0"  # dingbats
        "\U0000FE00-\U0000FE0F"  # variation selectors
        "\U00002600-\U000026FF"  # misc symbols
        "\U0000200D"             # zero-width joiner
        "\U00002B50"             # star
        "\U0000231A-\U0000231B"  # watch/hourglass
        "\U000023E9-\U000023F3"  # media controls
        "\U000023F8-\U000023FA"  # media controls
        "\U000025AA-\U000025AB"  # squares
        "\U000025B6"             # play
        "\U000025C0"             # reverse
        "\U000025FB-\U000025FE"  # squares
        "\U00002934-\U00002935"  # arrows
        "\U00002B05-\U00002B07"  # arrows
        "\U00002B1B-\U00002B1C"  # squares
        "\U00003030"             # wavy dash
        "\U0000303D"             # part alternation mark
        "\U00003297"             # circled ideograph congratulation
        "\U00003299"             # circled ideograph secret
        "]+",
        flags=re.UNICODE,
    )
    return emoji_pattern.sub("", text)


def hh_002_strip_markdown(text: str) -> str:
    """HH-002 — Strip markdown formatting syntax, keep enclosed text.

    Test:
        >>> hh_002_strip_markdown("**Contact** north, _urgent_")
        'Contact north, urgent'
    """
    # Code blocks (triple backtick with optional language)
    text = re.sub(r"```[\s\S]*?```", "", text)
    # Inline code
    text = re.sub(r"`([^`]*)`", r"\1", text)
    # Images (strip entirely)
    text = re.sub(r"!\[[^\]]*\]\([^)]*\)", "", text)
    # Links (keep link text)
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)
    # Bold/italic combinations (***text*** or ___text___)
    text = re.sub(r"\*{3}(.*?)\*{3}", r"\1", text)
    text = re.sub(r"_{3}(.*?)_{3}", r"\1", text)
    # Bold (**text** or __text__)
    text = re.sub(r"\*{2}(.*?)\*{2}", r"\1", text)
    text = re.sub(r"_{2}(.*?)_{2}", r"\1", text)
    # Italic (*text* or _text_)
    text = re.sub(r"\*([^*]+)\*", r"\1", text)
    text = re.sub(r"\b_([^_]+)_\b", r"\1", text)
    # Strikethrough
    text = re.sub(r"~~(.*?)~~", r"\1", text)
    # Headings
    text = re.sub(r"^#{1,6}\s*", "", text, flags=re.MULTILINE)
    # Horizontal rules
    text = re.sub(r"^[-*_]{3,}\s*$", "", text, flags=re.MULTILINE)
    return text


def hh_003_flatten_lists(text: str) -> str:
    """HH-003 — Flatten bullet/numbered lists into semicolon-separated string.

    Test:
        >>> hh_003_flatten_lists("- Foyer clear\\n- Kitchen clear\\n- 1 EKIA")
        'Foyer clear; Kitchen clear; 1 EKIA'
    """
    lines = text.split("\n")
    list_items: list[str] = []
    non_list_parts: list[str] = []
    is_list_block = False

    for line in lines:
        stripped = line.strip()
        # Bullet: -, *, +
        bullet_match = re.match(r"^\s*[-*+]\s+(.*)", stripped)
        # Numbered: 1. or 1)
        number_match = re.match(r"^\s*\d+[.)]\s+(.*)", stripped)

        if bullet_match:
            is_list_block = True
            list_items.append(bullet_match.group(1).strip())
        elif number_match:
            is_list_block = True
            list_items.append(number_match.group(1).strip())
        else:
            if is_list_block and list_items:
                non_list_parts.append("; ".join(list_items))
                list_items = []
                is_list_block = False
            if stripped:
                non_list_parts.append(stripped)

    if list_items:
        non_list_parts.append("; ".join(list_items))

    return " ".join(non_list_parts)


def hh_004_strip_parentheticals(text: str) -> str:
    """HH-004 — Remove parenthesized text entirely.

    Test:
        >>> hh_004_strip_parentheticals("1 EKIA (confirmed by thermal)")
        '1 EKIA'
    """
    text = re.sub(r"\s*\([^)]*\)", "", text)
    return text


def hh_005_strip_quotes(text: str) -> str:
    r"""HH-005 — Strip all quotation marks (straight and curly).

    Test:
        >>> hh_005_strip_quotes('SL said "push north"')
        'SL said push north'
    """
    text = re.sub(r'["\u201C\u201D\u2018\u2019\u0027\u0060]', "", text)
    return text


def hh_006_strip_special_chars(text: str) -> str:
    """HH-006 — Spell out or strip special characters (@, &, %, +, =, <, >).

    Test:
        >>> hh_006_strip_special_chars("Ammo at 50% & falling")
        'Ammo at 50 percent and falling'
    """
    text = text.replace("&", " and ")
    text = text.replace("%", " percent")
    text = text.replace("+", " plus ")
    text = text.replace("@", " at ")
    text = text.replace("=", " ")
    text = text.replace("<", "")
    text = text.replace(">", "")
    # Collapse any resulting double spaces
    text = re.sub(r"  +", " ", text)
    return text


# ===========================================================================
# CATEGORY 2: LENGTH (HH-007 → HH-010)
# ===========================================================================


def hh_007_leader_word_cap(text: str, role: str) -> str:
    """HH-007 — Leader earpiece: 18-word hard cap.

    Test (role='leader'):
        >>> hh_007_leader_word_cap(
        ...     "First floor 90 percent clear one EKIA Team two in contact "
        ...     "upstairs request permission to reinforce from ground floor now",
        ...     "leader")
        'First floor 90 percent clear one EKIA Team two in contact upstairs request permission to reinforce from ground'
    """
    if role != "leader":
        return text
    words = text.split()
    if len(words) > 18:
        return " ".join(words[:18])
    return text


def hh_008_peer_word_cap(text: str, role: str) -> str:
    """HH-008 — Peer routing: 12-word hard cap.

    Test (role='peer'):
        >>> hh_008_peer_word_cap(
        ...     "Push upstairs now reinforce Team one hold landing zone "
        ...     "until further orders come through",
        ...     "peer")
        'Push upstairs now reinforce Team one hold landing zone until further orders'
    """
    if role != "peer":
        return text
    words = text.split()
    if len(words) > 12:
        return " ".join(words[:12])
    return text


def hh_009_sitrep_cap(text: str) -> str:
    """HH-009 — SITREP relay: one sentence, max 20 words.

    Test:
        >>> hh_009_sitrep_cap(
        ...     "OP1 SITREP: First floor clear one EKIA no friendly casualties "
        ...     "ammo green moving to second floor stairwell west side of building now")
        'OP1 SITREP: First floor clear one EKIA no friendly casualties ammo green moving to second floor stairwell west side of building'
    """
    if not re.search(r"(?i)\bSITREP\b", text):
        return text
    words = text.split()
    if len(words) > 20:
        return " ".join(words[:20])
    return text


def hh_010_overflow_truncation(text: str, role: str) -> str:
    """HH-010 — Final overflow safety net. Truncate to role-appropriate cap.

    Test (role='leader', 25 words):
        Any string > 18 words → first 18 words.
    """
    max_words = 18 if role == "leader" else 12
    # SITREP override
    if re.search(r"(?i)\bSITREP\b", text):
        max_words = max(max_words, 20)
    words = text.split()
    if len(words) > max_words:
        return " ".join(words[:max_words])
    return text


# ===========================================================================
# CATEGORY 3: SPOKEN CLARITY (HH-011 → HH-016)
# ===========================================================================


def hh_011_acronym_gating(text: str) -> str:
    """HH-011 — Flag/replace unapproved acronyms.

    Only acronyms in APPROVED_ACRONYMS pass. Others are replaced with UNK.

    Test:
        >>> hh_011_acronym_gating("EKIA confirmed, JTAC requesting CAS")
        'EKIA confirmed, UNK requesting CAS'
    """
    def _replace_acronym(match: re.Match) -> str:
        acr = match.group(0)
        if acr in APPROVED_ACRONYMS or acr in ACRONYM_PASSTHROUGH:
            return acr
        _warn("HH-011", f"Unapproved acronym '{acr}' replaced with UNK")
        return "UNK"

    return re.sub(r"\b([A-Z]{2,}(?:-[A-Z]{2,})?)\b", _replace_acronym, text)


def hh_012_homophone_check(text: str) -> str:
    """HH-012 — Flag homophone-ambiguous words. Advisory only — does not alter text.

    Test:
        >>> hh_012_homophone_check("Move right")
        'Move right'
    """
    watchlist = ["right", "left", "fire", "round", "clear", "cover",
                 "check", "hold", "mark", "point", "base", "contact"]
    for word in watchlist:
        if re.search(rf"(?i)\b{word}\b", text):
            # Check if "right"/"left" is followed by a disambiguator
            if word in ("right", "left"):
                if not re.search(
                    rf"(?i)\b{word}\s+(side|flank|turn|hand|wall|door|corner)\b",
                    text,
                ):
                    _warn(
                        "HH-012",
                        f"'{word}' may be ambiguous — consider "
                        f"'{word} side' or cardinal direction",
                    )
    return text


def hh_013_number_normalization(text: str) -> str:
    """HH-013 — Numbers 1-9 as words, 10+ as digits. 9 becomes 'niner'.

    Test:
        >>> hh_013_number_normalization("3 hostiles, 15 meters north")
        'three hostiles, 15 meters north'
    """
    def _replace_digit(match: re.Match) -> str:
        return DIGIT_WORDS[match.group(1)]

    return re.sub(r"\b([1-9])\b", _replace_digit, text)


def hh_014_grid_formatting(text: str) -> str:
    """HH-014 — Grid coordinates spoken in digit groups.

    A 6-digit grid is split into two groups of 3; 8-digit into two groups of 4.
    Each digit is spoken using DIGIT_SPOKEN (which uses 'niner' for 9).

    Test:
        >>> hh_014_grid_formatting("grid 972416")
        'grid niner-seven-two, four-one-six'
    """
    def _expand_grid(match: re.Match) -> str:
        digits = match.group(1)
        half = len(digits) // 2
        first_half = "-".join(DIGIT_SPOKEN[d] for d in digits[:half])
        second_half = "-".join(DIGIT_SPOKEN[d] for d in digits[half:])
        return f"grid {first_half}, {second_half}"

    return re.sub(r"(?i)\bgrid\s*(\d{6,8})\b", _expand_grid, text)


def hh_015_no_double_negatives(text: str) -> str:
    """HH-015 — Rewrite double negatives to affirmative.

    Test:
        >>> hh_015_no_double_negatives("Area is not unlikely hostile")
        'Area is likely hostile'
    """
    lower = text
    for pattern, replacement in DOUBLE_NEGATIVE_MAP.items():
        # Case-insensitive replacement preserving surrounding text
        lower = re.sub(re.escape(pattern), replacement, lower, flags=re.IGNORECASE)

    # Catch remaining "not un-" / "not im-" / "not in-" patterns
    def _rewrite_not_un(match: re.Match) -> str:
        prefix = match.group(1)  # un, im, in
        root = match.group(2)
        return root

    lower = re.sub(
        r"\bnot\s+(un|im|in)(\w+)\b", _rewrite_not_un, lower, flags=re.IGNORECASE
    )
    return lower


def hh_016_cardinal_directions(text: str) -> str:
    """HH-016 — Flag relative directions. Advisory only.

    Test:
        >>> hh_016_cardinal_directions("Hostiles on left side")
        'Hostiles on left side'
    """
    relative_patterns = [
        "left side", "right side", "front side", "back side",
        "left flank", "right flank",
    ]
    for pat in relative_patterns:
        if re.search(rf"(?i)\b{re.escape(pat)}\b", text):
            _warn(
                "HH-016",
                f"'{pat}' — prefer cardinal direction if known",
            )
    return text


# ===========================================================================
# CATEGORY 4: NOISE DISCIPLINE (HH-017 → HH-020)
# ===========================================================================


def hh_017_strip_filler(text: str) -> str:
    """HH-017 — Strip filler phrases.

    Test:
        >>> hh_017_strip_filler("Copy that, moving to second floor")
        'moving to second floor'
    """
    # Leading filler (most common case)
    for filler in sorted(FILLER_PHRASES, key=len, reverse=True):
        pattern = rf"(?i)^{re.escape(filler)}[,.:;!\s]*"
        text = re.sub(pattern, "", text)

    # Mid-sentence filler
    for filler in sorted(FILLER_PHRASES, key=len, reverse=True):
        pattern = rf"(?i),?\s*{re.escape(filler)}[,.:;!\s]*"
        text = re.sub(pattern, " ", text)

    return text.strip()


def hh_018_strip_hedging(text: str) -> str:
    """HH-018 — Strip hedging language.

    Test:
        >>> hh_018_strip_hedging("It seems like there are 3 hostiles north")
        'there are 3 hostiles north'
    """
    for hedge in sorted(HEDGE_PHRASES, key=len, reverse=True):
        pattern = rf"(?i)\b{re.escape(hedge)}\b[,\s]*"
        text = re.sub(pattern, "", text)

    text = text.strip()
    # If entire output was hedging, return UNK
    if not text:
        return "UNK"
    return text


def hh_019_strip_pleasantries(text: str) -> str:
    """HH-019 — Strip pleasantries.

    Test:
        >>> hh_019_strip_pleasantries("Please move to second floor, stay safe")
        'move to second floor'
    """
    for phrase in sorted(PLEASANTRY_PHRASES, key=len, reverse=True):
        pattern = rf"(?i)\b{re.escape(phrase)}\b[,.\s]*"
        text = re.sub(pattern, "", text)
    return text.strip()


def hh_020_strip_self_reference(text: str) -> str:
    """HH-020 — Strip self-referential AI language.

    Test:
        >>> hh_020_strip_self_reference("As your AI, the foyer has 1 EKIA")
        'the foyer has 1 EKIA'
    """
    for phrase in sorted(SELF_REF_PHRASES, key=len, reverse=True):
        pattern = rf"(?i){re.escape(phrase)}[,.:;!\s]*"
        text = re.sub(pattern, "", text)

    text = text.strip()
    if not text:
        return ""  # Silence — entire output was self-referential
    return text


# ===========================================================================
# CATEGORY 5: SAFETY / CONTENT (HH-021 → HH-024)
# ===========================================================================


def hh_021_fabrication_detection(
    text: str,
    input_context: Optional[str] = None,
    raw_output_grids: Optional[set[str]] = None,
) -> str:
    """HH-021 — Flag/replace suspected fabricated data.

    Cross-references grid coordinates in output against input context.
    If a grid appears in output but not in input, replace with UNK.
    Accepts raw_output_grids (pre-HH-014 digit grids) so it can detect
    fabrications even after grid formatting has expanded digits to words.

    Test:
        >>> hh_021_fabrication_detection("Hostiles at grid 123456", "Report hostiles north")
        'Hostiles at grid UNK'
    """
    if input_context is None:
        return text

    input_grids = set(
        re.findall(r"(?i)\bgrid\s*(\d{6,8})\b", input_context)
    )

    # Check raw digit grids (still present if HH-014 hasn't run, or passed
    # via raw_output_grids from the chain runner)
    output_digit_grids = set(
        re.findall(r"(?i)\bgrid\s+(\d{6,8})\b", text)
    )

    # Check for fabricated digit grids still in raw form
    for grid in output_digit_grids:
        if grid not in input_grids:
            _warn("HH-021", f"Fabricated grid '{grid}' replaced with UNK")
            text = re.sub(
                rf"(?i)\bgrid\s+{re.escape(grid)}\b",
                "grid UNK",
                text,
            )

    # Check for fabricated grids that were already expanded by HH-014.
    # raw_output_grids contains the original digit strings extracted
    # before formatting.
    if raw_output_grids:
        fabricated = raw_output_grids - input_grids
        for grid in fabricated:
            half = len(grid) // 2
            first_half = "-".join(DIGIT_SPOKEN[d] for d in grid[:half])
            second_half = "-".join(DIGIT_SPOKEN[d] for d in grid[half:])
            expanded = f"grid {first_half}, {second_half}"
            if expanded in text:
                _warn(
                    "HH-021",
                    f"Fabricated grid '{grid}' (expanded) replaced with UNK",
                )
                text = text.replace(expanded, "grid UNK")

    return text


def hh_022_unverified_counts(text: str, strict: bool = False) -> str:
    """HH-022 — Flag bare numbers without confirmed/estimated qualifier.

    Test (strict=True):
        >>> hh_022_unverified_counts("3 hostiles north", strict=True)
        'estimated 3 hostiles north'
    """
    count_pattern = re.compile(
        r"(?<!\w)(\d+)\s+"
        r"(hostiles?|EKIA|WIA|casualties?|enem(?:y|ies)|tangos?|contacts?)\b",
        re.IGNORECASE,
    )
    qualifier_pattern = re.compile(
        r"(?i)\b(confirmed|estimated|approx|suspected|reported)\b"
    )

    for match in count_pattern.finditer(text):
        start = max(0, match.start() - 40)
        preceding = text[start:match.start()]
        if not qualifier_pattern.search(preceding):
            if strict:
                text = (
                    text[:match.start()]
                    + "estimated "
                    + text[match.start():]
                )
                return text  # Re-run would be needed for multiple; keep simple
            else:
                _warn(
                    "HH-022",
                    f"Unqualified count '{match.group(0)}' — "
                    f"add 'confirmed' or 'estimated'",
                )
    return text


def hh_023_classification_preservation(
    text: str, input_context: Optional[str] = None
) -> str:
    """HH-023 — Preserve classification markers from input in output.

    Test:
        >>> hh_023_classification_preservation(
        ...     "grid niner-seven-two, four-one-six is HVT location",
        ...     "SECRET: grid 972416 is HVT location")
        'SECRET: grid niner-seven-two, four-one-six is HVT location'
    """
    if input_context is None:
        return text

    for marker in CLASSIFICATION_MARKERS:
        # Check longer markers first (TOP SECRET before SECRET)
        if re.search(rf"\b{re.escape(marker)}\b", input_context):
            if not re.search(rf"\b{re.escape(marker)}\b", text):
                _warn("HH-023", f"Classification marker '{marker}' restored")
                text = f"{marker}: {text}"
    return text


def hh_024_profanity_filter(text: str) -> str:
    """HH-024 — Strip profanity from output.

    Test:
        >>> hh_024_profanity_filter("Get the hell out of there")
        'Get the out of there'
    """
    for word in PROFANITY_BLOCKLIST:
        text = re.sub(rf"(?i)\b{re.escape(word)}\b", "", text)
    return text


# ===========================================================================
# CATEGORY 6: TEMPORAL DISCIPLINE (HH-025 → HH-026)
# ===========================================================================


def hh_025_relative_time(text: str) -> str:
    """HH-025 — Flag absolute time patterns. Advisory only.

    Test:
        >>> hh_025_relative_time("Contact reported at 14:32")
        'Contact reported at 14:32'
    """
    # HH:MM or HH:MM:SS
    for match in re.finditer(r"\b\d{1,2}:\d{2}(?::\d{2})?\b", text):
        _warn(
            "HH-025",
            f"Absolute time '{match.group()}' — prefer relative "
            f"('X mikes ago')",
        )
    # Military time like 1432 or 1432Z
    for match in re.finditer(r"\b(\d{4})[hHzZ]?\b", text):
        val = int(match.group(1))
        if 0 <= val <= 2359:
            _warn(
                "HH-025",
                f"Possible military time '{match.group()}' — prefer relative",
            )
    return text


def hh_026_present_tense_urgency(text: str) -> str:
    """HH-026 — Flag present-tense without urgency markers. Advisory only.

    Test:
        >>> hh_026_present_tense_urgency("Team 2 is taking fire")
        'Team 2 is taking fire'
    """
    urgency_markers = re.compile(r"(?i)\b(NOW|current|currently|just now|seconds? ago|mikes? ago)\b")
    present_verbs = re.compile(
        r"(?i)\b(is|are)\s+(moving|engaging|taking fire|pushing|advancing|retreating|"
        r"holding|breaching|clearing|pulling back|falling back|under fire|pinned)\b"
    )

    if present_verbs.search(text) and not urgency_markers.search(text):
        verb_match = present_verbs.search(text)
        _warn(
            "HH-026",
            f"Present-tense '{verb_match.group()}' — "
            f"consider adding 'NOW' or 'current'",
        )
    return text


# ===========================================================================
# CATEGORY 7: PHONETIC SAFETY (HH-027 → HH-029)
# ===========================================================================


def hh_027_callsign_over_names(text: str, strict: bool = False) -> str:
    """HH-027 — Flag real names, prefer callsigns. Advisory unless strict.

    Test (strict=True):
        >>> hh_027_callsign_over_names("Mike is hit, need CASEVAC", strict=True)
        'CALLSIGN is hit, need CASEVAC'
    """
    for name in COMMON_FIRST_NAMES:
        # Case-insensitive but match capitalized form in text
        pattern = rf"\b({re.escape(name)})\b"
        matches = re.finditer(pattern, text, re.IGNORECASE)
        for match in matches:
            if strict:
                text = text[:match.start()] + "CALLSIGN" + text[match.end():]
                return text  # Return after first replacement to avoid index shift
            else:
                _warn(
                    "HH-027",
                    f"Possible real name '{match.group()}' — use callsign",
                )
    return text


def hh_028_phonetic_alphabet(text: str) -> str:
    """HH-028 — Single standalone letters → NATO phonetic alphabet.

    Does NOT expand letters inside known acronyms (those are separate tokens).

    Test:
        >>> hh_028_phonetic_alphabet("Team A push to point B")
        'Team Alpha push to point Bravo'
    """
    def _replace_letter(match: re.Match) -> str:
        letter = match.group(1).upper()
        return NATO_PHONETIC.get(letter, letter)

    # Match a single uppercase letter that is NOT adjacent to other uppercase letters
    # (to avoid breaking acronyms that somehow survived HH-011)
    return re.sub(
        r"(?<![A-Z])(?<![A-Za-z])([A-Z])(?![A-Z])(?![a-z])\b",
        _replace_letter,
        text,
    )


def hh_029_niner(text: str) -> str:
    """HH-029 — 'nine' → 'niner' (military radio convention).

    Test:
        >>> hh_029_niner("nine hostiles at the north gate")
        'niner hostiles at the north gate'
    """
    return re.sub(r"(?i)\bnine\b", "niner", text)


# ===========================================================================
# CHAIN RUNNER
# ===========================================================================


def run_chain(
    text: str,
    role: str = "leader",
    input_context: Optional[str] = None,
    strict: bool = False,
) -> tuple[Optional[str], list[str]]:
    """Apply all 29 PostProcessor filters in spec order.

    Args:
        text: Raw SLM output string.
        role: "leader" (18-word cap) or "peer" (12-word cap).
        input_context: Original operator voice input (for fabrication/classification
                       cross-referencing in HH-021 and HH-023).
        strict: If True, advisory filters (HH-022, HH-027) auto-correct instead
                of just warning.

    Returns:
        Tuple of (processed_text_or_None, warnings_list).
        None means silence — emit nothing to TTS.

    Filter chain order:
        1. FORMATTING   (HH-001 → HH-006)
        2. LENGTH       (HH-007 → HH-010)
        3. CLARITY      (HH-011 → HH-016)
        4. NOISE        (HH-017 → HH-020)
        5. SAFETY       (HH-021 → HH-024)
        6. TEMPORAL     (HH-025 → HH-026)
        7. PHONETIC     (HH-027 → HH-029)

    Test:
        >>> result, warnings = run_chain(
        ...     "Copy that, **3 hostiles** at grid 972416 👍",
        ...     role="leader")
        >>> result
        'three hostiles at grid niner-seven-two, four-one-six'
    """
    global _warnings
    _warnings = []

    # Early return for empty/whitespace-only input
    if not text or not text.strip():
        return "", []

    # --- CATEGORY 1: FORMATTING ---
    text = hh_001_strip_emojis(text)
    text = hh_002_strip_markdown(text)
    text = hh_003_flatten_lists(text)
    text = hh_004_strip_parentheticals(text)
    text = hh_005_strip_quotes(text)
    text = hh_006_strip_special_chars(text)
    text = _clean_spaces(text)

    # --- CATEGORY 2: LENGTH ---
    text = hh_007_leader_word_cap(text, role)
    text = hh_008_peer_word_cap(text, role)
    text = hh_009_sitrep_cap(text)
    text = hh_010_overflow_truncation(text, role)

    # --- CATEGORY 3: SPOKEN CLARITY ---
    text = hh_011_acronym_gating(text)
    text = hh_012_homophone_check(text)
    text = hh_013_number_normalization(text)
    # Snapshot raw digit grids BEFORE HH-014 expands them (for HH-021
    # fabrication cross-reference after formatting).
    raw_output_grids = set(re.findall(r"(?i)\bgrid\s*(\d{6,8})\b", text))
    text = hh_014_grid_formatting(text)
    text = hh_015_no_double_negatives(text)
    text = hh_016_cardinal_directions(text)

    # --- CATEGORY 4: NOISE DISCIPLINE ---
    text = hh_017_strip_filler(text)
    text = hh_018_strip_hedging(text)
    text = hh_019_strip_pleasantries(text)
    text = hh_020_strip_self_reference(text)
    text = _clean_spaces(text)

    # --- CATEGORY 5: SAFETY ---
    text = hh_021_fabrication_detection(text, input_context, raw_output_grids)
    text = hh_022_unverified_counts(text, strict=strict)
    text = hh_023_classification_preservation(text, input_context)
    text = hh_024_profanity_filter(text)
    text = _clean_spaces(text)

    # --- CATEGORY 6: TEMPORAL ---
    text = hh_025_relative_time(text)
    text = hh_026_present_tense_urgency(text)

    # --- CATEGORY 7: PHONETIC ---
    text = hh_027_callsign_over_names(text, strict=strict)
    text = hh_028_phonetic_alphabet(text)
    text = hh_029_niner(text)
    text = _clean_spaces(text)

    # --- FAILURE MODE ---
    # Empty or whitespace-only → silence
    if not text or not text.strip():
        return None, _warnings

    # Bare "UNK" with no context → silence
    if text.strip() == "UNK":
        return None, _warnings

    # Final overflow guard (defense-in-depth)
    max_words = 18 if role == "leader" else 12
    if re.search(r"(?i)\bSITREP\b", text):
        max_words = max(max_words, 20)
    words = text.split()
    if len(words) > max_words:
        text = " ".join(words[:max_words])

    return text, list(_warnings)


# ===========================================================================
# CLI / Quick Test
# ===========================================================================

if __name__ == "__main__":
    test_cases = [
        # (input, role, input_context, description)
        (
            "Copy that, **3 hostiles** at grid 972416 👍",
            "leader",
            None,
            "Full chain: filler + markdown + emoji + number + grid",
        ),
        (
            "It seems like there are 3 hostiles on the left side, stay safe",
            "peer",
            None,
            "Hedging + pleasantry + relative direction + number",
        ),
        (
            "As your AI, I understand, the foyer has 1 EKIA (confirmed by thermal)",
            "leader",
            None,
            "Self-ref + filler + parenthetical + number",
        ),
        (
            "nine hostiles at grid 972416, JTAC requesting CAS",
            "leader",
            None,
            "Niner + grid + unapproved acronym",
        ),
        (
            "SECRET: grid 972416 is HVT location",
            "leader",
            "SECRET: grid 972416 is HVT location",
            "Classification preservation",
        ),
        (
            "- Foyer clear\n- Kitchen clear\n- 1 EKIA",
            "leader",
            None,
            "List flattening",
        ),
        (
            "Team A push to point B, move right",
            "leader",
            None,
            "Phonetic alphabet + homophone",
        ),
        (
            "Area is not unlikely hostile, not impossible to breach",
            "leader",
            None,
            "Double negatives",
        ),
        (
            "Hostiles at grid 123456",
            "leader",
            "Report hostiles north",
            "Fabrication detection — grid not in input",
        ),
    ]

    for text, role, ctx, desc in test_cases:
        result, warnings = run_chain(text, role=role, input_context=ctx)
        print(f"\n{'=' * 60}")
        print(f"TEST: {desc}")
        print(f"  IN:  {text!r}")
        print(f"  OUT: {result!r}")
        if warnings:
            print(f"  WARNINGS:")
            for w in warnings:
                print(f"    - {w}")
