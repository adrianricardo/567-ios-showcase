#!/usr/bin/env bash
# Reset the feed-coach @AppStorage flags on the booted iOS simulator so both
# coach beats re-trigger on next launch. Library (SwiftData store + video
# files in Documents/videos/) is untouched.
#
# Why this is more than `defaults delete`: iOS simulators run their own
# cfprefsd daemon that caches preferences in memory. Just rewriting the plist
# on disk isn't enough — cfprefsd keeps serving the stale "seen" value to the
# app on the next cold launch. We also evict cfprefsd inside the simulator.
#
# Usage: ./scripts/reset-coach.sh
set -euo pipefail

APP_ID=com.nopal.five67

CONTAINER="$(xcrun simctl get_app_container booted "$APP_ID" data 2>/dev/null || true)"
if [[ -z "$CONTAINER" ]]; then
  echo "Could not find a booted simulator with $APP_ID installed." >&2
  echo "Boot a simulator and install the app first." >&2
  exit 1
fi

PLIST="$CONTAINER/Library/Preferences/$APP_ID"

# 1. Strip the keys from the on-disk plist.
defaults delete "$PLIST" hasSeenFeedSwipeCoach 2>/dev/null || true
defaults delete "$PLIST" hasSeenFeedTapCoach 2>/dev/null || true

# 2. Force-quit the app so the next launch is a real cold launch.
xcrun simctl terminate booted "$APP_ID" 2>/dev/null || true

# 3. Evict cfprefsd's in-memory cache inside the simulator. Without this,
# the daemon serves the stale value back to the app even though disk is clean.
xcrun simctl spawn booted killall cfprefsd 2>/dev/null || true

echo "Coach flags cleared and cfprefsd evicted. Relaunch Five67 from the home screen."
