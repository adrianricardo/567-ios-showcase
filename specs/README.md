# 567 iOS specs

The folder structure communicates execution state:

```text
specs/
├── pending/   # actionable or proposed work that is not complete
├── done/      # implemented and completed plans
└── archive/   # superseded or closed proposals kept for historical context
```

Keep the numeric identifier and filename stable when moving a spec. Update the
spec's own status line and all live repository references in the same change.

## Pending

| Spec | State | Next interpretation |
|---|---|---|
| `pending/0003-ugc-creator-9.99-sales-test.md` | Approved experiment, not executed | Reconcile the old $9.99 hard-paywall assumptions with the shipped freemium product before implementation. |
| `pending/0004-class-recap-sharing.md` | Draft, not started | Requires cross-repo contract work and a fresh approval before implementation. |
| `pending/0006-release-closure.plan.md` | Waiting for Review as of 2026-09-15 | Build 81 and the lifetime IAP were resubmitted together; check the current App Review outcome and keep manual release gated. |
| `pending/0008-segment-splitting-tutorial.plan.md` | P1 preserved on a feature branch; not merge-ready | Continue P2–P5 on `codex/segment-splitting-tutorial`; `main` was repaired and verified at `8f08b35`. |
| `pending/0009-onboarding-fixed-next-button.md` | Todo, not started | Pin the onboarding Next button to a fixed position so only the content updates between steps. |

## Done

| Spec | Completion |
|---|---|
| `done/0001-video-feed-redesign.md` | Core feed and Style-model work shipped, then evolved through later navigation/design passes. |
| `done/0007-onboarding-core-ui-redesign.plan.md` | All six phases implemented and verified on 2026-07-22. |

## Archive

| Spec | Why archived |
|---|---|
| `archive/0002-revenue-focus-habit-payment-test.md` | Superseded by 0005; retained for product/persona context and historical test reasoning. |
| `archive/0005-freemium-unlock-smart-import.md` | Partially implemented, then superseded by 0006/0007; smart import and iCloud cleanup are not active work. |

## Classification rules

- **Pending** means someone could reasonably pick the work up, although a draft
  or stale approved experiment may require a refresh first.
- **Done** means the implementation plan reached its completion criteria.
- **Archive** means do not implement the document as written. It remains useful
  evidence or decision history.
- A spec awaiting an external terminal outcome remains **pending** until that
  outcome and any required follow-up are recorded.
