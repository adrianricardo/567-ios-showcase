# Agent-Friendly iOS Workflow

## Why this exists

Five67 should be easy for Codex, Claude Code, Hermes, or any future agent to build and verify without opening Xcode. The agent interface is the command line: `make`, focused logs, tests, and clear repo rules.

## Daily loop

1. Scope one small product change.
2. Edit the smallest relevant files.
3. Run `make build` or a narrower command if available.
4. Read `build/logs/build.pretty.log` first; use `build/logs/build.raw.log` only when the pretty log hides needed detail.
5. Run `make test` when tests exist for the touched behavior.
6. Play-test in the simulator/device and paste concise observed feedback back to the agent.
7. Add runtime logs only when the behavior is otherwise opaque.
8. Handoff with exact commands and pass/fail status.

## Make targets

- `make` / `make build-and-run`: build and relaunch the app.
- `make build`: generate the Xcode project and compile with concise output.
- `make run`: install and launch the built app on the configured simulator.
- `make test`: run the scheme tests and write logs.
- `make ui-test`: placeholder; wire this once a UI test target exists.
- `make clean`: move build artifacts to Trash instead of permanently deleting them.

## Token-efficiency rules

- Summarize logs instead of pasting whole logs.
- Prefer pretty logs over raw logs.
- Keep rules in `AGENTS.md` short and stable.
- Put deep project context in `brain/` and focused docs instead of one giant prompt.
- Run fast, focused checks during iteration; reserve full UI/regression runs for handoff.

## Next upgrades

- Add a real unit-test target to `project.yml` so `make test` is meaningful.
- Add a separate UI-test target and wire `make ui-test` only after the simulator flow is stable.
- Consider adding a small `scripts/summarize_xcode_log.py` if raw logs become noisy despite `xcbeautify`.
