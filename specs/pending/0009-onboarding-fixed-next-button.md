# 0009 — Onboarding: fixed Next-button position

**State:** Todo, not started

## Intent

Update the onboarding flow so the **Next button stays in a fixed position across
all screens** — only the screen content above it changes as the user advances.
Today the button can shift vertically between steps because its position is tied
to the content height; the target is a stable, anchored control the eye can rely
on step to step.

## Acceptance

- The Next (primary advance) button occupies the same on-screen position on every
  onboarding step.
- Only the content region updates between steps; the button does not jump.
- Verify with `make run-fresh` (re-shows onboarding each launch), stepping through
  every screen and confirming the button is pinned.
