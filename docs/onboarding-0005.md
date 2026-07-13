# 567 — Onboarding & Freemium Copy (spec 0005)

Companion to `specs/0005-freemium-unlock-smart-import.md`. Holds the screen-level blueprint, draft copy, and the Codex second-opinion critique. Generated 2026-07-07 via `/app-onboarding-questionnaire` + a Codex adversarial review.

**Status: DRAFT.** Copy is first-pass. Codex flagged serious strategic risks (§C below) — several conflict with decisions Adrian locked 2026-07-07 and need a conscious accept/override before build.

---

## A. The 12-beat blueprint

Full conversion flow, **social proof / accounts / notifications / share-moment removed**. See spec 0005 §4 for rationale.

| # | Beat | Purpose |
|---|------|---------|
| 1 | Hook | Show the end state; create desire |
| 2 | Value-prop survey (multi-select) | Self-identify what they want 567 for |
| 3 | Pain cards (1–2, tap-through) | "This app gets me" |
| 4 | Styles (multi-select) | Personalize |
| 5 | Volume (single-select) | Quantify/amplify the pain |
| 6 | Payoff | Show a named, looping move — the "after" |
| 7 | Permission — full Photo Library | In-context primer + system request |
| 8 | Seed import (**single video**) | First import (1 clip, stays under the cap); seeds library + location model |
| 9 | Clip-and-name demo (real editor) | Do the core magic on that video; leave with real named moves |
| 10 | Processing moment (1–3s) | Make the result feel earned |
| 11 | Paywall — $6.99 "pay once" | Convert (skippable to free tier) |
| 12 | Land | Populated feed of their named moves |

---

## B. Draft copy (Phase 4, first pass)

**1 · HOOK**
> **Your class videos finally have a home.**
> Turn the dance clips buried in your camera roll into a move library you'll actually practice.
> `[Get started]`

**2 · VALUE-PROP SURVEY** *(multi-select — "pick all that fit")*
> **What do you want 567 for?**
> 🧠 Remember the moves I've learned
> 🔁 Practice the moves I'm working on
> 🗂️ Keep my class videos organized
> 💃 Stop losing steps between classes
> 🎯 Actually review what I record
> `[Continue]`

**3 · PAIN** *(2 tap-through cards)*
> ① "You record every class… and never watch them again."
> ② "A week later the move's gone — and the video's lost in 2,000 camera-roll clips."
> `[That's me]`

**4 · STYLES** *(multi-select)*
> **What do you dance?**  *So your library speaks your styles.*
> Salsa · Bachata · Cumbia · Kizomba · Zouk · Merengue · Other
> `[Continue]`

**5 · VOLUME** *(single-select — quantifies the pain)*
> **How many class videos are sitting in your camera roll right now?**
> A handful (1–10) · A stash (10–50) · A graveyard (50+) · I've lost count
> `[Continue]`

**6 · PAYOFF** *(show a named move looping)*
> **This is what they become.**
> Clipped. Named. Looping. Ready to practice in seconds.
> `[Show me how]`

