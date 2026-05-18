# Mech Engineer — Research Log

*Companion to the Mech Engineer design doc. Full per-game notes on the titles that shaped the design. Each entry covers what the game does, what we took from it, and (where relevant) what we explicitly did not take.*

*Updated May 2026 — v3 (STS1+STS2 merged, six character archetypes covered)*

---

## Slay the Spire 1 & 2

The primary reference family for Mech Engineer. STS1 is the foundational deckbuilding roguelike of the modern era — a complete, fully balanced, exhaustively analyzed game with years of competitive metagame development behind it. STS2 is its in-progress sequel, currently in Early Access, which we study not just for its mechanics but as a live case study in how designers refine, rebalance, and expand a beloved system.

Both games share the same core structure: build a deck across a branching map of encounters, defeat increasingly difficult enemies, climb to a final boss. Three currencies — turn energy, fight HP, and run deck composition — never convert into each other. Enemy intent is fully telegraphed before each player turn. Variance comes from card and relic offerings, not from concealed information.

**Why both games matter for Mech Engineer:**

- STS1 shows us what a fully realized roguelike looks like at the end of its design cycle — what survives competitive play, what each character archetype actually accomplishes at high Ascension difficulty, what scaling patterns prove durable.
- STS2 shows us how a successful design iterates — what mechanics get refined (Sly keyword on Silent, Glass orbs on Defect for AoE, Brand bridging Exhaust/Strength/Self-Damage on Ironclad), what new characters are designed to fill missing niches (Regent's banking economy, Necrobinder's companion structure), and how an experienced studio expands its design language.

**Key design lessons (shared across STS1 and STS2):**

- Three simultaneous decision horizons (turn / fight / run) with non-convertible currencies is the spine of the genre.
- Perfect information about enemy intent creates a puzzle feel rather than a guessing game.
- Powers (persistent effects within a fight) create a setup/execution phase structure within single combats.
- Visible status counters preview deferred consequences at a glance — Poison, Doom, Vulnerability, Weak, Strength stacks. Adopted directly as Mech Engineer's UI pattern for damage preview and personality state.
- Every successful character has 3-5 distinct viable archetypes within their card pool, each with a different scaling curve. The character is interesting because of the *space of possible builds*, not because of a single fixed playstyle.
- "Don't force a build; let the cards offer you one" — the highest-skill play is reading what's offered and committing to whichever archetype emerges. Mech Engineer's equivalent: reading the Gen 1 bot pool and committing to whichever team identity fits.

### Character Archetype: Ironclad (STS1, returns in STS2)

The classic warrior class. Starts with the highest HP (80) and the Burning Blood relic (heal 6 HP after every combat), making HP a renewable resource he can spend more freely than other characters. His card pool emphasizes HP manipulation, Strength scaling, and the Exhaust mechanic.

**Primary archetypes:**

- **Strength Scaling** — Stack Strength buffs (Inflame, Limit Break, Demon Form, Flex) and combine with multi-hit attacks (Twin Strike, Sword Boomerang, Whirlwind) so each Strength point multiplies across multiple hits. The most beginner-friendly archetype. Strength is a flat additive bonus per hit, which means it scales linearly until paired with multi-hit, at which point it becomes multiplicative.
- **Exhaust Engine** — Use Corruption (all Skills cost 0 and Exhaust), Feel No Pain (Block on Exhaust), Dark Embrace (draw on Exhaust), and Juggernaut (damage on Exhaust) to create a self-reinforcing engine where every card play feeds the next. The deck thins itself mid-fight as cards Exhaust, increasing draw density of remaining powerful cards. High ceiling, requires specific pieces.
- **Block/Barricade** — Stack massive Block totals with cards like Barricade (Block persists between turns) and finish with Body Slam (damage equals current Block). Defensive identity that converts survival into offense.
- **Bloodletting/Self-Damage** — Cards like Rupture (gain Strength when you take damage), Brutality (lose HP per turn, gain Strength), and Offering (lose 6 HP, gain energy and card draw) turn HP loss into power. The riskiest archetype; rewarded by Burning Blood's post-combat heal but punished by Act 3 enemies with high burst damage.

**Strengths:** High HP, sustainable through Burning Blood, multiple viable archetypes from a wide card pool, can adapt to most card draft offerings.

**Weaknesses:** Generally lacks innate AoE outside of Whirlwind. Self-damage archetypes have an unreliable HP floor against burst-damage elites. The Strength build's linear scaling makes it weaker against single-shot enemies that don't reward multi-hit math.

**Scaling pattern:** Linear (Strength) or multiplicative (Exhaust loops). Strength builds front-load damage early; Exhaust builds back-load it dramatically once the engine assembles.

**Key design lessons for Mech Engineer:**

