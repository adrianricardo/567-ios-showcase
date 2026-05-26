#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "Usage: scripts/move_to_trash.sh <paths...>" >&2
  exit 2
fi

trash_dir="${HOME}/.Trash"
mkdir -p "$trash_dir"

for path in "$@"; do
  if [ ! -e "$path" ]; then
    echo "skip: $path does not exist"
    continue
  fi

  base="$(basename "$path")"
  stamp="$(date +%Y%m%d-%H%M%S)"
  dest="$trash_dir/${base}.${stamp}"
  n=0
  while [ -e "$dest" ]; do
    n=$((n + 1))
    dest="$trash_dir/${base}.${stamp}.${n}"
  done

  mv "$path" "$dest"
  echo "moved to trash: $path -> $dest"
done