**7 · PERMISSION — Full Photo Library**
> **Let's find your class videos.**
> • Pulls your dance clips straight from Photos — no hunting
> • Everything stays on your device. Private by design.
> • We only touch the videos you choose to save
> `[Connect my videos]`  ·  `Not now`
>
> *Must request **full** access; if only limited granted → empty-inbox explainer + path to grant more. Manual picker import must still work under limited access (Codex #14).*

**8 · SEED IMPORT** *(single video — fix B; stays at 1/3, never trips the cap in onboarding)*
> **Pick a video from your recent classes.**
> Start with one — we'll turn it into your first moves.
> `[Save this video]`

**9 · CLIP-AND-NAME DEMO** *(real full trim/label editor on one imported video)*
> **Now make your first move.**
> Trim to the good part, give it a name. Add as many as you want.
> `[Save move]` … `[Done]`  ·  `I'll do this later`

**10 · PROCESSING** *(1–3s)*
> **Building your library…**

**11 · PAYWALL — "pay once, yours forever"**
> **Pay once. Yours forever.**
> Unlock unlimited moves — no subscription, ever.
> ∞ Unlimited videos  ·  🎨 Unlimited styles  ·  ☁️ iCloud cleanup (back up & clear your camera roll)
> `[Unlock 567 — $6.99]`  ·  `Maybe later`  ·  `Restore purchase`

**12 · LAND** → into their populated feed of named moves. Toast: *"Your library's ready."*

**Cap-hit paywall** *(primary trigger = tagging a 2nd dance style; secondary = importing an 11th video)*
> **2nd-style trigger:**
> **Unlock your second style?**
> 567 free covers one dance style. Unlock unlimited styles + videos for $6.99 — pay once.
> `[Unlock — $6.99]`  ·  `Keep it in [Style 1]`
>
> **Video-cap trigger:**
> **You've filled your 10 free video spots.**
> Unlock unlimited for $6.99 — pay once, keep everything.
> `[Unlock — $6.99]`  ·  `Maybe later`
>
> *(No "delete a video" option — deleting a video destroys its named moves. Fable #4.)*

---

## C. Codex second opinion (adversarial, 2026-07-07)

Codex (gpt-5.5) read both specs + the App Store review skill and searched Apple's IAP guidelines. **Verdict, verbatim:** *"yes, the freemium pivot is wrong for this stage as specified. The paid unlock may be worth testing soon, but 0005 overloads the build and weakens the core habit test. The sharper plan is: prove return with a recent-video inbox plus real reminder, keep onboarding lean, avoid seed-session paywall friction, then test a higher paid unlock once users have actually built libraries."*

The 15 findings, most-fatal first:

1. **Monetizing before habit exists is the core error.** 0002's insight (the denominator is unprompted repeat use) still holds. Ship the friction/trigger test first; add payment after 2–3 weeks of observed returns.
2. **Foreground-only popup is not re-engagement** — it only helps users who already opened the app, so it doesn't solve "I forget to log videos." Calling it "the trigger" is a category error. Restore a first-class return trigger (user-set class reminder → deep-link to inbox); keep the location popup as a foreground *assist*.
3. **Location matching is too brittle to carry the loop** — many class videos lack usable GPS (camera location off, indoor drift, saved/shared videos). Lead with a *recency* inbox (last 24–72h + duration threshold); use location only to **rank/label** candidates, never to decide if the user sees anything.
4. **3-video cap is too tight for an archive tool** — value compounds only once there's material to organize. Alternative: 7/14-day unlimited trial then cap; or cap *saved moves* not raw videos; or raise slots to 7–10.
5. **Slot model breeds delete-to-reuse** — "3 at once, deletable" teaches churn, which is anti-positioning for "finally have a home." Make free generous enough to preserve the archive metaphor; gate *scale*.
6. **One-style gate is weak** — many users only dance one style; style is metadata, not obvious premium value. Use as soft upsell, not primary gate.
7. **Onboarding is overbuilt for a tiny in-person cohort** — every pre-import screen fights the Photos status quo. Cut to: promise → Photos primer → recent videos → import → loop → optional name-one-move → land. Use Adrian's in-person narrative for the rest.
8. **Real editor in onboarding is high-risk friction** — the aha is "this is now easy to find and loop," not "I operated the editor." Make clip/name a post-import prompt with a guided default, not a required beat.
9. **No paywall during seed import** — if selecting >3 in onboarding immediately hits the paywall, it reads as bait-and-switch before any habit. Import the onboarding selection under a "starter batch" exception; enforce the cap on *future* imports only.
10. **$6.99 one-time is underpriced and structurally can't reach the goal** — $500/mo ≈ 85 buyers/mo; $3–5k/mo ≈ hundreds/mo, which a local cohort won't sustain. Either treat as small paid validation (not the business model) or test higher ($14.99–$24.99 one-time, or $19.99/yr for backup/cleanup).
11. **iCloud cleanup is dangerous to bundle into the first monetized release** — file movement + iCloud entitlements + PhotoKit deletion + review scrutiny; not needed to prove the loop. Defer it; first unlock = unlimited library only.
12. **Existing v1.0 users need grandfathering** — gating previously-free unlimited behavior is punitive and risks support/review blowback. Grant a legacy entitlement to installs before version X; never lock videos/moves they already imported. *(NEW — not in the spec.)*
13. **StoreKit needs a complete restore/entitlement story** — Restore Purchases, `Transaction.currentEntitlements`, cap behavior across reinstall/device migration, family-sharing decision, sandbox review path, App Review notes.
14. **Full-Photos + location matching has privacy-copy risk** — paid functionality must not depend on granting broad data access; keep manual picker working under limited access; phrase full access as powering suggestions; keep location processing on-device and say so.
15. **Success criteria are internally conflicted** — "smart-popup works" requires the user to return first, but the popup doesn't *cause* return, so it can't prove "the trigger earns the return." Separate the metrics: reminder/open rate, inbox import rate, location-suggestion acceptance, week-3 unprompted return.

Source checked: Apple App Store Review Guidelines — https://developer.apple.com/app-store/review/guidelines/

---

## D. Codex findings vs. Adrian's locked decisions — what to resolve

Mapping each finding to whether it re-opens a decision Adrian already made or raises something new.

**Already decided by Adrian 2026-07-07 (Codex dissents; needs conscious accept/override):**
- #1 monetize-before-habit → Adrian knowingly reversed §16 to a freemium test (R1). Codex wants it deferred.
- #2 foreground-only-isn't-a-trigger → Adrian accepted foreground-only (R5). *(Note: Claude flagged this exact risk before Adrian chose it.)*
- #4/#5 cap size + slot model → Adrian chose 3-in-library slots.
- #8 editor-in-onboarding → Adrian explicitly asked for the full editor as beat 9.
- #11 iCloud cleanup in first paid release → Adrian chose it as the paid-tier value (R4).

**Resolution (Adrian, 2026-07-08):** Held the freemium plan and **held $6.99** (Codex's "defer / price up" verdict overridden knowingly). Adopted four fixes, now folded into spec 0005:
- **A (was #12) — grandfather v1.0 users:** ADOPTED. Legacy-unlimited via receipt `originalApplicationVersion` OR existing-library detection. Only new installs see the cap.
- **B (was #9) — no cap-hit in onboarding:** ADOPTED, tightened. Rather than a "starter-batch exception," **onboarding seeds a single video** (1/3) — respects the cap and still demos the editor. Cleaner.
- **C (was #3) — recency-led, location-ranked:** ADOPTED. Location auto-pops on a GPS match; a quiet recency nudge covers missing-GPS videos so the trigger never silently dies. Softens R5 (Adrian's explicit nod).
- **D (was #15) — split success metric:** ADOPTED. Return-rate vs. suggestion-acceptance, separated; the circular "trigger works" bar removed.
- **#13 restore/entitlement + #14 privacy copy:** folded in as build requirements (Restore Purchases, durable entitlement, Family Sharing on; limited-access-safe manual import; on-device-only location keeps "no data collected" true).

**Overridden (kept as-is despite Codex dissent):** #1 monetize-now, #2 foreground-only trigger, #4/#5 cap size + slot model, #6 style gate, #7/#8 editor-in-onboarding, #10 price, #11 iCloud cleanup in first paid release.

---

## E. Fable third opinion (independent, 2026-07-08)

A Fable-model pass read both specs + this doc's §C/§D and was asked to find what Claude *and* Codex missed, and to judge the founder's overrides on their merits (not pile on). **Verdict:** *"The freemium held-line is more defensible than Codex allowed, but three locked numbers (cap 3, activation 3, week-3 still-saving) form a contradiction that will corrupt the test's read, and the grandfathering-on-TestFlight interaction means the conversion arm may have no real subjects — fix those two and the plan is buildable; ship R5 as-is and you'll misread the result."*

**New findings both prior reviews missed:**

1. **⚠️ The locked numbers are mutually exclusive.** Activation = "import ≥3 videos in session 1"; free cap = 3 videos. So **every activated free user is at cap from day 1** — and the week-3/4 retention bar ("open unprompted *and still saving/looping*") then can't be met without paying or deleting. You won't be able to tell "no habit" from "cap blocked the habit." **Fix:** raise the cap to ~10–12 (a month of classes), **or** redefine activation as "name ≥3 **moves**" (moves, not videos — one seeded video supports it and it measures the actual magic). One number must move before code.
2. **⚠️ The conversion test may have ~zero payable subjects.** (a) TestFlight purchases are **sandbox = not real money**, so a "real $6.99 paid" read needs the App Store build (every iteration behind App Review). (b) In sandbox the receipt's `originalApplicationVersion` reports **"1.0"**, so grandfather-fix-A condition 1 marks **every TestFlight install legacy-unlimited**. (c) The existing-library condition exempts the current testers 0002 §10 folds into the cohort. Net: unless Adrian recruits **fresh App Store installs**, the paid test he held against Codex has almost no treatment group. **Fix:** decide the channel now; scope the receipt check to the production environment; count cap-eligible/payable members in advance — if under ~10, the conversion read is theater.
3. **Foreground-only trigger — Codex was right; this is the wall.** R5 deletes the only mechanism for the founder's own founding problem ("I forget to log recent videos"), and §7 now admits nothing causally drives the return metric. Reversal is ~1 day (self-set class-night local notification, already spec'd in 0002 §9a #2, no backend, doesn't touch the smart surface). **Fix:** restore it as a companion to the foreground assist — or pre-commit to reading a failed return metric as "no trigger existed," not "no habit."
4. **Slot model destroys the artifact.** `Video` 1..* `Move`: deleting a video to free a slot **deletes its named, trimmed moves**. The cap-hit copy literally offers `Delete a video instead` — the app inviting you to destroy the library it promised to home. Also: cap is on *videos* but value is *moves* (a free user with 3 videos + 30 moves is uncapped forever). **Fix:** remove "delete a video instead" from copy; if deletion stays, warn "deletes N named moves"; write down that the cap is videos-with-moves and that's intentional.
5. **Smart popup offers free users what they can't accept.** Post-onboarding the popup surfaces N recent candidates; accepting >2 hits the paywall — the delight feature becomes the nag feature on first contact. **Fix:** free users see at most (remaining slots) candidates + a quiet "+N more with unlimited"; never pop a paywall from inside the magic popup.
6. **iCloud cleanup has a quota trap.** 0002 §9b says the target user abuses Shared Albums *to dodge iCloud storage costs* — i.e. they're on the free 5GB tier. Moving full-res video into iCloud Drive consumes **their** quota; a semester blows past 5GB → "I paid $6.99 and it says iCloud is full." **Fix:** ship unlimited-only first; fast-follow cleanup with a quota pre-check + honest copy; don't list it on the paywall before it exists (selling undelivered functionality = review/trust problem).
7. **1-style gate contradicts onboarding beat 4** (a *multi-select* "what do you dance?"), and the auto style-tag prompt after import means a dancer's 2nd-style video hits a paywall from a metadata prompt in week 1 (back-to-back multi-style classes are the Latin-studio norm). **Fix:** cut the style gate — cheapest override to reverse, near-zero conversion pressure, removes a class of edge cases.

**Where Fable defends the founder against Codex:**
- **Editor-in-onboarding:** founder wins — Codex's friction argument is for anonymous funnels; this cohort is onboarded in person, the beat is skippable, and the aha genuinely is clip+name. Keep it; instrument skip rate.
- **Monetize-now:** founder mostly wins — a *skippable* paywall doesn't confound retention; the real confound Codex should have named is the **cap**, not the price. Keep paywall, loosen cap.
- **$6.99:** defensible as a probe (validates the unit, not volume). But **decide in writing now** that this SKU is a probe that won't survive to scale — every lifetime unlock sold is a customer excluded from the future recurring model the 12-month goal requires.



**Fable's sharpest single question:** *A free user who hits your activation bar is at cap from day one — so for weeks 2–6, every save costs $6.99 or a deleted set of named moves. Which metric are you willing to let that user fail: activation, week-3 retention, or the "home for your videos" brand — and if none, which of the three locked numbers moves?*
