# Windfall

A garden planning, recording and natural history app for iPhone, iPad and
Mac, with an on-device assistant called Eira.

## Start here

| If you want to | Read |
|---|---|
| See what changed and why | `CHANGES.md` |
| Know what each file is for and the order to add them | `docs/windfall-manifest.md` |
| Read the original specification | `docs/windfall-spec.md` |
| Check the code without a Mac | `Tools/checks/run-checks.sh` |
| Judge whether a model is good enough for Eira | `docs/eira-test-questions.md` |

The plans, decisions and research live in the Windfall project's
knowledge base on Claude, not here. This repository is for code.

## What is in this repository

- `Windfall/` holds the Swift source files. This is the folder Xcode
  builds.
- `docs/` holds the file map and the original specification.
- `Tools/checks/` holds the checking scripts. Nothing in `Tools/` is
  part of the app.

## What is not here yet

The Xcode project file (`Windfall.xcodeproj`), the app's settings file
and the Google sign-in details are on William's Mac. They join this
repository the first time it is connected to the Mac.

## Branches

- `main` is the corrected set: the existing code made consistent, ready
  for its first build.
- `eira-on-device` is new work on running Eira locally. It is kept
  separate so it cannot get in the way of that first build. Build `main`
  first. `CHANGES.md` on that branch lists what it adds and how to set
  it up in Xcode.

## Joining this to the Xcode project on the Mac

The easiest way is to let Claude do it:

1. On the Mac, open the Claude desktop app and open a chat in the
   Windfall project.
2. Connect the folder that contains `Windfall.xcodeproj`.
3. Ask Claude to "join my Xcode project to the Windfall repository".

Claude will then compare the Mac's files with these, keep any fixes made
on the Mac, add the project file to the repository and explain each
step.

To look at the code in Xcode without changing anything, use Xcode's
Clone command from the Integrate menu and paste this repository's
address.

## Rules for this code

- Every change is explained in `CHANGES.md` in plain English.
- Nothing counts as done until it has built on the Mac.
- Passwords, keys and sign-in files are never committed.
