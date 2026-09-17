# Design: 567 update 0005 — Freemium Unlock + Smart Location Import + iCloud Cleanup

Generated 2026-07-07 via InterviewMe. Branch: `main`. Repo: `567-ios`.

**Status: ARCHIVED — partially implemented, then superseded.** The StoreKit
unlock and first onboarding implementation shipped through later plans, while
the 10-video cap and onboarding were replaced by
`specs/done/0007-onboarding-core-ui-redesign.plan.md`. Smart location import and
iCloud cleanup are not active implementation work.

This spec historically **superseded
`specs/archive/0002-revenue-focus-habit-payment-test.md`**. It kept 0002's core
thesis (fix import friction → drive a repeat-use habit) but proposed a **larger,
monetized build**: a real in-app freemium unlock, a smarter location-based
import trigger, and the iCloud cleanup flow that 0002 explicitly deferred. Read
0002 §0 for full product/persona context; it is not repeated here.

> **Handoff note:** self-contained. A second agent should be able to build from this top-to-bottom. The one thing needing Adrian's explicit sign-off before code is **§2 — the reversals from 0002** (payment is back; the test is no longer a clean single-variable retention read).

---

## 1. What we're building (one paragraph)

Turn 567 from a free on-device utility into a **freemium app**: a conversion-style onboarding ends in a **one-time $6.99 StoreKit unlock**; the free tier is capped at **10 videos in the library and 1 active dance style**; paying unlocks **unlimited videos, unlimited styles, and the iCloud cleanup flow**. The return/import experience is driven by a **smart location-based import popup**: once a user has imported at least one video, 567 watches (on foreground) for recent un-imported Photos videos shot at the **same location** as a known class video and proactively offers to import them. This replaces 0002's after-class notification + 72h auto-inbox + class-night capture entirely.

---

## 2. ⚠️ Reversals from spec 0002 — SIGN-OFF REQUIRED

These were deliberate decisions in 0002 (several in its authoritative §16 revision) that this spec **overturns**. Logged explicitly so nothing is silently overwritten. All confirmed by Adrian 2026-07-07 unless noted.

