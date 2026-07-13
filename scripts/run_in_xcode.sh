#!/usr/bin/env bash
# Build & run the app through Xcode's scheme so the local StoreKit
# configuration (Five67.storekit, referenced by the scheme's launch action)
# is injected. A raw `simctl launch` cannot do this, which is why the
# in-app paywall shows "Unlock is unavailable" and a disabled button when
# launched via `make run` / `make run-fresh`.
#
# Usage: scripts/run_in_xcode.sh <path-to-.xcodeproj> <scheme>
set -euo pipefail

PROJECT="${1:?path to .xcodeproj required}"
SCHEME="${2:?scheme name required}"

if [ ! -d "$PROJECT" ]; then
  echo "Project not found: $PROJECT" >&2
  exit 1
fi

echo "Opening $PROJECT in Xcode and running scheme '$SCHEME' (StoreKit config active)..."

osascript - "$PROJECT" "$SCHEME" <<'APPLESCRIPT'
on run argv
  set projectPath to item 1 of argv
  set schemeName to item 2 of argv

  tell application "Xcode"
    activate
    set workspaceDoc to open projectPath

    -- Wait for the workspace to finish loading before acting on it.
    repeat 120 times
      if loaded of workspaceDoc is true then exit repeat
      delay 0.5
    end repeat

    set active scheme of workspaceDoc to (first scheme of workspaceDoc whose name is schemeName)

    -- run returns a scheme action result; poll it until Xcode finishes launching.
    set actionResult to run workspaceDoc
    repeat
      if completed of actionResult is true then exit repeat
      delay 0.5
    end repeat

    return status of actionResult
  end tell
end run
APPLESCRIPT

echo "Xcode launch action finished. The app is now running with StoreKit active."
