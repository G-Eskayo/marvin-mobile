# MARVIN Mobile — Repo Instructions

## Pull requests and tickets

Anything that changes how the app looks must include iPhone-simulator screenshots (`scripts/screenshots.sh`) and
how to use it, with use cases. See `docs/agents/pr-requirements.md`.

## Design

PRD and ADRs live in G-Eskayo/marvin (PRD #152, ADRs 0039–0046). The app mirrors the desktop dashboard's look
(`Apps/Marvin/Sources/Theme.swift`).

## Tests

`cd Packages/MarvinCore && swift test`. Logic lives in MarvinCore so it tests without a simulator; SwiftUI views get
light checks only (PRD #152 Testing Decisions).