- A character with a "high floor, moderate ceiling" archetype (Strength scaling) alongside a "low floor, high ceiling" archetype (Exhaust engine) lets the same character serve beginners and experts. Mech Engineer's bot variety should similarly offer easy-to-pilot bots and high-skill-ceiling bots within the same starter pool.
- HP as a spendable resource via post-combat healing is the template for our durability-as-fight-resource design. Burning Blood is essentially what Mech Engineer's between-fight Rest option models.
- Multi-hit attacks multiplying flat stat buffs is the cleanest example of multiplicative scaling we've seen — translates directly to Mech Engineer's Frenzy/Spread Shot skills and Battle Cry buffs combining for outsized output.

### Character Archetype: Silent (STS1, returns in STS2)

The rogue class. Low HP (70), high card velocity, and the Ring of the Snake starting relic (draw 2 extra cards on turn 1). She has no innate healing — every HP trade is permanent for the run. Her card pool emphasizes hand manipulation, damage over time, and exploitation of zero-cost card chains.

**Primary archetypes:**

- **Poison** — Stack Poison on enemies (Deadly Poison, Bouncing Flask, Poisoned Stab) and let it tick down their HP each turn. Catalyst doubles current Poison stacks. Noxious Fumes applies Poison passively every turn. Scales exponentially: each turn adds more Poison while existing Poison damages, so total damage grows non-linearly. Wins through attrition; struggles against enemies with high HP single-turn burst.
- **Shiv** — Generate zero-cost Shiv attack cards (Blade Dance, Cloak and Dagger, Infinite Blades) and play them in volume. Each individual Shiv is weak, but stacked card draw and the Accuracy power (Shivs deal +X bonus damage) turns volume into burst. Synergizes hard with relics like Kunai, Shuriken, Nunchaku that trigger on multiple card plays per turn.
- **Discard/Sly (STS2 only)** — STS2 added the Sly keyword: when a Sly card is discarded from hand, it plays instantly. Combined with Tools of the Trade (draw 1, discard 1 each turn) and other discard generators, this creates a free-action engine. Speedster (deal damage every time you draw a card) turns the draw/discard loop into automatic damage.
- **Discard (STS1 grand finale)** — Discard cards intentionally to fuel payoff cards like Grand Finale (deal X damage based on cards in discard) and Dagger Throw (deal damage, draw 1, discard 1).

**Strengths:** Highest card velocity in the game. Exponential scaling via Poison. Flexible deck composition — multiple archetypes can coexist in the same deck. Excellent at long fights where Poison can accumulate.

**Weaknesses:** Fragile (low HP, no healing). Shiv builds struggle against thorns enemies (each Shiv triggers reflected damage). Poison builds need time to ramp and struggle with multi-target encounters before AoE Poison is established.

**Scaling pattern:** Exponential (Poison) or volume-based (Shiv). Poison damage grows non-linearly per turn; Shiv damage grows per card-play velocity, which itself compounds.

**Key design lessons for Mech Engineer:**

- A character whose central tension is "you have no healing, every HP loss is permanent" is the purest expression of HP-as-resource. Mech Engineer's durability decay system creates the same emotional pressure on a longer timescale — every fight has permanent consequences.
- Multiple viable archetypes within a single character maps to Mech Engineer's "each bot has three directions in its tech tree" — the same bot should support multiple build paths depending on how the player develops it.
- Exponential scaling via stackable debuffs (Poison) is the design pattern for our Doom Clock build archetype. The emotional arc is identical: invest early in the debuff, survive the ramp, watch it spiral.
- The Sly keyword's "discard this for free action" is a clean example of *converting a constraint into a resource* — discarding was previously a downside, now it's a payoff trigger. Worth thinking about for Mech Engineer's Charge command: can we convert "skipping a turn to Charge" into something that triggers additional effects?

### Character Archetype: Defect (STS1, returns in STS2)

The automaton class. Mid HP (75), unique Orb mechanic. Starts with the Cracked Core relic (channel 1 Lightning orb at start of every combat). Has three orb slots by default; when a fourth orb is channeled, the rightmost orb Evokes (triggering its full effect) and leaves play. Cards channel orbs, orbs trigger passive effects each turn, and Focus is a unique stat that amplifies all orb effects.

**Primary archetypes:**

- **Lightning/Focus** — Channel many Lightning orbs (Zap, Ball Lightning, Lightning Rod), stack Focus through Defragment and Consume, and let passive Lightning damage handle damage output. Electrodynamics makes all Lightning damage hit all enemies — solves AoE. Scales multiplicatively: each Focus point amplifies every orb's passive AND Evoke value.
- **Frost/Block** — Channel Frost orbs for passive Block generation. With enough Focus and orb slots, generate hundreds of Block per turn. Use Body Slam-equivalents or just outlast enemies. The "Frost Turtle" build is the canonical example of generating an unbreakable defense.
- **Dark Orb** — Dark orbs accumulate damage every turn before being Evoked for a single massive nuke. Combined with Focus and orb slot manipulation, can store damage across many turns before unleashing.
- **Claw** — Ignores orbs entirely. The Claw card is a 0-energy attack that deals X damage; every time any Claw is played, all Claws in the deck gain +2 damage permanently. Combined with card-draw cards (Scrape, Skim, Hologram) you play many Claws per turn, each one stronger than the last. Highest single-fight scaling ceiling of any STS card.
- **AoE/Glass Orbs (STS2 only)** — STS2 added Glass orbs that deal AoE damage passively and on Evoke. Solves the Defect's historical weakness against multi-enemy hallway fights.

