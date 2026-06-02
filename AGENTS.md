# AGENTS.md — Five67 iOS Agent Rules

## Product brain (shared)

The 567 product brain (strategy, personas, roadmap, decisions, open questions) is **not**
in this repo. It lives canonically in the `567-platform` monorepo at `567-platform/brain`
and is exposed here through a gitignored symlink `brain -> ../567-platform/brain`. Read it
before product/strategy work; start with `brain/README.md`.

If `brain/` is missing (fresh clone), clone `567-platform` as a sibling of this repo and run
`ln -s ../567-platform/brain brain`. iOS-specific implementation notes still live here under
`docs/` (Tier-3); the physical split of iOS docs out of the shared brain is a pending follow-up.

## Build and verification loop

- Prefer the repo `Makefile` over direct Xcode UI work.
- Default command: `make` (`build-and-run`).
- Use `make build` for compile checks and `make test` for fast verification.
- `make ui-test` is intentionally opt-in and currently a placeholder until a UI test target exists.
- Build/test output is written under `build/logs/`; read the focused `.pretty.log` first and only inspect `.raw.log` when needed.
- Do not claim verification passed if a tool, simulator, signing, or environment issue blocked the run.

## Agent efficiency

- Keep each task small enough to build/test independently.
- Read targeted files and logs; do not paste full Xcode logs into chat unless requested.
- Add or tighten runtime logs when behavior cannot be verified from tests alone.
- Remove verbose temporary logs once the issue is understood unless they are useful product diagnostics.

## iOS architecture rules

- Use one code path per action. Buttons, menus, gestures, and keyboard shortcuts should call the same implementation.
- Do not add fallbacks, parallel state machines, or compatibility paths without explicit written approval.
- Preserve SwiftData data safety; migration and persistence changes need focused tests or a manual verification note.
- Prefer SwiftUI/Observation patterns already present in the app before introducing new architecture.

## Safety rules

- Never run destructive git commands without explicit written approval.
- Forbidden git commands: `git reset --hard`, `git checkout --`, `git restore`, `git revert`, `git clean`, force push, and `git commit --amend`.
- Do not use `rm` for project files. Use `scripts/move_to_trash.sh <paths...>` so deletions are reversible.
- Make atomic commits only when asked. Stage explicit files, not `git add .`; prefer `scripts/atomic_commit.sh <agent-name> <intent> <file1> ...`.

## Handoff expectations

- State exactly what changed.
- State the exact verification commands run and their results.
- If verification was skipped or blocked, say why and what should be run next.
