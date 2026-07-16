# iOS docs (Tier-3 — implementation)

iOS-specific implementation notes for the 567 (Five67) app. These were split out of the shared
product brain so the brain stays product-level (Tier-2) and iOS detail lives with the iOS code.

- **Tier-2 product brain** (strategy, personas, roadmap, decisions, product open-questions) is shared
  and lives in the `567-platform` monorepo, reachable here through the gitignored symlink at
  `../brain` (i.e. `../brain/synthesized/…`, `../brain/sources/…`).
- **Tier-1 company/LLC** material is in the Obsidian vault, not in any repo.

Docs here:
- `design-foundation-brief.md` — original design foundation sprint contract
- `design-foundation/proposal.md` — approved matrix, evidence, and three representative snapshots
- `design-system.md` — approved Warm Stage visual and interaction contract
- `design-decisions.md` — dated iOS experience decisions and rationale
- `design-migration.md` — implemented Groups 0–5 migration record and historical visual review gates
- `feed-first-ia.md` — feed-first information architecture & journey
- `library-pane-and-style-mode.md` — library pane + global style mode spec
- `data-durability.md` — SwiftData durability / backup / migration posture
- `launch-punch-list.md` — TestFlight → App Store launch punch list
- `agent-skill-imports.md` — iOS agent-skill imports
- `open-questions-ios.md` — iOS-specific open questions (split from the shared `open-questions.md`)
- `agent-friendly-ios-workflow.md` — agent build/verify workflow

Cross-references of the form `feed-first-ia.md` point to siblings here; `../brain/synthesized/…`
point up into the shared product brain.