**Strengths:** Multiplicative scaling via Focus is the highest in the game. Frost builds are the tankiest in the genre. Each archetype has a fundamentally different feel — Lightning is reactive damage, Frost is patient turtling, Dark is burst storage, Claw ignores the entire orb system.

**Weaknesses:** Weakest early game of any character — the Defect's engines take turns to assemble, and Act 1 elites can punish a slow start. Highly technical to pilot well. RNG-vulnerable: a bad draft starves the build of Focus or orb generation.

**Scaling pattern:** Multiplicative (Focus × orb count × turn duration). The longer the fight lasts, the more powerful the Defect becomes. Single-fight scaling potential exceeds every other STS character.

**Key design lessons for Mech Engineer:**

- The Defect is the closest analog to our Methodical archetype — patient setup, long-fight scaling, multiplicative payoff. The "Frost Turtle" build is literally the Mech Engineer Commander Network archetype: stack defensive multipliers, run out the clock, win through attrition.
- A unique secondary resource (Focus) that amplifies an entire mechanical system (orbs) is the cleanest example of dedicated multiplier-stat design. Mech Engineer's Efficiency stat is structurally similar — it amplifies how much output we get from each energy point.
- Glass orbs being added in STS2 specifically to fix the Defect's AoE weakness is a key designer-iteration lesson: when an archetype has a structural blind spot, the right fix is often to add a new mechanic to that archetype rather than rebalance existing ones. Worth remembering for Mech Engineer's prototype iteration.
- The Claw build deliberately ignores the character's main mechanic and uses a completely different scaling pattern. This is a useful design move — letting players "opt out" of the central mechanic toward an alternate path keeps the character interesting even when the main path's pieces don't show up in the draft.

### Character Archetype: Watcher (STS1)

The monk class. Mid HP (72). Has a unique Stance mechanic — at any given moment she is in one of three stances:

- **Calm** — neutral. Exiting Calm grants 2 energy.
- **Wrath** — deals double damage AND takes double damage. Extremely powerful offensively, extremely risky defensively.
- **Divinity** — deals triple damage and gains 3 energy on entry. Lasts only until end of turn. Entered by accumulating 10 Mantra.

The Watcher's central tension is stance timing: maximize Wrath damage windows while never being in Wrath when an enemy attacks lands. She's widely considered the strongest character in STS1 for skilled players, but also the most punishing of poor stance management.

**Primary archetypes:**

- **Stance Dance** — Rapidly switch between Wrath (for damage) and Calm (for energy and safety). Cards like Flurry of Blows (returns to hand whenever you change stances) become essentially infinite damage sources. Mental Fortress grants Block on every stance change. Energy from Calm exits fuels more cards. The skill ceiling of this build is among the highest in the genre.
- **Divinity** — Build to 10 Mantra (Devotion, Worship, Prostrate, Pray, Damaru relic) and trigger a turn of triple damage. Combine with retained attack cards (Crescendo, Reach Heaven, Battle Hymn) saved up over previous turns. Often ends fights in a single explosive turn.
- **Retain** — Save retained cards across multiple turns (Battle Hymn, Sands of Time, Windmill Strike) and unleash them simultaneously in a Wrath or Divinity turn. The clearest setup/payoff archetype in the entire game.
- **Calm/Defense (Pressure Points or Pure Calm)** — Stay in Calm for safety, win through non-attack damage (Pressure Points debuff) or Scry-based block generation (Nirvana, Like Water). Highly specialized but extremely safe.
- **Infinite Combos** — A small number of card combinations (Lesson Learned + 0-cost draw chains, Talk to the Hand stacking, etc.) allow theoretically infinite damage loops. The most degenerate plays in the entire game.

**Strengths:** Highest damage ceiling of any character. Stance switching creates incredibly flexible turn structure. Multiple "win in one turn" archetypes. Excellent scaling against bosses with high HP single-target.

**Weaknesses:** Wrath mistakes are run-ending — taking double damage from an unexpected hit can kill her instantly. Mantra/Divinity decks require specific combo pieces. Some archetypes are very specialized and don't transfer between fights.

**Scaling pattern:** Multiplicative within a single turn (Stance × Strength × multi-hit), but per-turn rather than per-fight. The Watcher front-loads enormous burst damage into specific turns rather than scaling across the fight.

**Key design lessons for Mech Engineer:**