| # | 0002 decision | 0005 change | Consequence |
|---|---|---|---|
| R1 | §16: **payment dropped** — "single-variable test: do dancers form a habit once friction is gone." | **Payment reinstated** as the core model. | This is now a **freemium conversion test**, not a pure retention test. |
| R2 | §8/§13: payment was **out-of-band Venmo/cash, no in-app gate**, StoreKit deferred. | **In-app StoreKit 2 non-consumable**, real freemium cap. | **StoreKit back on the critical path** (§16.4 had removed it). App Store IAP review rules now apply. |
| R3 | §8 A step 5: **app stays fully usable, no hard lock** (so a cap can't confound retention). | **Free tier is capped** (10 videos / 1 style). | The cap gates usage. The formal cohort-*test* framing was later **dropped** (2026-07-08, §7), so the cap is now a plain product lever, not a measurement confound. |
| R4 | §9b: iCloud cleanup (move to iCloud + delete from Photos) **explicitly out of scope** until the loop is proven. | **iCloud cleanup is in scope**, as a **paid-tier feature**. | Pulls §9b's net-new surface (iCloud Drive container, copy-out-then-delete, PhotoKit deletion) into this build. |
| R5 | §8/§9a/§13: trigger = **self-set after-class local notification** + **72h auto-present inbox** + **class-night capture** in onboarding. | **All three dropped.** Replaced by the location-based smart popup (§5). | **No push/return trigger at all** — the smart popup is foreground-only (§5.4). Re-engagement is weaker; the retention read reflects this. Accepted. |

**Everything else from 0002 carries forward** — the ~80% code reuse (import, dedupe, save-now-clip-later, trim editor, loop, style, library, SwiftData stack per 0002 §9a), the manual in-person cohort recruiting (0002 §12/§14), and the "watch, don't demo" discipline (0002 §14).

**Codex adversarial review (2026-07-08) — fixes absorbed.** A second-opinion pass argued for deferring monetization entirely; Adrian **held** the freemium plan and $6.99 price, but absorbed four refinements: **(A)** grandfather existing v1.0 users (§3); **(B)** onboarding seeds a **single** video so the free cap is never hit during onboarding (§4 beat 8) — Adrian's tightening of Codex's "starter-batch" idea; **(C)** recency-led / location-ranked surface with a quiet fallback so the trigger doesn't silently die when GPS is missing — **softens R5** (§5); **(D)** split the conflated success metric (§7). Full critique + accept/override map: `docs/onboarding-0005.md` §C–D.

---

## 3. Free vs. Paid

**Free tier**
- Up to **10 videos in the library at any one time** (a "slot" model — deleting a video frees a slot, so it's not a hard lifetime cap). *(Set to 10, not 3, so the free tier feels like a real starter library (~a month of classes) and the cap-hit lands when the library is genuinely valuable — not right after onboarding. Trivially tunable; the 1-style gate below is the primary early trigger anyway.)*
- **1 active dance style.**
- Full import, clip/name, loop, feed, smart surface — all available within the caps.

**Grandfathering (existing v1.0 users) — fix A.** v1.0 shipped free & unlimited; gating those installs is punitive and an App Store / trust risk. On first launch of the freemium version, grant a permanent local **legacy-unlimited** entitlement if **either**: (1) the App Store receipt's `originalApplicationVersion` predates the freemium version, **or** (2) a non-empty library is detected at migration. Only genuinely new installs ever see a cap. Persist the legacy flag durably. **Scope the receipt check to the production environment** — in sandbox/TestFlight `originalApplicationVersion` reports as `1.0`, which would falsely grandfather every tester (Fable #2). Because the existing cohort is grandfathered, validate the paid unlock with **fresh App Store installs**.

**One-time unlock — $6.99** (StoreKit 2 **non-consumable**; Small Business Program 15%; **Family Sharing enabled**)
- **Unlimited videos.**
- **Unlimited dance styles.**
- **iCloud cleanup flow** (§6) — the tangible upgrade value beyond "unlimited."
- **Restore Purchases** on the paywall + Settings; entitlement from `Transaction.currentEntitlements`, durable across reinstall/device migration.

**Paywall triggers**
1. Onboarding paywall beat (skippable — §4 beat 11). **Never triggered by the seed import** — onboarding seeds a **single** video (fix B), so the free cap is never hit during onboarding.
2. **2nd-style gate (earliest, primary trigger):** tagging a video to a **second** dance style shows the paywall. Fires in week 1 for multi-style dancers (the Latin-scene norm), so it's the main conversion lever. The style-tag prompt hands off to the paywall **gracefully** — not a jarring metadata→paywall jump.
3. **Video cap-hit (secondary):** importing an 11th video while 10 exist. Catches single-style heavy users.

---

## 4. Onboarding (approved 2026-07-07; refined via /app-onboarding-questionnaire)

Full conversion flow, **social proof removed**, **no account step**, **no notification priming** (notifications dropped, R5). Adapts the proven 14-screen archetype framework to 567's locked decisions. Final 12-beat flow:

1. **HOOK** — "Your class videos finally have a home." Brand + one line; preview of the app in use.
2. **VALUE-PROP SURVEY** (multi-select — Adrian's "yeah, yeah" survey): _"What do you want 567 for?"_ e.g.
   - "Remember the moves I've learned for social dancing"
   - "Have a place to practice moves I'm working on"
   - "Keep my class-video library organized"
   - (2–4 more in the same voice). Selection personalizes/primes; not functionally gating.
3. **PAIN** — 1–2 tap-through cards: videos pile up in the camera roll, never watched again.
4. **PERSONALIZE** — which styles do you dance? (salsa / bachata / cumbia / …). Multi-select is **priming only** — it does *not* grant multiple active styles. Free tier = **1 active style**; tagging a video to a 2nd style later triggers the paywall (§3).
5. **PERSONALIZE** — how many class videos are rotting in your camera roll? (quantifies the pain).
6. **PAYOFF** — show a saved, named, looping move — the "after" state.
7. **PERMISSION** — prime + request **full Photo Library** access, in context (the only permission primed here).
8. **SEED IMPORT (single video)** — "pick **a** video from your recent classes" (fix B). Import **one** recent clip — within the free cap, so onboarding never hits the paywall — seeding both the library and the location model. (9 free slots remain to fill later.)
9. **CLIP-AND-NAME DEMO** — drop the user into the **real, full trim/label editor** (`VideoDetailView` / `TrimTrackView`) on one of their just-imported videos. **Full UI — they can name as many moves in the video as they want, not an artificial one-move cap.** This is the functional demo (skill archetype #11): the user *does* 567's core magic — clip + name a move — and leaves with real named moves, not just imports. Encouraged but skippable ("I'll do this later").
10. **PROCESSING MOMENT** — 1–3s "Building your library…" animation before the reveal, so the result feels earned/personalized (skill archetype #10).
11. **PAYWALL** — $6.99 one-time unlock, **"Pay once, yours forever"** framing: unlimited videos + styles + iCloud cleanup, anti-subscription angle. **Skippable** to the free tier.
12. **LAND** on the populated feed/library showing their named moves.

**Notes:** Paywall (beat 11) lands *after* the seed import + clip-and-name, once real value is felt — but the seed is a **single** video, so the cap is **never hit during onboarding** (fix B); the beat-11 paywall is a soft, skippable ask, and the real cap-hit conversion moment comes later on a normal import. Save-now-clip-later still holds in-app; the clip beat is a *taste*, not a gate. Every screen before the payoff (6) fights 0002's founding thesis (§3: anything that doesn't beat "leave it in Photos" on effort loses) — keep beats 1–5 tight.

**Deliberately excluded archetypes (logged so they aren't "missing" by accident):** social proof (removed by Adrian), comparison table (declined), mirror-solution screen (declined), account creation (on-device app, no accounts), viral/share moment (567 has no shareable artifact — that's the deferred Approach C), notification priming (notifications dropped, R5).

---

## 5. Smart location-based import popup (net-new, the trigger)

Replaces 0002's notification + 72h inbox (R5). The mechanism that makes 567 feel like it *knows* when you've been to class.

**5.1 Behavior (recency-led, location-ranked — fix C)**
- On app **foreground**, gather **candidate** videos: **un-imported** Photos videos from the **last 7 days** (optionally duration/portrait-filtered).
- **When a candidate carries GPS that matches a known class venue** (a previously-imported video's location, within ~150 m), **proactively auto-present** the strong popup: *"New class videos from [venue area]?"* — the magic moment.
- **When candidates lack GPS** (camera location off, indoor studios — common), don't disappear: surface them through a **quiet recency nudge** (a subtle badge/prompt), not an aggressive popup.
- So location decides **how aggressively** to surface, never **whether** the user sees anything. The trigger **degrades gracefully** instead of silently dying (Codex #3).
- Silence only when there are genuinely no un-imported recent candidates.
- **Cap-aware (Fable #5):** for a free user, offer at most *remaining-slots* candidates plus a quiet "+N more with unlimited" line. **Never** pop the paywall from inside the suggestion popup — the delight feature must not become the nag feature.

**5.2 Requirements**
- **Full PhotoKit** (`PHAsset` / `PHFetchResult` / `PHPhotoLibrary` authorization) — established by onboarding screen 7. Beware the **limited-access trap** (0002 §9a #1, §13): a `creationDate` fetch under *limited* access returns only granted assets; must request **full** and guide the user if only limited is granted.
- Candidate location from `PHAsset.location` (`CLLocation`); known-class locations stored per imported `Video` (net-new field — persist the source asset's location at import time). SwiftData migration safety per repo CLAUDE.md — needs a focused test or manual verification note.

**5.3 Defaults (tunable)**
- Recency window: **7 days.**
- "Same location" radius: **~150 m** (venue-scale; tune against real data).
- **Dedupe / no-nag:** never re-surface a candidate the user dismissed or already imported. A per-candidate dismissed set.

**5.4 Known limitation — foreground only (accepted, R5)**
Still true: `PHPhotoLibraryChangeObserver` only runs while the app is open; iOS won't reliably permit background scanning to fire a push. Nothing *pushes* the user back in. The recency fallback (5.1) makes the surface robust **once they're in**, but does **not** create a return trigger. Re-engagement remains the accepted weak point; §7 measures it honestly (fix D).

**5.5 Cold-start**
The onboarding **single-video seed (§4 beat 8)** gives ≥1 known location for GPS matching. Before any location is known — or for users whose videos never carry GPS — the **recency fallback** still surfaces recent un-imported clips, so the feature is useful from session 1.

---

## 6. iCloud cleanup flow (paid feature, was §9b)

Now in scope (R4), gated behind the unlock. Fulfills the brand promise literally: "your class videos finally have a home" — backed up, organized, off the camera roll.

**Flow**
- Optional, user-initiated (or offered contextually after a save). Move the **full-res source** into the app's **iCloud Drive** folder, **auto-filed by `style`** (Salsa / Cumbia / …), then offer to **delete the original from Photos** (system confirm dialog; recoverable from Recently Deleted for 30 days).
- **"Do not show again"** toggle on the prompt.
- **iCloud quota pre-check (Fable #6):** the target user is often on the free 5GB iCloud tier (0002 §9b — they abuse Shared Albums to dodge storage costs). Moving full-res video into iCloud Drive consumes **their** quota. Before archiving, check available quota and show honest copy ("this uses your iCloud storage") so they aren't blindsided by an "iCloud full" error after paying.

**Why it's low-risk (verified in 0002 §9b against the code):** the app **already owns a full-res copy** — `VideoImporter.ingest` copies into `Documents/videos/`; playback reads `Video.fileURL`, not the PHAsset. So deleting the Photos original is safe; the feed keeps playing. `Video.sourceAssetID` locates the original for deletion; `Video.style` gives the destination folder.

**Net-new surface:** iCloud Drive container/folder management per style, copy-out-then-offer-delete flow, PhotoKit deletion. iCloud Drive folders (private by default, full quality) — **not** Shared Albums (compressed to 720p, and PhotoKit forbids apps adding to them) — per 0002 §9b decision.

---

## 7. Product signals (informal — formal cohort *test* dropped 2026-07-08)

The 4–6 week cohort-test framing inherited from 0002 is **dropped** (Adrian, 2026-07-08: *"forget about the test"*). 0005 ships as a **freemium product**, not a measured experiment, so there are **no hard success bars** — and Fable's cap-vs-activation contradiction dissolves along with the metric it corrupted. A few lightweight signals still worth watching, informally:

- **First-session value:** users import a video or two and name a move (the aha is clip + name).
- **Return:** users reopen unprompted and keep saving/looping. **Caveat (fix D + R5):** the app has **no push return trigger** — foreground-only (§5.4), nothing *causally* drives reopening — so weak return reads as *"no trigger existed,"* not *"no habit."* Don't over-read it.
- **Suggestion acceptance:** when a returning user is offered a recent/nearby video by the smart surface, do they take it.
- **Conversion:** free users who hit the video cap or the 2nd-style gate and buy the $6.99 unlock. Requires **fresh App Store installs** (sandbox/TestFlight can't collect real money and grandfathers as legacy — §3).

---

## 8. Dependencies & build order

Net-new work, roughly sequenced:

1. **Full PhotoKit access** + limited-access handling (foundation for §5 and §6). — 0002 net-new #1.
2. **Persist source-asset location** on `Video` at import (SwiftData migration + test). Enables §5.
3. **Smart surface** (§5) — foreground scan, recency candidate set + location match/rank, quiet fallback vs. auto-popup, dedupe, one-tap import (reuses existing importer). **Cap-aware** for free users (≤ remaining slots; no in-popup paywall). Keep manual PhotosPicker import working under *limited* access.
4. **StoreKit 2 non-consumable** $6.99 unlock + ASC product + Small Business Program (15%) + Family Sharing. Entitlement from `Transaction.currentEntitlements`; **Restore Purchases** (paywall + Settings); **grandfathering** (fix A — legacy-unlimited via receipt `originalApplicationVersion` **checked in the production environment only**, or existing-library detection). Validate the paid unlock with **fresh App Store installs**. Use the `app-store-review` skill for IAP/review rules.
5. **Freemium caps** — 10-video slot enforcement + 1-active-style enforcement (**2nd-style tag → paywall**, the primary early trigger) + cap-hit paywall. Legacy-unlimited and the single-video onboarding seed both bypass the cap. Slot-model copy: **no "delete a video instead"** (it destroys named moves); if deletion stays possible, warn "deletes N named moves." Cap counts videos-with-their-moves (intentional).
6. **Onboarding** (§4) incl. value-prop survey + seed step. — 0002 net-new #4 (now full-conversion-minus-social-proof).
7. **iCloud cleanup** (§6) — paid-gated, with an iCloud **quota pre-check** + honest storage copy. — was 0002 §9b, deferred; now in.

**Reused as-is** (0002 §9a): multi-select import, dedupe, `recordedAt`, save-now-clip-later, trim editor, loop playback, style tagging, library pane, SwiftData stack, one-code-path nav.

**Preserve:** SwiftData migration safety; one code path per action; no parallel state machines without written approval (repo CLAUDE.md).

### Build log

**2026-07-08 — item 6 (onboarding §4) implemented** (Codex build, Claude-reviewed; uncommitted pending Adrian's pass). All 12 beats with `docs/onboarding-0005.md` §B copy; gate = completion flag unset AND empty library (v1.0 users never see it); seed import reuses the shared importer path (`VideoImportPersistence`, also adopted by the feed — one code path); real `VideoDetailView` editor as beat 9; minimal StoreKit 2 `UnlockStore` (product `com.nopalstudio.five67.unlock`, purchase/restore/`currentEntitlements`, graceful no-product degradation) + local `.storekit` config in the run scheme. `make build` + `make test` green (16 tests, incl. new gating/preferences tests). No schema changes.

**Follow-ups from item 6:**
1. **App Store Connect:** create the non-consumable `com.nopalstudio.five67.unlock` at $6.99, Family Sharing ON; confirm Small Business Program enrollment (also §9) before pricing goes live.
2. **Payoff/hook assets:** beats 1 and 6 use placeholder mocks (gradient phone preview / looping-move card). Replace with a real branded looping-move asset before external installs.
3. **UnlockStore test coverage:** no StoreKitTest-based entitlement tests yet; entitlement mapping is compile-verified only. Add when StoreKit work continues in item 4 (grandfathering will need the harness anyway).
4. **Limited-access hint is unreachable:** the permission beat's "limited is okay" note can't render (flow advances immediately after the system prompt). Harmless now (picker is limited-safe); fold proper limited-access guidance into item 1/3 (§5.2's empty-inbox explainer).
5. **Fresh-install QA pass:** run onboarding end-to-end on a clean install (delete app first — completion flag + library must be empty), including the `.limited` grant path and paywall with/without the local StoreKit config.
6. **Remaining build order untouched:** items 1–5 and 7 (full-Photos foundation, location persistence, smart surface, StoreKit grandfathering, cap enforcement, iCloud cleanup) still to build — the paywall currently *sells* unlimited/styles/cleanup but nothing is gated yet, so don't ship to real users before item 5 (caps) exists or the unlock is a no-op purchase.

---

## 9. Open questions (post-sign-off)

- **Value-prop survey copy** — final list/voice of the props (§4.2); Adrian to supply the exact lines.
- **Paywall copy & design** — the $6.99 screen; mock before build.
- **Cap-hit UX** — exact wording when a free user tags a 2nd style / imports an 11th video (soft, encouraging, not punitive).
- **Smart-popup tuning** — radius/recency defaults (§5.3) against real Photos data; portrait/duration heuristics if location alone is too noisy.
- **iCloud cleanup trigger point** — user-initiated only, or also contextually offered after a save? (§6.)
- **Enrollment check** — confirm Small Business Program (15%) is active before pricing goes live.


---

## Decision log

**2026-07-07 (InterviewMe, Adrian):** Chosen over the lean 0002 §16 variant. Locked: location popup **replaces** notification + 72h inbox + class-night capture (R5); **gated freemium** reversing §16 (R1–R3); onboarding = **full conversion flow minus social proof**, + early **value-prop survey**, approved; iCloud cleanup = **paid feature** (R4); return trigger = **foreground-only, accepted**; price = **$6.99** non-consumable; cap = **3 videos in library at once (slot model) + 1 active style**; first-import via **onboarding seed step**; candidate recency = **last 7 days**.

**2026-07-08 (Codex review, Adrian):** Ran an adversarial Codex second opinion (verdict: "defer monetization, prove habit first" — full critique in `docs/onboarding-0005.md` §C). Adrian **held the freemium plan** and **held $6.99 one-time**, absorbing four fixes: **A** grandfather v1.0 users (receipt `originalApplicationVersion` OR existing-library detection); **B** onboarding seeds a **single** video so the cap is never hit in onboarding (Adrian's tightening of Codex's "starter-batch" idea); **C** recency-led / location-ranked surface with a quiet fallback so the trigger doesn't die on missing GPS (softens R5); **D** split the conflated success metric into return-rate vs. suggestion-acceptance. Also folding in: Restore Purchases + durable entitlement, Family Sharing on the unlock, and limited-access-safe manual import + on-device-only location processing (keeps v1.0 "no data collected" true).

**2026-07-08 (Fable review, Adrian):** A Fable third opinion caught two things Codex + Claude missed — the cap-3 / activation-3 collision, and the TestFlight-grandfathering flaw that empties the paid arm (full critique: `docs/onboarding-0005.md` §E). Adrian's resolutions: **dropped the formal cohort-*test* framing entirely** ("forget about the test") → 0005 ships as a freemium product, §7 is now informal signals, and the cap contradiction dissolves with the metric it corrupted; **raised the free video cap 3 → 10** (product feel — a 3-item library is stingy and walls users right after onboarding); **recruit fresh App Store installs** for the paid read + **production-scoped** grandfather receipt-check; **kept R5** (no push; a flat return reads as "no trigger," not "no habit"); **kept the 1-style gate** as the primary early trigger (2nd-style tag → paywall, graceful handoff); **kept iCloud cleanup in** but added a **quota pre-check** + honest storage copy; made the **smart popup cap-aware**; fixed **slot-model copy/semantics** (removed "delete a video instead," which destroys named moves). Overrode Codex/Fable on deferring monetization, restoring the notification, and cutting the style gate.
</content>
