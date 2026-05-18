# Personality Spec
*Subsystem detail doc — last updated May 2026*

*Strategic context: see Design Doc §5 (Personality System)*

This document covers everything implementation-adjacent for the personality system: the three scales, the full tag vocabulary, how tags map to scale movement, post-battle processing, the elasticity model, generational scale unlocks, and the emergent label system.

---

## 1. Overview

Personality is an **emergent record of how a bot has been played**, not an autonomous AI. The system observes player decisions, tags actions with semantic meaning, and gradually shifts a bot's three personality scales based on patterns of play.

Personality is deliberately **partially opaque** — players see the effects (scales shifting, skills unlocking, labels crystallizing) but not the exact mechanism. This fits the Skynet flavor of machines evolving in ways even their commander doesn't fully understand.

---

## 2. The Three Scales

| Scale | What it measures |
|---|---|
| **Aggressive ↔ Defensive** | Does the bot deal damage or absorb it? |
| **Solitary ↔ Supportive** | Does the bot fight for itself or for the team? |
| **Reactive ↔ Methodical** | Does the bot respond to the moment or build toward a future state? |

Each scale runs from **-5 to +5**, with 0 as the neutral center.
- Negative values lean toward the first pole (e.g. -3 = Aggressive)
- Positive values lean toward the second pole (e.g. +3 = Defensive)

Values are stored as floats internally for smooth movement, displayed as positions on sliding bars.

---

## 3. Generational Scale Access (Prestige Class Model)

Not all scales are active for all generations:

| Generation | Active Scales |
|---|---|
| Gen 1 | 1 scale only — determined by personality seed at creation |
| Gen 2 | 2 scales — inherits parent's developed scale + one new axis |
| Gen 3+ | All 3 scales |

Inactive scales are locked at 0 and visually grayed out on the bot's display.

When a Gen 1 bot is created, it rolls a personality seed that determines:
- Which single scale is active
- A starting position on that scale (typically 0 to ±1)
- A subtle direction the bot is "naturally inclined" toward

When a Gen 2 bot is born, the active scale from the parent transfers (with its current value), and a second scale unlocks at 0.

Gen 3+ bots have all three scales active. Top-tier emergent labels and signature skills are only fully reachable for Gen 3+ bots.

---

## 4. Tag Vocabulary

Every combat action is tagged with a combination of action tags, target tags, and context tags. Tags map to scale nudges during post-battle processing.

### Action Tags
Tags applied based on what the bot did:

| Tag | Triggered by | Primary scale signal |
|---|---|---|
| `dealing-damage` | Any attack skill | Aggressive |
| `absorbing-damage` | Any defend skill | Defensive |
| `buffing-ally` | Support skills targeting allies | Supportive |
| `buffing-self` | Self-targeting buff/charge | Solitary |
| `healing-ally` | Healing skills (Medic Protocol) | Supportive |
| `planning-ahead` | Charge command | Methodical |
| `finishing-blow` | Kills an enemy (any source) | Aggressive |
| `armor-piercing` | Used an armor-piercing skill | Aggressive |
| `aoe-attack` | Used a multi-target attack | Aggressive |
| `single-target-attack` | Used a focused attack | Methodical |
| `random-multi-hit` | Used Frenzy or similar | Reactive |
| `reckless-action` | Took an action with self-damage (Overload) | Reactive |
| `retaliating` | Used Counter Stance and was hit | Reactive |

### Target Tags
Tags applied based on who was targeted:

| Tag | Triggered by | Primary scale signal |
|---|---|---|
| `target-lowest-hp-enemy` | Targeting the weakest enemy | Reactive |
| `target-highest-hp-enemy` | Targeting the strongest enemy | Methodical |
| `target-highest-threat-enemy` | Targeting the enemy with highest projected damage | Aggressive, Reactive |
| `target-enemy-threatening-ally` | Targeting an enemy whose intent is on a teammate | Supportive, Reactive |
| `target-enemy-threatening-self` | Targeting an enemy whose intent is on this bot | Solitary, Reactive |
| `target-self` | Self-targeting | Solitary |
| `target-weakest-ally` | Buffing/healing the lowest HP ally | Supportive |
| `target-strongest-ally` | Buffing the highest stat ally | Supportive, Methodical |
| `target-charged-ally` | Buffing an ally in Charge state | Methodical, Supportive |
| `target-all-allies` | Team-wide buff/heal | Supportive |
| `target-all-enemies` | AoE attack | Aggressive |