- The Stance mechanic is the cleanest example of "active state that fundamentally changes how the character behaves." This maps onto Mech Engineer's Charge state and personality archetypes — a bot in Charge state is essentially in a different stance with different multipliers, just like Watcher in Wrath.
- The Divinity archetype's emotional structure — accumulate Mantra (an invisible meter), reach 10, unleash a triple-damage turn — is structurally identical to a Charged Mech Engineer bot's payoff. The reveal moment of "now I unleash" is the emotional core of the Methodical archetype.
- Wrath's "double damage in both directions" is a brilliant risk/reward design. Mech Engineer's Overload skill captures the same energy: extra power output at the cost of self-damage. Worth considering whether more skills should have this two-sided risk pattern.
- The skill ceiling gap between basic Watcher play and expert stance-dancing is enormous. Mech Engineer should aspire to a similar gap — most players can run a competent team, but a master player should be able to extract dramatically more from the same starting pool.

### Character Archetype: Regent (STS2-only)

A new character introduced in STS2 Early Access. Manages **Stars** as a secondary resource alongside Energy. Stars do not reset at end of turn and have no cap, enabling multi-turn banking into devastating burst turns. The Regent's design is openly experimental — a deliberate exploration of "what if a deck had a secondary infinite-cap resource?"

**Primary archetypes:**

- **Star Engine** — Generate Stars rapidly, convert them back into Energy to extend turns, finish with high-cost payoff cards. The advanced loop converts Stars → Energy → card draw → more Stars, effectively playing the entire deck in one turn before dropping a finisher.
- **Forge** — Permanently increase the Sovereign Blade's damage by playing Forge-keyword cards across many turns, then finish with a single massive strike. The slowest-scaling archetype but also the highest single-hit ceiling.

Splitting between both archetypes produces an inconsistent deck that excels at neither.

**Strengths:** Highest setup-to-payoff ratio of any character. Stars never expiring means even "wasted" turns of banking contribute meaningfully. Multiple combo lines that can chain into "play the whole deck" turns.

**Weaknesses:** Slow to start. Heavily dependent on finding key cards. Stars-as-resource creates a learning curve since the optimal spending timing is non-obvious.

**Scaling pattern:** Pure banking/payoff — small linear gains across many turns culminating in one explosive payoff turn.

**Key design lessons for Mech Engineer:**

- A secondary resource that carries between turns with no cap is one of the most powerful scaling tools in the genre. Mech Engineer's Charge state is structurally similar but lacks the multi-turn banking depth — worth considering whether some bots should have access to a "stockpile" mechanic.
- The setup/payoff structure (bank for many turns, cash out in one) is the emotional core of the Methodical archetype in Mech Engineer.
- Committing to one archetype early and building toward it consistently outperforms hedging — applies directly to Mech Engineer team compositions.
- As an in-progress character, the Regent shows how designers introduce a high-variance "experimental" archetype to a known formula. New mechanics in Mech Engineer (new tech tree branches, new personality combinations) can follow the same approach: introduce a deliberately weird mechanic with high ceiling and let players figure out what it's for.

### Character Archetype: Necrobinder (STS2-only)

A new character introduced in STS2 Early Access. Fights alongside **Osty**, a reanimated skeletal hand that absorbs incoming damage and can be buffed into a primary damage dealer. This is the first official duo-unit character in the STS lineage — historically all STS characters fought alone.

**Primary archetypes:**

- **Doom** — Stack a kill threshold on enemies. When their HP drops to or below their Doom stacks, they die at end of their turn. Doom doesn't deal damage directly — it sets a condition that triggers death. Rewards longer fights and punishes passive play (the enemy will die eventually regardless of what they do).
- **Osty** — Buff the companion into a primary damage dealer. Cards that increase Osty's stats, defend Osty, or let Osty take actions create a duo-attack pattern where the Necrobinder is more of a support character.
- **Souls** — Generate zero-cost cards that draw two cards and exhaust. Creates a card velocity engine that powers other archetypes. Souls are the connective tissue of most Necrobinder builds.

**Strengths:** Doom as an execution mechanic ignores enemy defenses, scaling, and HP totals. Osty creates an additional "unit" the player can deploy. Souls provide consistent card velocity that prevents dead turns.

**Weaknesses:** Doom builds are slow against short fights. Osty can be killed, removing the build's primary damage source. Souls require specific deck composition to enable.

**Scaling pattern:** Threshold-based (Doom) — damage is binary, you either reach the threshold or you don't. Combined with companion units (Osty) for a duo-character output structure.

**Key design lessons for Mech Engineer:**

