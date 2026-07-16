# 567 design foundation sprint

## Status

Completed and approved on 2026-07-14 with one correction: minimalism means one sufficient visible indicator per state or fact. The selected style row uses a checkmark only—no visible “Selected” label, leading notch, or selection surface change. The shared product principle and iOS system are codified, and the separately authorized Groups 0–5 migration was completed by 2026-07-16. App-wide coverage remains a separate release-closure phase.

## Objective

Turn the chosen Warm Stage taste direction into a coherent, evidence-informed interaction system before it spreads across the app. Keep the output compact: decisions, realistic snapshots, and implementation-ready rules—not a presentation.

## Read first

1. `AGENTS.md`
2. `brain/ARCHITECTURE.md` and `brain/README.md`
3. `brain/cloud/synthesized/active-principles.md`
4. `brain/cloud/synthesized/onboarding-strategy.md`
5. `docs/brand.md`
6. `docs/design-system.md`
7. The current SwiftUI implementation and simulator UI

## Direction already selected

- Character: joyful, premium, simple, minimal, polished, powerful without looking complicated.
- Visual direction: Warm Tempo's tactile hierarchy with Quiet Stage's neutral palette.
- Flat near-black canvas, graphite content surfaces, warm-white hierarchy; no gradients or ornamental glow.
- A global selected dance style supplies an accent from the approved hard-coded palette.
- Accent is a signal, not a large background system.
- Preserve native iOS navigation and neutral Liquid Glass chrome.
- Family Values is the primary experience-craft framework: simplicity through gradual revelation, fluidity through continuity, and delight through selective emphasis. Adapt it heavily to 567; do not copy Family's product-specific UI or tokens literally.

These are directional constraints, not permission to copy Family's product or visual tokens literally.

## Provisional—must be resolved

- Semantic roles for primary action, selection, active navigation, progress, success, warning, and destructive action.
- Exact selected-row treatment and how it differs from a primary CTA.
- Surface hierarchy, component recipes, density, corner-radius usage, and motion grammar.
- Which current theme tokens are truly semantic versus POC conveniences.
- How the system adapts across onboarding, content/library, and immersive practice contexts.

Known POC issue: the onboarding style row and Continue CTA currently share the same warm-white surface. Contrast is now accessible, but the repeated prominence weakens hierarchy. Preserve the contrast fix; do not propagate that shared treatment.

## Representative surfaces

Evaluate the same system on only these three surfaces:

1. Onboarding dance-style selection
2. Library/home organization
3. Practice or video-detail flow

Use realistic 567 content and controls, not abstract design-system tiles.

## Targeted research

- Family Values: <https://benji.org/family-values>
- Apple HIG: Buttons, Lists and tables, Color, Accessibility, and current Liquid Glass guidance.
- A small reference set of polished native apps. Analyze hierarchy and state behavior; do not assemble a broad mood board.
- If practical, use a quick comprehension check: “What would you tap next?” and “What is currently selected?” Test in grayscale as well.

User-provided reference images:

- `~/Downloads/Screenshot 2026-07-14 at 2.58.33 PM.png`
- `~/Downloads/Screenshot 2026-07-14 at 3.02.06 PM.png`

## Required outputs

1. A compact semantic role matrix describing purpose, prominence, color/surface behavior, and non-color indicator.
2. Three realistic snapshots—one per representative surface—using one coherent proposal.
3. A short list of settled principles, remaining questions, and evidence/rationale.
4. Proposed edits to `docs/design-system.md`; do not finalize or migrate until Adrian approves.

## Approval gates

1. **Complete:** Adrian approved the interaction direction and representative snapshots with the single-cue minimalism correction.
2. **Complete:** Cross-product experience principles are in the shared product brain and iOS recipes are in `docs/design-system.md`.
3. **Complete:** `docs/design-decisions.md` and `docs/design-migration.md` exist.
4. **Complete:** The separately authorized Groups 0–5 migration was implemented with visual review between the scoped surface groups; broader app-wide coverage remains separately gated in release closure.

## Suggested skills

- `design-with-taste` for the Family Values craft framework.
- `journey` for the three end-to-end product surfaces.
- `ios-accessibility` for contrast, non-color state, Dynamic Type, motion, and assistive technology behavior.
- `swiftui-liquid-glass` and `swiftui-ui-patterns` when translating approved decisions to native implementation.
- Consider an independent critique pass after the first proposal; do not let an external skill replace the product's own principles.

## Efficiency rules

- Treat repository artifacts as canonical; do not reconstruct this conversation.
- Browse only to answer a named design question.
- Prefer screenshots, matrices, and concise decisions over narrative.
- Do not implement beyond what is needed to make the three snapshots credible.
- End with exact file updates, verification performed, unresolved decisions, and the next action.
