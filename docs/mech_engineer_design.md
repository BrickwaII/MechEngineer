# Mech Engineer — Design Doc

*Updated May 2026 — v4 (refined)*

A roguelite squad-tactics game where the player is an AI commander summoning combat bots from a future timeline. Bots fight, develop personality through play, retire, and pass their traits and skills down to the next generation. The strategic core is multi-generational team building under a soft retirement clock, expressed through a tight per-turn energy puzzle and a territorial macro map.

Design lineage at a glance: STS2 for decision horizons and information design, Into the Breach for telegraphed enemies and territorial pressure, Hades 1/2 for multiplicative scaling and pre-run loadouts, Fire Emblem Awakening for inheritance, Monster Train and FF6/7 ATB as the two competing combat-resolution candidates. Full research notes live in the research appendix.

---

## 1. The Three Decision Horizons

Three non-convertible currencies, one per horizon. Choices at each layer stay distinct.

**Turn → Energy.** A shared pool, replenished each turn, scaled by territorial income. Skills have flat energy costs. Late-game skills cost orders of magnitude more than early ones (working range: early 1–3, late 20–30) to keep the budget tight even as numbers scale. The turn puzzle: given my budget and the enemy's telegraphed intent, which bots activate and with what skills?

**Fight → Bot durability.** Bots degrade over time, accelerated by damage taken, frequent activation, and high-cost skills. The fight question: how hard do I push this fight knowing it shortens my bots' lifespans?

**Run → Territory.** A Risk/Plague Inc-style map. Territory sets the energy ceiling. The human resistance actively reclaims territory, creating pressure that punishes stalling. High-risk nodes (power plants, server farms) yield outsized energy; low-risk nodes yield modest amounts.

---

## 2. Combat Resolution — Two Prototypes

This is the load-bearing open question. Two prototypes built in parallel, then one chosen. Personality, stats, skills, inheritance, and the energy economy are shared between them as much as possible; each prototype tests a different resolution model and the stat-importance shifts that follow from it.

**Prototype A — ATB (Wait Mode).** Inspired by FF6/7 and Backpack Battles. Speed-driven bars fill on a shared timeline. When a bar completes, that unit acts. Player bars pause the game; enemy bars resolve their telegraphed intent and immediately display the next one. Energy regenerates continuously rather than per-round. Status effects that change an enemy's output update the displayed intent in real time. Speed is one of the most impactful stats in the game; a fast efficient bot is a categorically different asset from a slow one.

**Prototype B — Simultaneous Resolution.** Inspired by Monster Train and STS planning. A discrete planning phase shows full-round enemy intent. Player assigns commands one at a time, spending from the shared energy pool, with live damage preview updating after each assignment. Confirm → all commands resolve simultaneously → enemies act. Speed determines order within resolution, not frequency. Energy scarcity (not every bot active every round) is the primary tension source.

**Success criteria, both prototypes:** Does the player feel like a commander making meaningful decisions every round? Does Speed feel valuable without feeling unfair? Does the squad fantasy hold up across a full fight? Does the damage preview successfully eliminate guesswork without flattening tension?

*Implementation detail: see `spec_combat.md`*

---

## 3. Damage Preview UI (both prototypes)

Before any action confirms, the UI shows red drain segments on projected damage, skull indicators on units projected to die, green indicators on bots whose Defend saves them, Charge previews showing next-activation values, ranges (e.g. "7–14") for variance skills, and exact numbers for everything deterministic. The player always knows what they're committing to.

*Implementation detail: see `spec_combat.md`*

---

## 4. Squad and Run Structure

**Starting draft.** Each run begins with a pool of 4–5 randomized bots. Player drafts 3 to field. Benched bots do not develop — personality only grows through combat. The draft is the run's first strategic decision: which three bots have complementary trees, personality seeds, and stats for the team you want to build?

**Field size.** Default is 3 fielded bots. Territorial expansion can stretch this to 4 in mid-late game as energy income supports it. Larger squads (up to 6) are a stretch feature pending prototype validation — they may not survive readability constraints.

