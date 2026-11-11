# Windfall

A garden planning, recording and natural history app for iPhone, iPad and
Mac, with an on-device assistant called Eira.

Everything is stored on the device. There is no sign-in and no server.

## Start here

| If you want to | Read |
|---|---|
| See what changed and why | `CHANGES.md` |
| Know what the starter data holds and leaves out | `docs/starter-data-report.md` |
| Judge whether a model is good enough for Eira | `docs/eira-test-questions.md` |
| Check the code without a Mac | `Tools/checks/run-checks.sh` |
| Read the original specification | `docs/windfall-spec.md` |

`docs/windfall-manifest.md` and `docs/windfall-spec.md` describe the app
as first designed, with Google Sheets. They are kept for reference and
are out of date on that point.

The plans, decisions and research live in the Windfall project's
knowledge base on Claude, not here. This repository is for code.

## What is in this repository

- `Windfall.xcodeproj` is the Xcode project. Open this.
- `Windfall/` holds the Swift source files and `StarterData.json`. Xcode
  builds every file in this folder, so adding a file here adds it to the
  app.
- `docs/` holds the reports and the original design papers.
- `Tools/checks/` holds the checking scripts and logic tests.
- `Tools/data/` holds the script that makes `StarterData.json` from the
  Garden Planning workbook.

Nothing in `Tools/` or `docs/` is part of the app.

## Branches

| Branch | What it is |
|---|---|
| `eira-on-device` | The current version: Eira running on the device, native garden data, no Google. Builds and runs in Xcode 27 |
| `main` | The earlier corrected set, with Google sign-in. Builds, but is behind |
| `google-sheets-version` | A marker for the last version that used Google Sheets, in case it is ever wanted |

## Never commit

Passwords, keys and sign-in files. `.gitignore` already blocks the usual
ones.

## Rebuilding the starter data

```
python3 Tools/data/build_starter_data.py Garden_Planning.xlsx \
    Windfall/StarterData.json docs/starter-data-report.md
```

The workbook itself is not kept in this repository.
