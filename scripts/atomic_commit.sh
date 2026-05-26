#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  cat >&2 <<'USAGE'
Usage: scripts/atomic_commit.sh <agent-name> <intent> <file1> [file2 ...]

Example:
  scripts/atomic_commit.sh Agent "add agent-friendly build workflow" Makefile AGENTS.md scripts/move_to_trash.sh
USAGE
  exit 2
fi

agent_name="$1"
intent="$2"
shift 2

# Stage only the explicit files passed by the caller. This avoids sweeping in unrelated user work.
git add -- "$@"

git commit -m "Agent ${agent_name}: ${intent}"