- Doom as an execution threshold (not damage-per-turn) is the template for Mech Engineer's Death Blow / execution skill design. Deferred but inevitable kill conditions create a different strategic texture than direct damage.
- The companion/duo-unit structure mirrors Mech Engineer's team synergy patterns — a fragile high-ceiling bot paired with a defensive bot that absorbs damage for it is a natural team composition. The Necrobinder + Osty pairing is essentially the "Berserker Engine" archetype in different clothing.
- Souls as zero-cost connective tissue cards is the cleanest example of how to build a flexible engine that supports multiple archetypes simultaneously. Mech Engineer's equivalent could be a category of low-cost skills that generate energy or draw effects, available to most bot archetypes.
- The Necrobinder is STS2's experiment in multi-unit play. As the only character in the STS lineage with a permanent companion, it's a direct precursor to Mech Engineer's squad-based approach. Watching how players develop strategies around Osty as a positional/health-pool resource gives us live data on how players reason about duo-unit teams.

### Cross-Character Lessons for Mech Engineer

Looking across all six characters, several broader patterns emerge:

- **Every successful character has a "default safe build" AND a "high ceiling build" within their pool.** Ironclad has Strength (safe) and Exhaust (ceiling). Silent has Poison (safe) and Shiv-velocity (ceiling). Defect has Frost (safe) and Lightning/Focus (ceiling). Watcher has Stance Dance (safe) and Divinity infinites (ceiling). Mech Engineer should similarly offer beginner-friendly archetypes alongside expert builds within the same starting pool.

- **The character's signature mechanic should be opt-in, not mandatory.** Defect's Claw archetype ignores orbs entirely. Watcher's Pressure Points archetype barely uses stances. Ironclad's Bloodletting builds use Exhaust as a tool but center on self-damage. This flexibility means even when the draft is hostile to a character's main mechanic, alternative paths exist.

- **Scaling type matters as much as scaling amount.** Linear (Strength), exponential (Poison), multiplicative (Focus), volume-based (Shiv velocity), threshold (Doom), and stance-multiplied (Wrath/Divinity) all feel different to play. Mech Engineer should support multiple distinct scaling patterns rather than just numerical scaling.

- **In-progress design (STS2) shows where the genre is heading.** Sly (converting a constraint into a resource), Stars (uncapped secondary resource), Forge (permanent intra-run card modification), Glass orbs (filling structural gaps), Doom (execution thresholds), and companion units (Osty) are all design moves worth considering for Mech Engineer's future development. The fact that the same studio that designed STS1 chose to add these specific things suggests they're the directions a mature deckbuilder design language wants to expand into.

---

## Hades 1

An action roguelite where Zagreus escapes the underworld using a weapon and boons from Olympian gods. Each run, the player selects boons that modify attack, special, dash, and cast abilities. Boons stack multiplicatively — a percentage damage bonus from Aphrodite multiplying against a base already boosted by Artemis creates disproportionate output. Duo boons (requiring boons from two specific gods) represent the highest-ceiling interactions, rewarding players who build toward cross-god synergies rather than taking the best individual option each room.

**Key design lessons:**

- Every strong build has a single primary damage funnel that all other boons feed into. Splitting across multiple damage types underperforms a focused build.
- High attack speed weapons want boons that add new damage sources (Zeus chain lightning, Dionysus Hangover). High base damage weapons want percentage multipliers (Aphrodite, Artemis). Matching the scaling type to the weapon is the core skill expression.
- Duo boons and cross-system synergies have disproportionately large payoffs.
- Privileged Status (bonus damage when two different status effects are active) is the template for "meeting conditions to unlock a multiplier" — the game's most powerful damage ceiling requires deliberate setup across multiple systems.

---

## Hades 2

Melinoe's escape from Chronos adds Arcana Cards — a pre-run permanent loadout that determines your baseline power floor before any boon is collected. Arcana are activated with Grasp (a limited resource), forcing meaningful choices about which permanent bonuses to enable. The Origination Arcana (+50% damage to enemies with two or more curses) is the defining endgame multiplier — it rewards builds that commit to applying multiple curse types from different gods.

**Key design lessons:**

- Arcana Cards as a persistent pre-run layer that amplifies everything is the template for Mech Engineer's inheritance system — the stat floor bots bring from generations of development determines the baseline before any run-specific skill choice.
- Percentage-based boons compound multiplicatively against already-boosted base damage — each additional multiplier layer scales disproportionately. This validates the Mech Engineer stat design goal: Attack × Efficiency × personality bonus × skill level should multiply, not add.
- The Origination principle — a powerful multiplier that only activates when specific conditions are met — is the design pattern for cross-bot synergy bonuses in Mech Engineer. Two bots with complementary personality archetypes working in concert should produce disproportionate output.
- Omega moves (chargeable high-cost skills requiring Magick) are the template for Charge state skills — high energy cost, powerful output, require resource management.

---

## Slice & Dice

A 5-hero party roguelike where each hero is a die. Enemy actions are shown before the player acts. Players roll dice, see results, then selectively reroll. Every turn is a small puzzle with full information. The party card layout is worth studying directly: portrait, name, HP as a pip track, and current skill icon — all in a compact readable rectangle. Enemy cards mirror the same format. Color-coded card borders encode state (active, charged, defeated) faster than any text system.

