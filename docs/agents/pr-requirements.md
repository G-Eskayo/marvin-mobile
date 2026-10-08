# Ticket and PR requirements

## Anything UI-facing ships with simulator screenshots and how to use it

Any change that alters what's on screen must, in the ticket's closing comment or the PR body:

1. **Show it.** Screenshots of the real app on an iPhone simulator, one per affected screen or state.
   Run `scripts/screenshots.sh <set>` (e.g. `issue-5`). It builds the app, runs it in demo mode (`-demo`, a built-in
   fake backend with realistic data) and writes PNGs to `docs/screenshots/<set>/`. Commit them and link the
   images from the comment. Add a `shot` line to the script for any new screen or state.
2. **Explain how to use it, with use cases.** For each new capability: "You want X → do Y → you see Z."
   Concrete situations, not feature lists.

If a screenshot can't be captured, say so plainly and why. Never imply a screen was seen when it wasn't.

Non-UI changes (backend client, models, tests) don't need screenshots.

## Never a bare ticket number

Anywhere the app shows a ticket or PR, show its title with the number, never the number alone.
