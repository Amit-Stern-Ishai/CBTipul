#!/usr/bin/env python3
"""Generate Android string resources from ios/Localization.swift."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SWIFT = ROOT / "ios" / "Localization.swift"
RES = ROOT / "android" / "app" / "src" / "main" / "res"
VALUES = RES / "values"
RAW = RES / "raw"


def camel_to_snake(name: str) -> str:
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()


def xml_escape(text: str) -> str:
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    text = text.replace('"', r"\"")
    # Android treats ' as a string delimiter unless escaped.
    text = text.replace("'", r"\'")
    return text


def interpolate(swift: str) -> str:
    parts = re.split(r"\\\(([^)]+)\)", swift)
    out = []
    n = 1
    for i, part in enumerate(parts):
        if i % 2 == 0:
            out.append(part)
        else:
            out.append(f"%{n}$s")
            n += 1
    return "".join(out)


def main() -> None:
    src = SWIFT.read_text(encoding="utf-8")
    VALUES.mkdir(parents=True, exist_ok=True)
    RAW.mkdir(parents=True, exist_ok=True)

    strings: list[tuple[str, str]] = []
    arrays: list[tuple[str, list[str]]] = []

    # Triple-quoted lets → raw files or long strings.
    for m in re.finditer(
        r"static let (\w+)\s*=\s*\"\"\"(.*?)\"\"\"",
        src,
        re.S,
    ):
        name, body = m.group(1), m.group(2).strip("\n")
        key = camel_to_snake(name)
        if name in {"termsBody", "privacyPolicyBody", "aiConsentBody"}:
            (RAW / f"{key}.txt").write_text(body + "\n", encoding="utf-8")
        else:
            strings.append((key, body))

    # Arrays of strings.
    for m in re.finditer(
        r"static let (\w+)\s*(?::\s*\[String\])?\s*=\s*\[(.*?)\]",
        src,
        re.S,
    ):
        name, inner = m.group(1), m.group(2)
        items = re.findall(r"\"((?:\\.|[^\"])*)\"", inner)
        if items:
            arrays.append((camel_to_snake(name), [bytes(i, "utf-8").decode("unicode_escape") if "\\" in i else i for i in items]))

    # Simple static lets: = "..." possibly continued on next lines as "..."
    for m in re.finditer(
        r"static let (\w+)\s*=\s*\"((?:\\.|[^\"])*)\"",
        src,
    ):
        name, value = m.group(1), m.group(2)
        key = camel_to_snake(name)
        if any(k == key for k, _ in strings):
            continue
        if any(k == key for k, _ in arrays):
            continue
        strings.append((key, value.encode("utf-8").decode("unicode_escape") if "\\" in value else value))

    # Concatenated: static let x =\n    "foo"
    for m in re.finditer(
        r"static let (\w+)\s*=\s*\n\s*\"((?:\\.|[^\"])*)\"",
        src,
    ):
        name, value = m.group(1), m.group(2)
        key = camel_to_snake(name)
        if any(k == key for k, _ in strings):
            continue
        strings.append((key, value))

    # Simple function bodies that are a single interpolated string.
    for m in re.finditer(
        r"static func (\w+)\([^)]*\) -> String \{\s*return \"((?:\\.|[^\"])*)\"\s*\}",
        src,
        re.S,
    ):
        name, value = m.group(1), m.group(2)
        key = camel_to_snake(name)
        strings.append((key, interpolate(value)))

    for m in re.finditer(
        r"static func (\w+)\([^)]*\) -> String \{\s*\"((?:\\.|[^\"])*)\"\s*\}",
        src,
        re.S,
    ):
        name, value = m.group(1), m.group(2)
        key = camel_to_snake(name)
        if any(k == key for k, _ in strings):
            continue
        strings.append((key, interpolate(value)))

    extra = [
        ("verify_email_message", "שלחנו קישור אימות לכתובת %1$s. יש לפתוח את הקישור כדי להשלים את ההרשמה."),
        ("session_numbered", "פגישה %1$d"),
        ("session_editor_title", "פגישה"),
        ("session_editor_title_numbered", "פגישה %1$d"),
        ("more_follow_ups", "עוד (%1$d)"),
        ("delete_code_message", "להשלמת המחיקה יש להקליד את הקוד:\n%1$s"),
        ("sessions_count_one", "פגישה אחת"),
        ("sessions_count_other", "%1$d פגישות"),
        ("last_session_summary", "%1$s · %2$s"),
        ("app_version_label", "גרסה %1$s (%2$s)"),
        ("ai_prompt_placeholder", "שאל/י על %1$s"),
        ("gad_phq_scores", "GAD-7: %1$d · PHQ-9: %2$d"),
        ("score_badge", "%1$s: %2$d"),
        ("total_score_line", "%1$s: %2$d"),
        ("previous_score_line", "%1$s: %2$d"),
        ("previous_answer_legend", "הערך המוקף = תשובה מהשאלון הקודם מתאריך %1$s"),
        ("previous_score_label", "קודם, %1$s"),
        ("tokens_used", "אסימונים בשימוש: %1$d"),
        ("source_line", "מקור: %1$s"),
        ("confidence_line", "רמת ביטחון: %1$s"),
        ("purpose_line", "מטרה: %1$s"),
        ("bulleted", "• %1$s"),
        ("transcription_failed", "התמלול נכשל: %1$s"),
        ("could_not_read_audio_file", "לא ניתן לקרוא את קובץ השמע: %1$s"),
        ("not_implemented_error", "%1$s עדיין לא זמין."),
        ("session_type_first_phone_call", "שיחת טלפון ראשונית"),
        ("session_type_intake", "אינטייק"),
        ("session_type_psycho_education", "פסיכו-חינוכי"),
        ("session_type_diary_one", "יומן 1"),
        ("session_type_diary_two", "יומן 2"),
        ("session_type_diary_three", "יומן 3"),
        ("session_type_case_formulation", "המשגה"),
        ("session_type_behavioral_interventions", "חשיפות"),
        ("session_type_relapse_prevention_and_termination", "סיכום טיפול והישנות"),
        ("gad7_severity_minimal", "ללא חרדה משמעותית"),
        ("gad7_severity_mild", "חרדה קלה"),
        ("gad7_severity_substantial", "חרדה משמעותית"),
        ("gad7_severity_extreme", "חרדה קשה"),
        ("phq9_severity_minimal", "דיכאוןם מינימאלי"),
        ("phq9_severity_mild", "דיכאון קל"),
        ("phq9_severity_moderate", "דיכאון בינוני"),
        ("phq9_severity_moderately_severe", "דיכאון בינוני כבד"),
        ("phq9_severity_severe", "דיכאון כבד"),
        ("phq9_suggestion_minimal", "אין צורך בטיפול לדיכאון"),
        ("phq9_suggestion_mild", "כדאי לשקול טיפול ע״פ דיווח הסימפטומים של המטופל וע״פ התפקוד הכללי"),
        ("phq9_suggestion_moderate", "כדאי לשקול טיפול ע״פ דיווח הסימפטומים של המטופל וע״פ התפקוד הכללי"),
        ("phq9_suggestion_moderately_severe", "מומלץ טיפול בדיכאון בתרופות, פסיכוטרפיה או שילוב שלהם"),
        ("phq9_suggestion_severe", "מומלץ טיפול בדיכאון בתרופות, פסיכוטרפיה או שילוב שלהם"),
        ("patient_status_active", "Active"),
        ("patient_status_inactive", "Inactive"),
        ("mic_permission_rationale", "CBTipul uses the microphone to record voice notes for therapy sessions."),
    ]
    existing = {k for k, _ in strings}
    for k, v in extra:
        if k not in existing:
            strings.append((k, v))
            existing.add(k)

    # Drop helper formatters that are not copy.
    skip = {
        "hebrew_date",
        "hebrew_numeric_date",
        "hebrew_date_time",
        "hebrew_month",
        "label",
        "suggestion",
        "session",
        "session_editor_title",  # keep extra version
        "sessions_count",
        "last_session_summary",
        "app_version_label",
        "ai_prompt_placeholder",
        "gad_phq_scores",
        "score_badge",
        "total_score_line",
        "previous_score_line",
        "previous_answer_legend",
        "previous_score_label",
        "tokens_used",
        "source_line",
        "confidence_line",
        "purpose_line",
        "bulleted",
        "transcription_failed",
        "could_not_read_audio_file",
        "not_implemented_error",
        "verify_email_message",
        "more_follow_ups",
        "delete_code_message",
        "hebrew_date_from",
    }
    # Don't skip the extra keys we just added — only skip if they came from
    # unusable Swift funcs. We already added the good extras after parse,
    # so filter parsed junk by name if value still contains Swift interpolation.
    cleaned = []
    seen = set()
    for k, v in strings:
        if "\\(" in v:
            continue
        if k in seen:
            continue
        seen.add(k)
        cleaned.append((k, v))
    strings = cleaned

    lines = [
        '<?xml version="1.0" encoding="utf-8"?>',
        "<resources>",
    ]
    for k, v in strings:
        lines.append(f'    <string name="{k}">{xml_escape(v)}</string>')
    lines.append("</resources>")
    lines.append("")
    (VALUES / "strings.xml").write_text("\n".join(lines), encoding="utf-8")

    array_lines = [
        '<?xml version="1.0" encoding="utf-8"?>',
        "<resources>",
    ]
    for k, items in arrays:
        array_lines.append(f'    <string-array name="{k}">')
        for item in items:
            array_lines.append(f"        <item>{xml_escape(item)}</item>")
        array_lines.append("    </string-array>")
    array_lines.append("</resources>")
    array_lines.append("")
    (VALUES / "arrays.xml").write_text("\n".join(array_lines), encoding="utf-8")

    plurals = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <plurals name="sessions_count">
        <item quantity="one">פגישה אחת</item>
        <item quantity="other">%d פגישות</item>
    </plurals>
</resources>
"""
    (VALUES / "plurals.xml").write_text(plurals, encoding="utf-8")
    print(f"Wrote {len(strings)} strings, {len(arrays)} arrays")


if __name__ == "__main__":
    main()