**Key design lessons:**

- Full enemy intent visibility before the player acts is essential to a puzzle feel.
- A 5-unit party game can be perfectly readable if each unit's card is self-contained and state-coded by color/border.
- The binary between-fight choice (upgrade a hero OR get an item) keeps pacing tight without becoming a separate mini-game.
- "No hidden mechanics, everything visible at all times" as a design philosophy.

---

## Monster Train

A roguelite deckbuilder where the player defends a train across three floors against waves of enemies. Key mechanic: the player spends their turn playing cards (units and spells) using Ember (energy), then ends their turn — after which enemies attack friendly units, friendly units counterattack, and surviving enemies climb to the next floor. The player does not directly control combat resolution; they set up the conditions and fire.

Monster Train 2 added an undo-turn system, allowing players to experiment with placement and card order before committing. The damage preview is always implicit — enemy attack values are visible, so players can calculate outcomes before ending their turn.

**Key design lessons:**

- "Set up and fire" simultaneous resolution feels satisfying when the player has full information before committing. This is the basis for Prototype B.
- Live damage preview (implicit from visible stats) removes the frustration of opaque resolution.
- Undo-turn reduces misclick frustration without removing strategic pressure.
- Ember as a flat per-turn resource with skill costs attached is a clean, readable economy.

---

## Bravely Default

A JRPG whose Brave/Default system is one of the most elegant turn-based energy designs in the genre. Each character has Brave Points (BP): they gain 1 BP per turn and spend 1 BP per action. **Brave** lets a character act multiple times in one turn by borrowing future BP — going negative means their turns are skipped until the debt is repaid. **Default** banks 1 BP and reduces incoming damage, preparing for a future burst turn.

**Key design lessons:**

- Spending future turns (Brave) vs. banking turns (Default) creates a genuine tempo game within a turn-based structure.
- The debt mechanic (negative BP = skipped turns) makes aggressive play genuinely risky rather than always optimal.
- This framework maps conceptually onto Charge (banking for a future burst) and the risk of over-committing resources.
- **What we are not taking:** the per-character BP system itself. Mech Engineer's energy is a shared pool. The lesson is the *tempo framing* — spending vs. banking as a real decision — not the BP mechanics directly.

---

## Into the Breach

A 3-mech squad tactics game on an 8x8 grid. Enemies fully telegraph their attacks before the player acts. The push mechanic is central — redirecting enemies so their attacks miss is often more valuable than direct damage.

**The power grid.** Buildings on the map are the thing being protected. Each building destroyed reduces Grid Power. If Grid Power hits zero, it's game over regardless of mech status.

**Progression within a run.** Reputation (stars) earned per mission is spent between missions on weapons, reactor cores, or Grid Power.

**Between-run progression.** Extremely restrained — horizontal unlocks only (new squads as sidegrades, not upgrades). No power creep.

**Key design lessons:**

- The power grid as a separate persistent resource is the template for Mech Engineer's territorial Power system.
- Full enemy intent visibility makes every loss feel solvable.
- Restrained meta-progression (horizontal unlocks) is correct for puzzle-identity games.
- The map structure and flavor (protecting infrastructure, territory as a resource) are direct inspirations.
- **What we are not taking:** ItB's grid-based positional combat. Mech Engineer's combat depth comes from command combinations and enemy variety, not positioning.

---

## Fire Emblem Awakening

The primary reference for the inheritance system. Children inherit stats averaged from both parents, plus one skill from each parent's active inheritance slot. The player controls which skill is in the inheritance slot before triggering the child mission — making inheritance an active strategic decision.

**Key design lesson:** Inheritance works best when it's a creative act — you choose what to pass down. The child feels authored, not random. This is exactly the design feel Mech Engineer's inheritance slot system aims for.

---

## Mewgenics

A cat-breeding tactical roguelite. Each cat can only go on one adventure before retiring permanently. Progression comes entirely from breeding better cats across generations.

**Key design lesson:** A limited-use constraint creates a legacy feel. However, one run is too short to form attachment — the constraint needs tuning. Mech Engineer uses soft decay (durability degradation) rather than a hard limit, so a single bot can develop meaningfully across multiple battles before retirement becomes a real question.

---

## Pokémon (IV / EV / Breeding Systems)

Mainline Pokémon games have evolved the deepest, longest-running stat-and-breeding system in the genre. Three interlocking layers determine a Pokémon's final combat stats:

**Base Stats** — fixed values per species. Every Bulbasaur has the same base stats. This is the "what kind of bot you have" layer.