### Context Tags
Tags describing the battlefield state when the action was taken. Context tags **modify** action tags rather than producing their own scale signal — they change what an action *means*.

| Tag | When applied |
|---|---|
| `self-is-low-hp` | This bot is below 33% HP |
| `self-is-critical` | This bot is below 15% HP |
| `ally-is-low-hp` | Any ally is below 33% HP |
| `enemy-is-low-hp` | Any enemy is below 33% HP |
| `no-immediate-threat` | No enemy intent targets a friendly unit this turn |
| `responding-to-threat` | An enemy intent targets a friendly unit this turn |
| `bot-is-charged` | This bot was in Charge state when acting |
| `last-bot-standing` | Only one player bot remains alive |
| `first-action-of-fight` | This is the bot's first action this battle |

---

## 5. Tag-to-Scale Mapping

Each tag contributes a small nudge to one or more scales when processed at end of battle. The values below are starting points for prototyping — exact tuning will come from playtesting.

### Direct nudges from action and target tags

| Tag | Aggressive ↔ Defensive | Solitary ↔ Supportive | Reactive ↔ Methodical |
|---|---|---|---|
| `dealing-damage` | -0.1 (Aggressive) | — | — |
| `absorbing-damage` | +0.1 (Defensive) | — | — |
| `buffing-ally` | — | +0.15 (Supportive) | — |
| `buffing-self` | — | -0.1 (Solitary) | — |
| `healing-ally` | +0.05 (Defensive) | +0.2 (Supportive) | — |
| `planning-ahead` | — | — | +0.2 (Methodical) |
| `finishing-blow` | -0.1 (Aggressive) | — | -0.05 (Reactive) |
| `aoe-attack` | -0.15 (Aggressive) | — | — |
| `single-target-attack` | — | — | +0.05 (Methodical) |
| `random-multi-hit` | -0.05 (Aggressive) | — | -0.1 (Reactive) |
| `reckless-action` | -0.1 (Aggressive) | — | -0.15 (Reactive) |
| `retaliating` | — | — | -0.1 (Reactive) |
| `target-lowest-hp-enemy` | — | — | -0.1 (Reactive) |
| `target-highest-hp-enemy` | — | — | +0.1 (Methodical) |
| `target-enemy-threatening-ally` | — | +0.15 (Supportive) | -0.05 (Reactive) |
| `target-enemy-threatening-self` | — | -0.1 (Solitary) | -0.05 (Reactive) |
| `target-self` | — | -0.15 (Solitary) | — |
| `target-weakest-ally` | — | +0.15 (Supportive) | -0.05 (Reactive) |
| `target-strongest-ally` | — | +0.1 (Supportive) | +0.05 (Methodical) |
| `target-charged-ally` | — | +0.1 (Supportive) | +0.15 (Methodical) |
| `target-all-allies` | — | +0.2 (Supportive) | — |
| `target-all-enemies` | -0.1 (Aggressive) | — | — |

### Context modifiers

Context tags multiply or modify the values above:

