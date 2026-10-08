# MARVIN Mobile

MARVIN on iPhone: Voice, Chat and Dashboard, talking to MARVIN's mobile backend on the Mac over Tailscale. Installed on the phone as **MARVIN**.

Design: PRD [G-Eskayo/marvin#152](https://github.com/G-Eskayo/marvin/issues/152) and ADRs 0039–0046 in [G-Eskayo/marvin](https://github.com/G-Eskayo/marvin). The backend lives there too, in `dashboard/mobile-backend/`.

## What works now

- **Thread**: the one continuous conversation, with Chat replies from a headless Claude Code session on the Mac.
- **Dashboard**: Health and ticket Activity, read-only.
- **Connection banner**: says when the backend can't be reached and when it was last reached.

Voice, offline mode, Face ID-gated actions, Boards, PR review and Docs come next, as their own slices.

## Layout

- `Packages/MarvinCore`: backend client, chat stream decoding, connection state. Tested with `swift test`, no simulator needed.
- `Apps/Marvin`: the SwiftUI app. The Xcode project is generated, not committed.

## Run it on a phone

```sh
echo YOURTEAMID > Apps/Marvin/.team    # Xcode > Settings > Accounts; gitignored
./scripts/generate-project.sh
open Apps/Marvin/Marvin.xcodeproj      # pick your iPhone, press Run
```

The phone needs Tailscale on and must be on the backend's allowlist (`~/.claude/mobile-allowlist.json` on the Mac). The backend address is set in the app's Settings tab.