**Individual Values (IVs)** — hidden values from 0 to 31 in each of six stats, rolled when a Pokémon is encountered or hatched. IVs are immutable once set (except via Hyper Training, which doesn't pass through breeding). At level 100, the IV adds directly to the corresponding stat — so two identical Pokémon with 0 vs 31 IVs in Attack differ by 31 stat points. This is the "innate quality" layer, the genetic dice roll. Players cannot change IVs; they can only re-roll by breeding.

**Effort Values (EVs)** — earned through battle. Each defeated Pokémon awards EVs in specific stats based on the species defeated. EVs are capped: 252 per stat, 510 total per Pokémon. Every 4 EVs in a stat add 1 point at level 100. This is the "training" layer — how the player shapes a Pokémon they've already acquired.

**Nature** — a 4th layer, randomly assigned at acquisition. Boosts one stat by 10% and reduces another by 10%. Passed down via the Everstone item during breeding.

**Stat formula** (simplified): `Stat = ((2 * Base + IV + EV/4) * Level / 100 + 5) * Nature_Modifier`

### Breeding Mechanics

This is the most directly relevant system for Mech Engineer. Without items, three random IVs from the combined pool of both parents pass to the offspring; the other three are randomly rolled. Several items dramatically alter inheritance:

- **Destiny Knot** — when held by either parent, five IVs are inherited from the combined pool of both parents (12 total IVs across both parents). Only one IV is randomly rolled for the child. This is the workhorse of competitive breeding.
- **Everstone** — guarantees the holder's Nature passes to the child.
- **Power Items** — six items, one per stat. Each guarantees that specific stat's IV transfers from the holder to the child.
- **Ditto** — a special Pokémon that can breed with nearly any species, used as a flexible parent for IV transfer.

The iterative breeding loop:
1. Catch or breed Pokémon with imperfect IVs
2. Pair the best two parents
3. Hatch offspring, check IVs
4. If offspring has more perfect IVs than the parent of the same gender, replace that parent
5. Repeat until 5-6 perfect IVs are achieved

This is essentially a generational climbing process: each generation should be slightly better than the last, with both deliberate selection (which offspring replaces which parent) and random chance (which IVs roll). The Destiny Knot widens the inheritance pool; Power Items lock specific stats; multiple breeding tools allow the player to control different aspects of inheritance simultaneously.

### Key Design Lessons for Mech Engineer

- **Three layers of stat determination** maps cleanly onto our system: Base (the bot's tech tree / species), IVs (Gen 1 random seed roll), EVs (in-fight development and personality scores). Players who understand the difference between these layers play meaningfully differently than those who don't.
- **The Destiny Knot pattern** — inheritance from a combined parent pool, with the number of inherited values being the tunable parameter — is the cleanest formal model for Mech Engineer's breeding. Default could be 3 inherited traits, with a late-game unlock or item raising it to 5.
- **Power Item pattern** — letting the player guarantee one specific trait transfers, at the cost of less control over the others, is a great way to give the player targeted intent without removing all randomness. The Mech Engineer equivalent could be "designate one stat or skill as the priority inheritance slot."
- **Hidden vs visible values** — IVs are hidden until late game; EVs are also hidden traditionally. Modern Pokémon games surfaced these to players (Gen VI+). The lesson: hidden values create mystery early but become frustrating; eventually surfacing them is correct. Mech Engineer's personality tags follow this same arc — opaque at first, with post-battle summaries surfacing the broad strokes.
- **Iterative climbing** — each generation slightly better than the last, with both deliberate and random elements — is the long-form emotional arc of the breeding meta-system. Mech Engineer's generational personality scale unlocks (Gen 1: 1 scale, Gen 2: 2 scales, Gen 3: all 3) is the same structural idea applied to dimensionality rather than stat values.
- **Hyper Training as a controversial mechanic** — Generation VII added a way to max IVs without breeding. Competitive players are split: some appreciate the time savings, others feel it cheapens the achievement. Worth noting for Mech Engineer: making breeding the *only* path to top-tier bots maintains the legacy feel, but adding a costly bypass (e.g. a rare "Optimization" upgrade) can prevent dead-end runs where the player's RNG was just bad.
- **What we are not taking:** the specific six-stat structure and the 252/510 EV cap. Mech Engineer has a different stat set (HP/Attack/Defense/Speed/Elasticity/Efficiency) and uses personality scales as the development layer rather than a per-stat EV cap. The lesson is the *structural pattern* of layered stat determination with breeding-based inheritance, not the exact numbers.

---

## Bot Arena 3

The spiritual ancestor of Mech Engineer's premise. Bots are assembled and configured before battle, then fight autonomously. Identified as a key precedent: **the interesting decisions happen before the battle.**

Bot Arena 3 leans further into autonomy than Mech Engineer will — combat in BA3 is pure spectator after configuration. Mech Engineer keeps the player active in combat through command and skill selection while still preserving the "you authored this system, now watch it work" feel for the personality and synergy layers.

---

## Backpack Battles

An auto-battler where players arrange items in a backpack inventory before combat, which then resolves autonomously. Items activate on independent cooldown timers — each item fills a highlight bar at its own rate and fires when full, then resets. Speed modifiers (Heat, Cold) accelerate or slow all cooldowns multiplicatively. Stun pauses all cooldowns for its duration. The system creates a continuous real-time combat loop where faster items act more frequently but the player has no direct control during resolution.

**Key design lessons:**

- Cooldown-based activation (how frequently a unit acts) is a richer stat than simple turn order — a unit that acts twice as often is categorically different from one that acts once.
- Speed and Efficiency as compounding stats: a fast unit that is also energy-efficient sustains high action frequency without resource exhaustion. A fast unit with poor efficiency starves the resource pool.
- The "set up then watch it resolve" structure creates emotional investment in the preparation phase — players are authoring a system, not micromanaging it.
- **What we are not taking:** pure real-time auto-resolution. Mech Engineer keeps the player active. The lesson is the cooldown timing model (which feeds into Prototype A), not the autonomous resolution.

---

## Final Fantasy 6 / 7 (ATB System)

The Active Time Battle system runs a shared timeline where each unit has a bar that fills based on their Speed stat. When a bar completes, it is that unit's turn. In **Wait mode**, the game pauses when a player unit's bar fills — the player makes their decision with no time pressure, confirms, the action resolves, and bars resume filling. Enemy bars continue filling in real time between player decisions, making enemy bar progress visible information the player uses to prioritize actions.

**Key design lessons:**

- Wait mode is the correct implementation for Mech Engineer's Prototype A — pausing on player decisions preserves full-information design while making Speed a genuinely impactful stat rather than a tiebreaker.
- A unit that acts twice as often due to higher Speed is a fundamentally different strategic asset than one that acts less frequently.
- Enemy bar progress as visible information creates reactive tactical decisions: "Enemy A is 80% full and about to hit my weakest bot — do I spend this action preventing that or advancing my own position?"
- The Active/Wait duality is the template for accessibility mode design.

---

## Across the Obelisk

A 4-character co-op deckbuilder where speed determines turn order within a round. Faster characters resolve their cards earlier, which matters significantly when their cards set up effects for slower allies.

**Key design lesson:** Party card games get slow. Speed-based turn ordering in a party game creates meaningful character differentiation, particularly when faster characters' actions enable or amplify slower ones'. This is part of what Speed needs to feel like in Prototype B (where it determines order, not frequency).

---

## Summary Table — What Each Game Contributed

| Game | Primary Contribution |
|---|---|
| Slay the Spire 1 & 2 | Three-horizon decision structure; perfect information as design philosophy; status counter UI for previewing deferred damage; six character archetypes (Ironclad, Silent, Defect, Watcher, Regent, Necrobinder) as build identity templates; STS1 as completed-design reference, STS2 as in-progress refinement case study |
| Into the Breach | Territorial power grid as persistent run resource; full enemy intent visibility; restrained meta-progression; map/flavor inspiration |
| Hades 1 | Primary damage funnel principle; duo boon cross-system multipliers; Privileged Status as conditional multiplier template |
| Hades 2 | Arcana as persistent pre-run power floor; percentage multipliers compounding multiplicatively; Origination as cross-bot synergy bonus template; Omega moves as Charge skill template |
| Monster Train | "Set up and fire" simultaneous resolution; live damage preview; undo-turn UX; flat energy cost model — basis for Prototype B |
| Backpack Battles | Cooldown-based action frequency; Speed × Efficiency as compounding stats; set-up-then-resolve emotional structure |
| Final Fantasy 6/7 (ATB) | ATB Wait mode as the basis for Prototype A; Speed as action frequency stat; enemy bar progress as visible reactive information |
| Bravely Default | Tempo framing: banking vs. spending future turns; risk of over-committing resources |
| Slice & Dice | Party card UI legibility; "no hidden mechanics" philosophy |
| Fire Emblem Awakening | Inheritance system: skill slot positioning as primary strategic act; skill level carrying through inheritance at full level |
| Mewgenics | Legacy emotional arc from limited-use constraint; soft decay preferred over hard limits |
| Pokémon | Layered stat determination (Base/IVs/EVs/Nature); Destiny Knot pattern for inheritance pool size; Power Item pattern for targeted trait transfer; iterative generational climbing |
| Bot Arena 3 | Bot-as-autonomous-agent precedent; pre-fight configuration as the primary decision space |
| Across the Obelisk | Speed-based turn ordering in party games |

---

## Games Worth Investigating Next

Not yet researched in depth but flagged as potentially relevant:

- **Wildermyth** — generational storytelling and bot-as-character attachment over time
- **Battle Brothers** — squad management with permadeath and skill tree variance per recruit
- **Darkest Dungeon 1/2** — party composition, stress as a soft clock, position-based combat (relevant as a contrast even though we're not using positioning)
- **Pit People / Cuphead-style auto-resolve party games** — for additional cooldown-resolution references beyond Backpack Battles
- **Inscryption** — for inventive deck/unit visualization and information design
- **FTL** — for run-pacing and territorial-pressure design (the rebel fleet as a resistance-equivalent)
