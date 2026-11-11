#!/usr/bin/env python3
"""Turns the Garden Planning workbook into Windfall's starter data file.

    python3 build_starter_data.py Garden_Planning.xlsx StarterData.json [report.md]

The app reads StarterData.json on first launch and through
Settings > Garden data. This script is the only thing that writes it, so
running it again on a newer workbook gives a file that can be compared with
the old one line by line.

What it does, and nothing more:

  * Reads the cached value of every cell. Formulas are never recalculated.
  * Finds columns by their header text, never by position.
  * Leaves out columns that hold only formulas, because the app works those
    values out for itself.
  * Leaves out error cells such as #N/A and #REF!.
  * Leaves out rows with no name, and companion pairs with no + or - mark.
  * Writes every value as text, the way the app expects.

It changes no wording. Anything it had to decide is listed in the report.
"""

import datetime
import json
import sys
import warnings

import openpyxl

warnings.filterwarnings("ignore")  # openpyxl grumbles about data validation

# name in the workbook, row holding the headers, column that must not be empty
PLANT_TABLES = [
    ("Permaculture Garden", 3, "Common Name"),
    ("Allotment Garden", 1, "Name"),
    ("Permaculture Plants to buy", 3, "Common Name"),
    ("Previously Owned Plants", 3, "Common Name"),
]
REFERENCE_TABLES = [
    ("Companion planting", 1, "Plant 1"),
    ("Fauna", 1, "Common Name"),
    ("Plant-Fauna Links", 1, "Plant"),
    ("Flower Form Guide", 1, "Flower Shape"),
    ("Cascades", 1, "Step 1 — Plant"),
]
# Sheets that exist in the workbook but are not carried across, with why.
NOT_CARRIED = {
    "Planting front page": "a lookup page made of formulas",
    "Planting Schedule": "a working schedule built from formulas; the app keeps its own sowing records",
    "Read Me": "instructions for the spreadsheet itself",
    "Plantings": "example row only; real records are made in the app",
    "Harvests": "example row only; real records are made in the app",
    "FIT Counts": "example row only; real records are made in the app",
    "FIT Tallies": "example row only; real records are made in the app",
    "Wildlife Observations": "example row only; real records are made in the app",
    "Wild Plant Assemblages": "the app has nowhere to put these yet",
    "Recording Organisations": "the app has nowhere to put these yet",
}
ERRORS = {"#REF!", "#NAME?", "#VALUE!", "#N/A", "#DIV/0!", "#NUM!", "#NULL!"}


def as_text(value):
    """One cell as the text the app should see, or None for nothing."""
    if value is None:
        return None
    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"
    if isinstance(value, datetime.datetime):
        if value.time() == datetime.time(0, 0):
            return value.date().isoformat()
        return value.isoformat(timespec="minutes")
    if isinstance(value, datetime.date):
        return value.isoformat()
    if isinstance(value, datetime.time):
        return value.strftime("%H:%M")
    if isinstance(value, float):
        if value.is_integer():
            return str(int(value))
        return format(value, ".10g")
    text = str(value).strip()
    if not text or text in ERRORS:
        return None
    return text


def read_table(values_book, formulas_book, name, header_row, key_header, notes):
    values, formulas = values_book[name], formulas_book[name]

    headers = {}  # column number -> header text
    for cell in values[header_row]:
        text = as_text(cell.value)
        if text:
            headers[cell.column] = text
    if key_header not in headers.values():
        sys.exit(f"STOPPED: '{name}' has no '{key_header}' column on row {header_row}.")

    seen = {}
    for column, text in headers.items():
        if text.lower() in seen:
            sys.exit(f"STOPPED: '{name}' has two columns called '{text}'.")
        seen[text.lower()] = column

    # A column counts as worked-out if it holds formulas and no typed values.
    derived = []
    for column, text in headers.items():
        typed = formula_count = 0
        for row in range(header_row + 1, values.max_row + 1):
            raw = formulas.cell(row, column).value
            if isinstance(raw, str) and raw.startswith("="):
                formula_count += 1
            elif as_text(raw) is not None:
                typed += 1
        if formula_count and not typed:
            derived.append(text)
    if derived:
        notes.append(f"**{name}**: left out {len(derived)} formula-only "
                     f"column(s): {', '.join(sorted(derived))}.")

    rows, skipped = [], 0
    for row in range(header_row + 1, values.max_row + 1):
        record = {}
        for column, text in headers.items():
            if text in derived:
                continue
            cell = as_text(values.cell(row, column).value)
            if cell is not None:
                record[text] = cell
        if not record:
            continue
        if key_header not in record:
            skipped += 1
            continue
        rows.append(record)
    if skipped:
        notes.append(f"**{name}**: skipped {skipped} row(s) that had some "
                     f"content but no '{key_header}'.")
    return rows


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    source, target = sys.argv[1], sys.argv[2]
    report_path = sys.argv[3] if len(sys.argv) > 3 else None

    values_book = openpyxl.load_workbook(source, data_only=True)
    formulas_book = openpyxl.load_workbook(source, data_only=False)

    notes, tables = [], []
    for name, header_row, key in PLANT_TABLES + REFERENCE_TABLES:
        if name not in values_book.sheetnames:
            sys.exit(f"STOPPED: the workbook has no sheet called '{name}'.")
        rows = read_table(values_book, formulas_book, name, header_row, key, notes)

        if name == "Companion planting":
            before = len(rows)
            marks = {}
            for row in rows:
                marks[row.get("+/-", "(blank)")] = marks.get(row.get("+/-", "(blank)"), 0) + 1
            rows = [r for r in rows if r.get("+/-", "").startswith(("+", "-", "−"))]
            others = {k: v for k, v in marks.items() if not k.startswith(("+", "-", "−"))}
            notes.append(f"**Companion planting**: kept {len(rows)} of {before} pairs. "
                         f"The rest have no + or - mark and say nothing either way. "
                         f"Marks left out: {others}.")

        tables.append({"name": name, "rows": rows})

    unknown = [s for s in values_book.sheetnames
               if s not in NOT_CARRIED and s not in [t["name"] for t in tables]]
    if unknown:
        notes.append("**Sheets this script does not know about** (not carried "
                     "across): " + ", ".join(unknown) + ".")

    document = {
        "formatVersion": 1,
        "source": source.replace("\\", "/").split("/")[-1],
        "generated": datetime.date.today().isoformat(),
        "tables": tables,
    }
    with open(target, "w", encoding="utf-8") as handle:
        json.dump(document, handle, ensure_ascii=False, indent=1)
        handle.write("\n")

    lines = [
        "# Starter data: conversion report",
        "",
        f"Made on {document['generated']} from `{document['source']}` by "
        "`Tools/data/build_starter_data.py`.",
        "",
        "## What was carried across",
        "",
        "| Table | Rows |",
        "|---|---|",
    ]
    lines += [f"| {t['name']} | {len(t['rows'])} |" for t in tables]
    lines += ["", "## Decisions the script made", ""]
    lines += [f"- {note}" for note in notes] or ["- None."]
    lines += ["", "## Sheets not carried across", "", "| Sheet | Why |", "|---|---|"]
    lines += [f"| {name} | {why} |" for name, why in NOT_CARRIED.items()
              if name in values_book.sheetnames]
    report = "\n".join(lines) + "\n"
    if report_path:
        with open(report_path, "w", encoding="utf-8") as handle:
            handle.write(report)
    print(report)


if __name__ == "__main__":
    main()
