# Agent Skill Imports

## Current imported stack

The repo now carries a curated iOS agent-skill stack in `.agents/skills/`, plus engineering rules in `.agents/rules/`.

## Source

Primary source: `../brain/sources/2026-05-21-paul-solt-ios-agent-skills-xcode-project.md`.

## Imported on 2026-05-21

### OpenAI Build iOS Apps plugin skills

Imported from `openai/plugins/plugins/build-ios-apps/skills`:

- `ios-app-intents`
- `ios-debugger-agent`
- `ios-ettrace-performance`
- `ios-memgraph-leaks`
- `swiftui-liquid-glass`
- `swiftui-performance-audit`
- `swiftui-ui-patterns`
- `swiftui-view-refactor`

Reason: these add practical Codex-era workflows for simulator debugging, memory/performance traces, SwiftUI refactoring, iOS App Intents, and current SwiftUI UI patterns.

### AvdLee Xcode Build Optimization skills

Imported from `AvdLee/Xcode-Build-Optimization-Agent-Skill/skills`:

- `spm-build-analysis`
- `xcode-build-benchmark`
- `xcode-build-fixer`
- `xcode-build-orchestrator`
- `xcode-compilation-analyzer`
- `xcode-project-analyzer`

Reason: these add a build-performance workflow that is distinct from the existing Swift/iOS language and framework skills.

### Merowing rules

Imported as repo-local rules under `.agents/rules/`:

- `general.md`
- `rule-loading.md`

Reason: these provide higher-level Swift engineering guardrails and a context-sensitive rule-loading pattern. They complement tactical skills rather than duplicating them.

## Held back deliberately

- Twostraws SwiftUI / Swift Concurrency / Swift Testing / SwiftData skills: held because the repo already has local skills covering those areas.
- AvdLee SwiftUI / Concurrency / Testing / Core Data: held because SwiftUI/concurrency/testing overlap existing skills, and 567 v1 is SwiftData rather than Core Data.
- OpenAI Build macOS Apps: held because this repo is iOS-only.
- AppCreator gated skill: not imported directly; its agent-friendly build idea is represented by the root `Makefile`.

## Applied workflow update on 2026-05-26

The Paul Solt / AppCreator learnings are now represented in repo-local agent infrastructure:

- `AGENTS.md` captures concise build, verification, architecture, logging, and git/deletion safety rules for agents.
- `docs/agent-friendly-ios-workflow.md` explains the command-line loop and token-efficiency practices for Five67.
- `Makefile` defaults to `build-and-run`, writes pretty/raw build logs under `build/logs/`, adds `run` and `ui-test` targets, and uses the reversible trash script for cleanup.
- `scripts/move_to_trash.sh` and `scripts/atomic_commit.sh` give agents safer deletion and commit paths.

## Agent usage guidance

- For implementation work, load the focused `.agents/skills/<skill>/SKILL.md` files relevant to the task.
- For architecture-heavy work, read `.agents/rules/general.md` and `.agents/rules/rule-loading.md` first.
- For build/debug/test work, prefer `make`, `make build`, `make test`, and the imported iOS debugger/build optimization skills.
- Read `build/logs/*.pretty.log` before raw logs to keep agent context small.