**Between-fight choices.** Three options, all costing energy/Power, all competing for the same pool: **Rest** (recover durability), **Upgrade** (improve a current bot's skill or stat), **Summon** (pull a next-gen bot from the future, retiring a parent).

**Run pacing.** TBD through prototyping — but the target is long enough that a bot has time to develop personality meaningfully (multiple battles per generation), short enough that 2–3 generational turnovers happen in a typical run.

---

## 5. Personality System

Three sliding scales, each 0–5 on each pole:

1. **Aggressive ↔ Defensive** — deal damage or absorb it
2. **Solitary ↔ Supportive** — fights for itself or for the team
3. **Reactive ↔ Methodical** — responds to the moment or builds toward a future state

**Prestige-class generations.** Gen 1 bots have only one active scale. Gen 2 inherits the parent's developed scale and unlocks a second. Gen 3+ runs all three. Later generations are dimensionally richer, not just numerically stronger. Top-tier signature skills are gated to Gen 3+.

**Rubber band elasticity.** Personality moves freely near the center and resists movement near the extremes — maxing a pole requires sustained consistent behavior, not a few actions. Inconsistent play settles in the middle by default. Elasticity declines with age: old bots' personalities are essentially fixed. Retiring too late means inheritance scores are locked whether you wanted that or not.

**Tag-based evaluation.** Every combat action is tagged (target, action, context). At end of battle, the full tagged sequence is processed for personality nudges. Context tags modify action tags — acting aggressively under `no-immediate-threat` reads Methodical; the same action under `responding-to-threat` reads Reactive. Personality is locked during combat and updates only between battles. Cancelling actions (equal pulls) produce less net movement than consistent ones.

**Visibility.** Tagging is intentionally opaque — players observe shifts without seeing the exact inputs, fitting the "machines evolving beyond their commander's full understanding" flavor. Risk: this can feel unfair if a player's bot won't develop in their intended direction. Mitigation under consideration: a post-battle summary showing which scales moved and roughly which behaviors drove it, without exposing the full tag list.

**Emergent labels** appear when scale combinations crystallize (Berserker, Assassin, Aggressor, Vanguard, Coward, Fortress, Savior, Commander). Only Gen 3+ bots can fully crystallize. Mixed positions produce intermediate labels — exact behavior TBD through playtesting.

**Personality drives stats and skill access.** Aggressive raises Power-direction stat growth; Defensive raises resistance growth. Solitary/Supportive and Reactive/Methodical primarily unlock skills rather than driving stat growth — this avoids flavor-incoherent outcomes like "cowardly bots are faster."

**Display.** Three sliding bars labeled by pole, with inactive scales (Gen 1/2) grayed out. Bot art and presentation should shift subtly as personality develops, so a fully-formed Berserker looks different from a fully-formed Commander even from the same seed.

*Implementation detail: see `spec_personality.md`*

---

## 6. Stats

| Stat | Role |
|---|---|
| **HP** | Damage absorbable before defeat |
| **Attack** | Base damage, multiplied by skill modifiers |
| **Defense** | Flat damage reduction per hit; armor-piercing skills bypass it |
| **Speed** | Action frequency (Prototype A) or order (Prototype B) |
| **Elasticity** | Rate and ceiling of personality development; degrades with age |
| **Efficiency** | Energy-to-output ratio |

**Multiplicative scaling.** Effective output is approximately `Attack × Efficiency × skill level × personality bonus × team synergy`. Each layer compounds. Builds that synergize across all layers produce categorically larger output than builds that hedge. This is what "good synergies should produce big bombastic numbers" means in practice.

**No random dodge.** All avoidance is activated, deliberate, and costs energy.

---

## 7. Skills and Tech Trees

**Each bot has a partially fixed tech tree** with three directions: a deep, fast-to-unlock primary path; an accessible secondary path; and an expensive tertiary path. Trees define emphasis, not exclusion — every bot can eventually reach most skills, but the investment varies dramatically.

**Skill unlocks require all three of:** a minimum stat threshold, a minimum personality score in the relevant direction, and (sometimes) a prerequisite lower-tier skill in the same chain.

**Skill tiers.** Early-tier skills: lower gates, higher level caps (working assumption: cap 5). Late-tier skills: higher gates, lower caps (cap 3), but greater absolute power at max. A maxed late-tier skill is categorically stronger than a maxed early-tier skill.

**Evasion skills are personality-gated, not Speed-gated.** Camouflage (Defensive + Solitary) makes a single bot untargetable for one round. Smoke Screen (Defensive + Supportive + Methodical, Commander-tier) protects the whole team at higher cost. Both deterministic, both energy-cost. Speed affects how useful they are tactically but does not unlock them.

**Tech tree inheritance.** Children's trees blend both parents' — some branches from each, potentially creating combinations neither parent had. Two parents with different primary paths can produce a child whose tertiary paths are now secondary.

*A full worked tech tree example for one starter archetype belongs in the next revision — this is currently the most underspecified part of the design. Implementation detail to be captured in `spec_skills.md` and `spec_tech_tree.md` when written.*

---

## 8. Inheritance and Breeding

When a bot retires, the player selects which skills to slot into the inheritance position — the primary strategic decision of the system. Breeding produces **2–3 offspring options** with slight randomization in how parent traits blended. Player picks one to keep.

Offspring inherit: blended stat modifiers, a tech tree combining both parents' paths, one skill per command from each parent's inheritance slot at the parent's current skill level, and a personality starting point weighted by parent scores. Gen 2+ children unlock one additional personality scale.

Skill level carries at full level — a parent's Level 4 Power Shot produces a Level 4 Power Shot child. Developing skills before retirement is a meaningful investment, not just flavor.

*Implementation detail: see `spec_personality.md` §12 (inheritance effects on personality); full breeding flow to be captured in `spec_inheritance.md` when written.*

---

## 9. Variance Philosophy

The game is built on full information and deterministic outcomes, with a narrow and intentional variance set:

**Intentional variance:** multi-hit skills (shown as ranges in preview), Gen 1 starting pool (the primary run-to-run variance), enemy variety per run, skill and upgrade offerings, and personality development (opaque but not random — player-driven patterns).

**Everything else is deterministic.** Defend, Support, Charge, Speed, and Camouflage all produce exact outcomes shown precisely in preview. Enemy intent is always visible before the player acts.

---

## 10. Build Archetype Hypotheses

These are predictions the prototype should validate, not promises:

- **Berserker Engine** — single high-Attack carry fed by support and shielded by a tank
- **Commander Network** — buffs layered across the team for compounded multi-target payoff
- **Doom Clock** — escalating execution debuff that bypasses Defense; rewards long fights
- **Assassin Loop** — high-Speed glass cannon chaining kills behind Camouflage
- **Swarm** — many cheap bots through high Efficiency; resilient through redundancy

Committing to one of these early and developing toward it through inheritance and personality growth should be the primary strategic arc of a run. Hedging across unrelated archetypes should underperform in late game.

---

## 11. Open Questions (Prioritized)

**Highest priority — prototyping:**
- Minimum scope for each combat prototype to be a meaningful test
- Which prototype to build first
- Concrete success criteria

**High priority — pacing and feel:**
- Run length, encounter count, expected generations per run
- Energy regen rate (Prototype A) vs energy budget per round (Prototype B), tuned against skill costs
- Failure modes of the personality system — how a player debugs an under-developing bot

**Medium priority — depth:**
- One full worked tech tree example per starter archetype
- Full action-to-tag mapping (partial mapping exists in `spec_personality.md`)
- Personality blend formula on inheritance
- Stat thresholds for each skill tier
- Armor-piercing skill distribution

**Lower priority — meta and polish:**
- Territorial map design, resistance AI, win condition
- Family tree visualization
- Whether retired bots have any passive legacy benefit
- Behavior of mixed/intermediate personality labels

---

## Document Map

This design doc is the strategic vision and high-level decisions. For implementation detail, see the subsystem specs:

- **`spec_combat.md`** — data models, damage calculation, prototype skill set, enemy AI patterns, full architecture for both Prototype A and Prototype B, UI scene structures, build order recommendation
- **`spec_personality.md`** — three scales detail, full tag vocabulary, tag-to-scale mapping, elasticity formula, post-battle processing, emergent label crystallization

For research lineage and per-game design lessons:

- **`mech_engineer_research.md`** — full per-game notes on the titles that shaped the design

---

## Appendix: Research Lineage Summary

Slay the Spire 2 (decision horizons, perfect information, status counter UI, character archetypes). STS2 Regent (secondary resource banking, setup/payoff, commit-to-archetype). STS2 Necrobinder (execution thresholds, duo-unit patterns, loop-not-deck). Into the Breach (territorial power grid, telegraphed intent, restrained meta-progression, map flavor). Hades 1 (damage funnel, duo boons, conditional multipliers). Hades 2 (Arcana as pre-run floor, multiplicative compounding, cross-bot synergy template, Omega→Charge mapping). Monster Train (Prototype B basis). Backpack Battles (cooldown frequency, Speed × Efficiency compounding). FF6/7 ATB (Prototype A basis). Bravely Default (tempo framing). Slice & Dice (party UI legibility, no-hidden-mechanics). Fire Emblem Awakening (inheritance slot as primary act, skill level carries through). Mewgenics (soft decay preferred over hard limit). Bot Arena 3 (pre-fight configuration as primary decision space). Across the Obelisk (speed-based ordering in party games).

Full per-game research notes live in `mech_engineer_research.md`.
