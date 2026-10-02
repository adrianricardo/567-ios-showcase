# 567 — dance practice iOS app

**567** turns the videos dancers film in class into a practice library: import clips, mark the moves inside each one, and drill them in a full-screen, swipeable feed.

Shipped on the App Store as a paid-unlock app. → **[567 Dance on the App Store](https://apps.apple.com/us/app/567-dance/id6771970284)**

This repository is the complete iOS app with its real commit history, shared as a work sample. Product strategy and business planning live in a separate private repo and have been removed from this history. Some docs and plans still mention those files, or the third-party agent skills, by name. Those files are not included here.

## Stack

- Swift 6 (strict concurrency), SwiftUI, iOS 18+
- SwiftData with versioned schemas and a migration plan (V1 → V5)
- AVFoundation: custom `AVPlayerLayer` surface, trim timeline, scrub-to-seek
- StoreKit 2 non-consumable "pay once" unlock, with a freemium access policy
- XcodeGen (`project.yml`) and a `Makefile`-driven build/test loop. No Xcode UI is needed.
- Swift Testing unit tests plus XCUITest visual-audit and tab-bar checks

## Highlights worth reading

| Commit | What it shows |
|---|---|
| [`395df38`](../../commit/395df38) | A custom TikTok-style player: `AVPlayerLayer` surface, action rail, timestamp pill |
| [`853af28`](../../commit/853af28) | Data-safety work: library exporter, privacy manifest, and a migration-failure recovery UI |
| [`f2a7377`](../../commit/f2a7377) | Promotes a scalar enum to a SwiftData `@Model` with a V3 → V4 schema migration |
| [`8f1e2e4`](../../commit/8f1e2e4) | Horizontal scrub gesture for seeking across the video timeline |
| [`7ebaa77`](../../commit/7ebaa77) | VoiceOver actions that reuse the same navigation path as the visual edge taps |
| [`e4639a3`](../../commit/e4639a3) | StoreKit 2 lifetime unlock, with restore and the freemium access policy |
| [`0bae109`](../../commit/0bae109) | V5 schema migration with migration and access-policy tests |
| [`59da619`](../../commit/59da619) | A visual-audit UI test harness and App Review notes for a redesign |
| [`3b1cc8b`](../../commit/3b1cc8b) | A separate Debug bundle ID so development and production builds install side by side |

Design and engineering write-ups are in [`docs/`](docs/), for example [data durability](docs/data-durability.md), the [design system](docs/design-system.md) and the [design decisions](docs/design-decisions.md). Feature specs and phased plans are in [`specs/`](specs/).

## How it was built: directing coding agents

Much of this app was built by directing AI coding agents (Claude Code and Codex). Commits prefixed `Agent Claude:` / `Agent Codex:` were made through that workflow, as were commits authored as `Enzo` (another agent setup).

I owned the product decisions, specs, architecture rules and review. The working agreement is in [`AGENTS.md`](AGENTS.md) and [`docs/agent-friendly-ios-workflow.md`](docs/agent-friendly-ios-workflow.md). It covers:

- Specs come first, as phased plans with review gates (see [`specs/done/0007-onboarding-core-ui-redesign.plan.md`](specs/done/0007-onboarding-core-ui-redesign.plan.md)).
- Each user action has one code path. No parallel state machines or silent fallbacks.
- SwiftData persistence changes require focused migration tests.
- A change only counts as verified after `make build` and `make test` have run, with logs written to `build/logs/`.

## Build

```bash
brew install xcodegen
make build   # compile
make test    # unit tests
make         # build and run in the simulator
```

Signing uses the original team ID in `project.yml`. Change `DEVELOPMENT_TEAM` to your own to run on a device.

## License

All rights reserved. The source is shared for review only.
