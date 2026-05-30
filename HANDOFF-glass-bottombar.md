# Handoff: Bottom-bar glass selection upgrade

**Created:** 2026-05-30 · **Branch:** feat/immersive-video-feed · **Status:** implemented, awaiting on-device test

## Implementation notes (2026-05-30, final)
Done in `GlobalBottomBar.swift` only; `LiquidGlass.swift` reused untouched. Builds clean for iOS Simulator. Call site `VideoFeedView.swift:192` unchanged (same API) — parallax pane gestures + vertical video paging fully intact.

**Layout change:** bar is now a 3-tab glass capsule (Library · Feed · Style) + a **detached Add-Video glass circle** on the right (was a 4th button inside the capsule). Add uses `plus` in `.liquidGlass(in: Circle(), interactive: true)`.

**Selection indicator (the screenshot effect):**
- iOS 26: real glass via `Color.clear.glassEffect(.regular.tint(accent), in: Capsule())` + **`glassEffectID("bottomBarSelection", in: ns)`** inside `GlassCluster` → system morphs it between tabs (clear while travelling → tinted at rest), exactly like the native tab bar. This IS the mechanism the reference screenshot uses.
- < iOS 26: tinted material pill slid via `matchedGeometryEffect`.
- Reduce Motion: drops the shared identity on both paths → cross-fades in place. `.snappy(0.38, extraBounce: 0.12)` travel / `.easeInOut(0.2)` fade.

**Why NOT native TabView (decided with Adrian):** the feed is a custom gesture-driven parallax-pane layout (`feedAndPaneGesture`, `paneProgress`/`stylePaneProgress`), not tabs. Native TabView would replace the left/right parallax pane drag with tap-to-switch — gutting the immersive feel. The glass effect is achievable in the custom bar via `glassEffectID` without that cost, so we kept the custom bar.

**Interactive lift (added after Adrian flagged the press-hold "lens" reference):** active tab's *label* (not a background) uses `.glassEffect(.regular.tint(accent).interactive(), in: Capsule())` + `glassEffectID`. `.interactive()` is what produces the press-and-hold glass lens/bulge. Glass is on the label so the press lands on it. CANNOT be screenshotted (only exists while held) — verify by press-holding on device.
- If lift is absent or too subtle, switch tabs to Apple's `.buttonStyle(.glass)` (purpose-built interactive glass, more pronounced). That's the known fallback.

**To verify/tune on device (iOS 26 esp.):**
- Confirm the clear-while-morphing → solid-tint behavior actually reads (it's system-driven; may need tint strength tuning on `.tint(accent)`).
- Accent-tinted glass + accent icon may be low-contrast — consider white icon when selected.
- Detached Add circle sizing/gap (`Spacing.smPlus`) vs the capsule.

## Goal
Make the `GlobalBottomBar` selected-state feel like the premium apps Adrian
saw: the selected indicator should (1) be glass itself, not a flat tint wash,
and (2) **morph/slide** fluidly from the old tab to the new one instead of
cross-fading static capsules.

## Decision (locked)
**Gate true glass for iOS 26, material-pill fallback for iOS 18–25.** Deployment
target stays **18.0** (do NOT raise it — would cut off most of the install base
pre-launch). 100% of users get an animated selection; iOS 26 users additionally
get real Liquid Glass morphing.

## Current state (what exists)
- `Five67/Views/Shared/LiquidGlass.swift` — clean wrapper already using the real
  native API: `glassEffect` / `GlassEffectContainer` (as `GlassCluster`) on
  iOS 26, `.thickMaterial` fallback below. Architecture is correct; reuse it.
- `Five67/Views/Shared/GlobalBottomBar.swift` — 4 icon buttons in a glass
  capsule (`.liquidGlass(in: Capsule())`, line 46). **The gap:** the selected
  indicator is a static flat fill —
  `Capsule().fill(isActive ? Color.accentColor.opacity(0.16) : .clear)`
  (lines 67–68) — with **zero animation**. `isActive` just flips the fill.

## Why it looks flat vs. other apps
1. Selection is a color wash, not a glass surface.
2. Each tab has its own capsule that fades in/out — no shared, moving indicator.
   Premium apps use ONE indicator that springs + reshapes between tabs.

## Plan / next steps
1. **Pull Apple docs first** (iOS 26 API is at knowledge edge — verify shapes):
   - "Applying Liquid Glass to custom views"
   - `glassEffectID(_:in:)` + `@Namespace` semantics, union/morph behavior
   - confirm it composes inside `GlassEffectContainer` (our `GlassCluster`)
2. **Base path (iOS 18+, all users):** replace the per-button static fill with a
   single shared indicator driven by `matchedGeometryEffect` + a spring
   (`.snappy`/`.smooth`), rendered as a material pill. This is the biggest
   perceived-quality win and ships to everyone. `swiftui-animation` skill covers
   this; writable from memory.
3. **iOS 26 path:** same shared indicator, but as a real glass surface via
   `glassEffectID` inside `GlassCluster` so it morphs as Liquid Glass.
   `@available(iOS 26.0, *)` branch; material pill is the else.
4. Respect `accessibilityReduceMotion` — fall back to a cross-fade when on.
5. Keep existing `.accessibilityAddTraits(.isSelected)` wiring.

## Files to touch
- `Five67/Views/Shared/GlobalBottomBar.swift` (main change)
- `Five67/Views/Shared/LiquidGlass.swift` (maybe add a glass-indicator helper)

## Notes / non-goals
- No new skill needed. The UIKit-Agent-Skill Adrian looked at is wrong framework
  (this app is SwiftUI + SwiftData; UIKit only for haptics/thumbnails/player).
- Do not raise deployment target.
- `GlassCluster` already exists for morphing — reuse, don't recreate.