- `no-immediate-threat` + offensive action → push toward **Methodical** instead of Reactive (the player attacked when there was no pressure, suggesting plan-driven aggression)
- `responding-to-threat` + offensive action → push toward **Reactive** (reacting to current threat)
- `self-is-critical` + defensive action → push more strongly toward **Solitary** (self-preservation under pressure)
- `self-is-critical` + supportive action targeting others → push strongly toward **Supportive** (sacrifice instinct)
- `ally-is-low-hp` + healing or defensive support → amplify Supportive nudge by 1.5×
- `enemy-is-low-hp` + finishing-blow → amplify Aggressive nudge by 1.5× (predatory tendency)
- `bot-is-charged` + waiting another turn before using charge → push toward **Methodical**
- `last-bot-standing` + any action → halves all personality movement (extreme circumstances don't define character)

---

## 6. Elasticity Model — Rubber Band Resistance

Personality scales don't move linearly. Movement is **easy near the center** and **harder near the extremes**.

Resistance formula:
```
resistance_factor = 1.0 - (abs(current_value) / 5.0) ^ 2
actual_nudge = base_nudge * resistance_factor * elasticity_stat_modifier
```

Where:
- `current_value` is the scale's current position (-5 to +5)
- `elasticity_stat_modifier` is derived from the bot's Elasticity stat (higher = easier movement)

This means:
- A scale at 0 moves at 100% of the base nudge
- A scale at ±2.5 moves at 75% of the base nudge
- A scale at ±4 moves at 36% of the base nudge
- A scale at ±5 moves at 0% (capped)

**Aging effect:** Elasticity degrades over a bot's lifetime. An old bot's `elasticity_stat_modifier` drops significantly, eventually making personality essentially fixed regardless of behavior. This creates urgency around developing personality while a bot is still young.

---

## 7. Post-Battle Processing

At the end of each battle, the full sequence of tagged actions is processed for each bot:

```gdscript
class_name PersonalityProcessor extends RefCounted

static func process_battle_log(bot: BotData) -> Dictionary:
    var scale_deltas = {
        "aggressive_defensive": 0.0,
        "solitary_supportive": 0.0,
        "reactive_methodical": 0.0
    }
    
    # Phase 1: accumulate raw nudges from all actions
    for action in bot.action_log:
        var nudges = _calculate_action_nudges(action)
        for scale in nudges:
            scale_deltas[scale] += nudges[scale]
    
    # Phase 2: apply context modifiers
    scale_deltas = _apply_context_modifiers(scale_deltas, bot.action_log)
    
    # Phase 3: apply elasticity resistance per active scale
    for scale in scale_deltas:
        if not _is_scale_active(bot, scale):
            scale_deltas[scale] = 0.0
            continue
        var current = bot.personality.get(scale)
        var resistance = 1.0 - pow(abs(current) / 5.0, 2)
        var elasticity_mod = bot.elasticity / 10.0  # base elasticity assumed 10
        scale_deltas[scale] *= resistance * elasticity_mod
    
    # Phase 4: apply to bot personality
    for scale in scale_deltas:
        var current = bot.personality.get(scale)
        var new_value = clamp(current + scale_deltas[scale], -5.0, 5.0)
        bot.personality.set(scale, new_value)
    
    # Phase 5: clear action log for next battle
    bot.action_log.clear()
    
    return scale_deltas  # returned so UI can animate the changes
```

---

## 8. Cancellation and Net Movement

If a battle contains contradictory actions (e.g. equal Aggressive and Defensive tags), the nudges cancel each other naturally because they're applied to the same scale in opposite directions. This means:

- A bot played consistently aggressive in one battle → meaningful Aggressive shift
- A bot played mixed-aggressive-and-defensive → smaller net movement, scale stays near center
- A bot played deliberately mixed but contextually appropriate (defensive when threatened, aggressive when safe) → still produces net movement because context modifiers shift which scale gets nudged

This handles the "scattered fight should count for less" intent without needing a separate consistency metric.

---

## 9. Emergent Labels

When a bot's three scales (or however many are active) push past thresholds, an emergent label appears. Labels are derived, not assigned.

### Crystallization thresholds
- Below ±2 on a scale: that scale contributes "developing" to the label
- ±2 to ±3.5: that scale contributes "leaning" to the label
- Above ±3.5: that scale contributes fully to the label

### Full crystallization table (Gen 3+ only)

| Aggressive | Solitary | Reactive | Label |
|---|---|---|---|
| Aggressive | Solitary | Reactive | **Berserker** |
| Aggressive | Solitary | Methodical | **Assassin** |
| Aggressive | Supportive | Reactive | **Aggressor** |
| Aggressive | Supportive | Methodical | **Vanguard** |
| Defensive | Solitary | Reactive | **Coward** |
| Defensive | Solitary | Methodical | **Fortress** |
| Defensive | Supportive | Reactive | **Savior** |
| Defensive | Supportive | Methodical | **Commander** |

### Partial labels for Gen 1 and 2

For bots with fewer active scales, labels are derived from only the active dimensions:

**Gen 1 (1 scale active):**
- Aggressive → "Striker" (developing)
- Defensive → "Guard" (developing)
- Solitary → "Loner" (developing)
- Supportive → "Helper" (developing)
- Reactive → "Reflexive" (developing)
- Methodical → "Planner" (developing)

**Gen 2 (2 scales active):**
- Aggressive + Solitary → "Hunter" (developing)
- Aggressive + Supportive → "Champion" (developing)
- Defensive + Solitary → "Sentinel" (developing)
- Defensive + Supportive → "Shepherd" (developing)
- ...and so on for other 2-scale combinations

These intermediate labels are placeholders pending playtesting — actual naming should feel coherent with the Skynet/Terminator aesthetic.

---

## 10. Visibility and Player Feedback

The tagging system is intentionally not fully exposed. However, complete opacity creates frustration when a bot won't develop in the player's intended direction. The mitigation is a **post-battle summary**:

After each battle, the player sees:
- Visual animation of personality bars shifting for each bot
- A summary card per bot showing which scales moved and roughly in which direction
- A few flavor-text descriptors of the bot's behavior this battle (e.g. "protected allies," "took aggressive risks," "stayed defensive")

The exact tag list is **never shown to the player**. The summary translates raw mechanics into readable behavioral observations.

### Example post-battle summary
```
┌────────────────────────────────────────┐
│  ATLAS — Battle Summary                │
├────────────────────────────────────────┤
│  Aggressive ◄═══════│═════════►        │
│           was -1.2  ────►  now -1.6    │
│                                        │
│  This battle, Atlas:                   │
│  • Took aggressive offensive actions   │
│  • Focused fire on high-value targets  │
│  • Did not protect allies              │
│                                        │
│  Trending toward: Hunter (developing)  │
└────────────────────────────────────────┘
```

---

## 11. Personality Influence on Stats and Skills

Personality scores have two downstream effects beyond just labels:

**Stat growth direction:**
- Aggressive position increases Attack growth rate
- Defensive position increases Defense growth rate
- Solitary/Supportive and Reactive/Methodical do not directly drive stat growth (to avoid flavor-incoherent outcomes like "cowardly bots are faster")

**Skill unlock gates:**
Each skill in the tech tree has personality requirements. See `spec_skills.md` for the full unlock conditions per skill, but the general pattern is:
- Early-tier skills require modest personality investment (±2 on the relevant scale)
- Mid-tier skills require committed development (±3 to ±3.5)
- Top-tier signature skills require deep development (±4 to ±5) and are realistically only reachable by Gen 3+ bots

---

## 12. Inheritance Effects

When a bot retires and breeds, personality scores influence the offspring's starting state:

- The parent's developed scales transfer to the offspring (with weighted blending if two parents both developed the same scale)
- Gen 2 offspring inherit the parent's active scale plus one new scale at 0
- Gen 3+ offspring inherit both parents' active scales plus the third scale at 0
- A small random variance (±0.5) is applied to each inherited scale value, so siblings differ slightly

The exact blend formula for two parents:
```
child_scale_value = (parent1_value * parent1_weight + parent2_value * parent2_weight) / total_weight + random(-0.5, 0.5)
```

Weights can be equal (default) or biased toward whichever parent had higher Elasticity at retirement.

*Full breeding flow detail: see `spec_inheritance.md` (to be written)*

---

## 13. Open Implementation Questions

- Exact tuning of base nudge values (current numbers are starting estimates)
- How rapidly Elasticity should degrade with age — needs playtesting
- Whether context modifiers should be additive or multiplicative against base nudges
- Whether emergent labels should appear gradually (smooth transition between "developing" → "leaning" → "fully crystallized") or snap at thresholds
- How the post-battle summary should handle bots with no net personality movement
- Whether the player should be able to see *which* of their own bots' actions are pushing in which direction in real time during the prototype, for debugging purposes

*Strategic context for any of the above: see Design Doc §5*

---

*Related specs: `spec_combat.md` (action tagging during combat), `spec_skills.md` (personality-gated skill unlocks), `spec_inheritance.md` (personality blending on breeding — to be written)*
