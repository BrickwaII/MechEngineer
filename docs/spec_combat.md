# Combat Spec
*Subsystem detail doc — last updated May 2026*

*Strategic context: see Design Doc §2 (Combat Resolution) and §3 (Damage Preview UI)*

This document covers everything implementation-adjacent for the combat system: the two prototype designs, energy economy, damage calculation, enemy AI patterns, the prototype skill set, and the UI architecture for both prototypes.

---

## 1. Overview

Two prototypes are being built in parallel. They share as much code and data as possible. Only the resolution model differs.

- **Prototype A** — ATB (Active Time Battle, Wait Mode)
- **Prototype B** — Simultaneous Resolution (Monster Train / STS-style)

The shared core includes data models, damage calculation, personality tag logging, bot/enemy card UI, and the prototype skill set. Each prototype has its own battle scene and unique UI elements.

---

## 2. Shared Data Models

All defined as Godot Resources for editor visibility and easy iteration.

### BotData
```
- id: String
- name: String
- color: Color
- portrait: Texture2D
- hp: int
- max_hp: int
- attack: int
- defense: int
- speed: int
- elasticity: float
- efficiency: float
- generation: int
- personality: PersonalityData
- skill_slots: Dictionary  # command_type -> Array[SkillData]
- assigned_skill: SkillData  # current turn assignment (Prototype B)
- charge_state: ChargeState
- action_log: Array  # per-battle tag log
```

### PersonalityData
```
- aggressive_defensive: float  # -5 to +5
- solitary_supportive: float   # -5 to +5
- reactive_methodical: float   # -5 to +5
- active_scales: int           # 1, 2, or 3 based on generation
```

### SkillData
```
- skill_name: String
- command_type: String     # "attack" | "defend" | "support" | "charge"
- energy_cost: int
- multiplier: float
- effect_type: String      # "damage" | "defend" | "buff" | "charge" | "heal"
- effect_value: float
- target_type: String      # "single_enemy" | "all_enemies" | "self" | "single_ally" | "all_allies" | "random_enemy"
- hit_count_min: int       # for variance skills like Frenzy
- hit_count_max: int
- armor_piercing: bool
- level: int
- max_level: int
- tags: Array[String]      # personality tags this skill always generates
```

### EnemyData
```
- id: String
- name: String
- personality_archetype: String  # "bruiser" | "tactician" | "berserker" | "supporter" | "predator"
- hp: int
- max_hp: int
- attack: int
- defense: int
- speed: int
- intent_loop: Array[IntentData]
- current_intent_index: int
- current_intent: IntentData
- status_effects: Array[StatusEffect]
```

### IntentData
```
- intent_type: String      # "attack" | "defend" | "power_up" | "buff_ally" | "recover" | "attack_weakest"
- value: int               # damage amount, defense gained, etc.
- target_resolution: String # "fixed" | "weakest" | "random" | "self"
- display_label: String
- display_icon: Texture2D
```

### ChargeState
```
- is_charged: bool
- is_overloaded: bool
- multiplier: float        # 2.0 for charged, 3.0 for overloaded
```

---

## 3. Damage Calculation

Single shared module, used by both prototypes.

```gdscript
class_name DamageCalculator extends RefCounted

static func calculate_attack(attacker, skill: SkillData, target) -> int:
    var base_damage = attacker.attack * skill.multiplier
    
    # apply charge state if present
    if attacker.charge_state.is_charged or attacker.charge_state.is_overloaded:
        base_damage *= attacker.charge_state.multiplier
    
    # apply defense reduction unless armor-piercing
    var final_damage = base_damage
    if not skill.armor_piercing:
        final_damage = max(0, base_damage - target.defense)
    
    return int(final_damage)

static func calculate_defend(bot, skill: SkillData) -> int:
    # Defend command produces defense bonus for this round/turn
    return int(bot.defense * skill.multiplier)

static func calculate_incoming_damage(enemy, intent: IntentData, target_bot, target_assignment: SkillData = null) -> int:
    # Used by damage preview to show what enemies will do
    var base = intent.value
    
    # if target_bot is assigned a Defend skill, apply its defend bonus
    if target_assignment and target_assignment.command_type == "defend":
        var defend_bonus = calculate_defend(target_bot, target_assignment)
        base = max(0, base - defend_bonus)
    
    return int(base)
```

---

## 4. The Prototype Skill Set (14 skills)

These are the working skill set for the prototype. Final skill list will expand significantly during full development.

### Attack (5)

| Skill | Cost | Multiplier | Target | Notes | Tags |
|---|---|---|---|---|---|
| Standard Attack | 1 | 1.0× | single | baseline | `dealing-damage` |
| Power Shot | 2 | 1.5× | single | high single-target | `dealing-damage`, `methodical` |
| Spread Shot | 2 | 0.75× | all enemies | AoE | `dealing-damage` |
| Frenzy | 2 | 0.5× | 2–4 random | variance, hits multiple times | `dealing-damage`, `reckless` |
| Crippling Shot | 2 | 1.0× | single | -2 Attack to target next turn | `dealing-damage`, `methodical` |

### Defend (3)

| Skill | Cost | Effect | Tags |
|---|---|---|---|
| Standard Defend | 1 | +defense for this round/turn | `absorbing-damage` |
| Counter Stance | 2 | +defense, retaliates 0.5× when hit | `absorbing-damage`, `responding-to-threat` |
| Bulwark | 2 | +defense, shares half with weakest ally | `absorbing-damage`, `buffing-ally` |

### Support (3)

| Skill | Cost | Effect | Tags |
|---|---|---|---|
| Standard Support | 1 | +2 Attack/Defense to all allies | `buffing-ally` |
| Battle Cry | 2 | +4 Attack to one ally | `buffing-ally` |
| Medic Protocol | 2 | +6 HP to one ally | `buffing-ally`, `responding-to-threat` |

### Charge (3)

| Skill | Cost | Effect | Tags |
|---|---|---|---|
| Standard Charge | 1 | next Attack/Defend ×2 | `planning-ahead` |
| Overload | 2 | next Attack/Defend ×3, self takes 3 damage | `planning-ahead`, `reckless` |
| Team Charge | 2 | charge self + +2 Attack to one ally | `planning-ahead`, `buffing-ally` |

---

## 5. Enemy AI Patterns

Five enemy personality archetypes for the prototype. Each has a fixed intent loop that cycles. Intent is always visible before execution.

### Bruiser (Aggressive/Solitary)
```
intent_loop: [Attack, Attack, Defend]
```
Straightforward, telegraphs clearly, easy to read. Tests basic combat flow.

### Tactician (Methodical/Defensive)
```
intent_loop: [Defend, PowerUp, Attack, Attack]
```
Builds up before striking. Hits harder after PowerUp. Tests whether player can interrupt setup turns.

### Berserker (Aggressive/Reactive)
```
intent_loop: [Attack, Attack, Attack, Recover]
```
Relentless offense then one vulnerable recovery turn. Tests timing — can the player capitalize on the recovery window?

### Supporter (Supportive/Methodical)
```
intent_loop: [BuffAlly, Defend, Attack]
```
Buffs a teammate before acting. Creates priority targeting decisions — kill the buffer or the buffed ally first?

### Predator (Reactive/Solitary)
```
intent_loop: [AttackWeakest, AttackWeakest, Defend]
```
Always targets lowest HP bot. Tests threat prioritization — do you protect vulnerable bots or accept the damage?

---

## 6. Prototype A — ATB Architecture

### Combat Flow

1. All bots and enemies start with ATBBar at 0%
2. Bars fill continuously based on Speed stat
3. Energy regenerates continuously at base rate (tunable)
4. When any bar reaches 100%:
   - If enemy: pause briefly, resolve their telegraphed intent, set next intent, reset bar, resume
   - If player bot: pause all bars, show DecisionPanel for that bot, wait for player input
5. Player selects skill and target, action resolves, bar resets, all bars resume
6. Continue until victory or defeat

### Key New Components

**ATBBar.gd** — one per unit
```gdscript
class_name ATBBar extends Control

signal bar_filled(unit)

@export var fill_speed_modifier: float = 1.0  # for tuning
var fill_percent: float = 0.0
var is_paused: bool = false
var is_ready: bool = false
var owner_unit  # BotData or EnemyData

func _process(delta: float) -> void:
    if is_paused or is_ready:
        return
    fill_percent += (owner_unit.speed / 100.0) * fill_speed_modifier * delta
    if fill_percent >= 1.0:
        fill_percent = 1.0
        is_ready = true
        emit_signal("bar_filled", owner_unit)
    _update_visual()

func _update_visual() -> void:
    $BarFill.size.x = $BarBackground.size.x * fill_percent

func pause() -> void:
    is_paused = true

func resume() -> void:
    is_paused = false

func reset() -> void:
    fill_percent = 0.0
    is_ready = false
```

**ATBTimeline.gd** — coordinator, lives on ATBBattleScene
```gdscript
class_name ATBTimeline extends Node

var all_bars: Array[ATBBar] = []
var energy_pool: float = 0.0
var energy_regen_rate: float = 1.0  # energy per second
var is_globally_paused: bool = false

func _ready() -> void:
    for bar in all_bars:
        bar.bar_filled.connect(_on_bar_filled)

func _process(delta: float) -> void:
    if not is_globally_paused:
        energy_pool += energy_regen_rate * delta

func _on_bar_filled(unit) -> void:
    pause_all()
    if unit is BotData:
        _show_decision_panel(unit)
    else:
        _resolve_enemy_intent(unit)
        unit.atb_bar.reset()
        resume_all()

func pause_all() -> void:
    is_globally_paused = true
    for bar in all_bars: bar.pause()

func resume_all() -> void:
    is_globally_paused = false
    for bar in all_bars: bar.resume()

func on_player_action_confirmed(bot, skill, target) -> void:
    _execute_player_action(bot, skill, target)
    bot.atb_bar.reset()
    _hide_decision_panel()
    resume_all()
```

### Prototype A UI Layout

```
┌──────────────────────────────────────────────────────────┐
│              ENERGY: 47.3 / 100 (regen +1/s)             │
├──────────────────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                  │
│  │ ENEMY 1 │  │ ENEMY 2 │  │ ENEMY 3 │                  │
│  │  HP ▓▓░ │  │  HP ▓▓▓ │  │  HP ▓░░ │                  │
│  │  ⚔ 12   │  │  🛡 def │  │  ⚔ 8    │   ← intents     │
│  │ [▓▓▓░░░]│  │ [▓░░░░░]│  │ [▓▓▓▓▓░]│   ← ATB bars    │
│  └─────────┘  └─────────┘  └─────────┘                  │
│                                                          │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                  │
│  │  ATLAS  │  │  WREN   │  │  CORVUS │                  │
│  │  HP ▓▓▓ │  │  HP ▓▓░ │  │  HP ▓▓▓ │                  │
│  │ [▓▓▓▓▓▓]│  │ [▓▓░░░░]│  │ [▓▓▓░░░]│ ← ATLAS ready!  │
│  │ ⚡READY │  │         │  │         │                  │
│  └─────────┘  └─────────┘  └─────────┘                  │
└──────────────────────────────────────────────────────────┘

WHEN ATLAS BAR FILLS, OVERLAY APPEARS:

┌──────────────────────────────────────────────────────────┐
│              ATLAS — YOUR TURN                           │
├──────────────────────────────────────────────────────────┤
│  Attack:                                                 │
│    [Standard Attack] [Power Shot] [Spread Shot]         │
│  Defend:                                                 │
│    [Standard Defend] [Counter Stance]                   │
│  Support:                                                │
│    [Battle Cry]                                          │
│  Charge:                                                 │
│    [Standard Charge]                                     │
│                                                          │
│  Select target →                                         │
└──────────────────────────────────────────────────────────┘
```

### Action Preview (Prototype A)

When the player hovers a skill in the DecisionPanel:
- Clear all existing previews
- For each valid target, calculate projected outcome
- Display preview on each target's card (red drain for damage, green for healing, etc.)
- If skill targets enemies that have intents pointed at allies, update those incoming damage previews to reflect any defense changes
- Variance skills show ranges ("7–14") rather than exact numbers

---

## 7. Prototype B — Simultaneous Resolution Architecture

### Combat Flow

1. Round begins. All enemies display intent for this round.
2. Energy pool set to round budget (e.g. 4 energy).
3. Planning phase: player assigns commands to bots one at a time.
4. Each assignment decrements energy. Live damage preview updates after every assignment.
5. Player can undo last assignment (restores energy, recalculates previews).
6. Player confirms.
7. Resolution phase: all assignments execute simultaneously in Speed order. Defend bots act first, then sorted by Speed.
8. Enemy turn resolves.
9. Round ends. Personality tags logged.
10. Next round begins.

### Key New Components

**SimBattle.gd** — main controller
```gdscript
class_name SimBattle extends Node

enum State { PLANNING, RESOLVING, ROUND_END }

var state: State = State.PLANNING
var assignments: Dictionary = {}  # bot_id -> {skill, target}
var energy_remaining: int
var energy_budget: int = 4  # tunable
var current_round: int = 0

signal planning_started
signal assignment_made(bot, skill, target)
signal assignment_undone(bot)
signal resolution_started
signal round_ended

func start_round() -> void:
    current_round += 1
    assignments.clear()
    energy_remaining = energy_budget
    state = State.PLANNING
    emit_signal("planning_started")
    _update_all_previews()

func make_assignment(bot, skill, target) -> bool:
    if skill.energy_cost > energy_remaining:
        return false
    if bot.id in assignments:
        return false  # already assigned
    
    assignments[bot.id] = {"skill": skill, "target": target}
    energy_remaining -= skill.energy_cost
    emit_signal("assignment_made", bot, skill, target)
    _update_all_previews()
    return true

func undo_last_assignment() -> void:
    if assignments.is_empty():
        return
    var last_bot_id = assignments.keys()[-1]
    var last_assignment = assignments[last_bot_id]
    energy_remaining += last_assignment.skill.energy_cost
    assignments.erase(last_bot_id)
    emit_signal("assignment_undone", last_bot_id)
    _update_all_previews()

func confirm_assignments() -> void:
    state = State.RESOLVING
    emit_signal("resolution_started")
    _resolve_simultaneously()

func _resolve_simultaneously() -> void:
    # 1. Defend bots act first (apply defense bonus)
    # 2. Then sort remaining by Speed, descending
    # 3. Execute each action in order
    # 4. Log tags
    # 5. Resolve enemy intents
    # 6. End round
    ...
```

**LivePreviewSystem.gd** — recalculates all previews on every assignment change
```gdscript
class_name LivePreviewSystem extends Node

func update_all_previews(bots, enemies, assignments) -> void:
    _clear_all_previews(bots, enemies)
    _preview_outgoing_damage(bots, enemies, assignments)
    _preview_incoming_damage(bots, enemies, assignments)
    _preview_charge_states(bots, assignments)
    _preview_buff_effects(bots, assignments)

func _preview_outgoing_damage(bots, enemies, assignments) -> void:
    for bot_id in assignments:
        var assignment = assignments[bot_id]
        var bot = _get_bot(bots, bot_id)
        var skill = assignment.skill
        
        if skill.effect_type != "damage":
            continue
        
        if skill.target_type == "all_enemies":
            for enemy in enemies:
                var dmg = DamageCalculator.calculate_attack(bot, skill, enemy)
                _show_damage_preview(enemy, dmg)
        else:
            var target = assignment.target
            var dmg = DamageCalculator.calculate_attack(bot, skill, target)
            _show_damage_preview(target, dmg)

func _preview_incoming_damage(bots, enemies, assignments) -> void:
    for enemy in enemies:
        var intent = enemy.current_intent
        if intent.intent_type != "attack":
            continue
        var target_bot = _resolve_intent_target(intent, bots)
        var target_assignment = assignments.get(target_bot.id, null)
        var target_skill = target_assignment.skill if target_assignment else null
        var dmg = DamageCalculator.calculate_incoming_damage(enemy, intent, target_bot, target_skill)
        _show_damage_preview(target_bot, dmg)
```

### Prototype B UI Layout

```
┌──────────────────────────────────────────────────────────┐
│           ROUND 3 — ENERGY: 2 / 4 remaining              │
├──────────────────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                  │
│  │ ENEMY 1 │  │ ENEMY 2 │  │ ENEMY 3 │                  │
│  │  HP ▓▓░ │  │  HP ▓▓▓ │  │  HP ▓░░ │                  │
│  │  ⚔ 12 → │  │  🛡 def │  │  ⚔ 8 → │                   │
│  │  -8 prev│  │         │  │  -5 prev│ ← damage preview │
│  └─────────┘  └─────────┘  └─────────┘                  │
│       ▲              ▲                                   │
│       │ player       │ player                            │
│       │ assignment   │ assignment                        │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                  │
│  │  ATLAS  │  │  WREN   │  │  CORVUS │                  │
│  │ ASSIGNED│  │ ASSIGNED│  │  ready  │                  │
│  │ Pow.Shot│  │ Defend  │  │  to     │                  │
│  │         │  │         │  │  assign │                  │
│  └─────────┘  └─────────┘  └─────────┘                  │
├──────────────────────────────────────────────────────────┤
│  ASSIGNMENT QUEUE                                        │
│  ✓ ATLAS → Power Shot → Enemy 1 (proj. 8 dmg)           │
│  ✓ WREN  → Defend (self)                                 │
│  _ CORVUS (unassigned)                                   │
│                                                          │
│  [UNDO LAST]              [EXECUTE ORDERS ▶]            │
└──────────────────────────────────────────────────────────┘
```

### Action Preview (Prototype B)

Live, continuously updating system. Every assignment change recalculates:

**Outgoing damage previews** (on enemy cards):
- Red drain segment on HP bar
- Numerical damage label
- Skull icon if projected death
- For AoE skills: preview shown on all affected enemies

**Incoming damage previews** (on bot cards):
- Red drain segment from enemy intents
- Reduced based on bot's assigned Defend skill if any
- Skull icon if projected death without Defend
- Green "saved" indicator if Defend prevents death

**Buff/heal previews** (on bot cards):
- Green tint on the buff target
- "+4 ATK" or "+6 HP" label
- Stacks visually if multiple buffs target the same bot

**Charge state previews** (on bot cards):
- "CHARGED ×2" badge if Standard Charge assigned
- "OVERLOADED ×3 (-3 HP)" badge if Overload assigned
- Note: these affect *next round's* projections, not this round's

---

## 8. Shared UI Components

These are used by both prototypes.

### BotCard scene structure
```
BotCard (PanelContainer)
└── VBoxContainer
    ├── Header (HBoxContainer)
    │   ├── BotName (Label)
    │   └── BotColor (ColorRect)
    ├── Portrait (TextureRect)
    ├── HPBar (HBoxContainer)
    │   ├── HPBarFill (ProgressBar)
    │   └── HPLabel (Label)
    ├── PreviewOverlay (Control)
    │   ├── DamagePreviewBar (ColorRect)
    │   ├── SkullIcon (TextureRect)
    │   └── SavedIcon (TextureRect)
    ├── StatsRow (HBoxContainer)
    │   ├── AttackLabel
    │   ├── DefenseLabel
    │   └── SpeedLabel
    ├── PersonalityBars (VBoxContainer)
    │   ├── Scale1Bar
    │   ├── Scale2Bar
    │   └── Scale3Bar
    ├── ChargeIndicator (Label)
    ├── AssignedSkillDisplay (Label)  # Prototype B
    ├── ATBBar (Prototype A only)
    └── SkillSlots (HBoxContainer)
```

### EnemyCard scene structure
```
EnemyCard (PanelContainer)
└── VBoxContainer
    ├── EnemyName (Label)
    ├── Portrait (TextureRect)
    ├── HPBar (HBoxContainer)
    │   ├── HPBarFill (ProgressBar)
    │   └── HPLabel (Label)
    ├── PreviewOverlay (Control)
    │   ├── DamagePreviewBar (ColorRect)
    │   └── SkullIcon (TextureRect)
    ├── IntentDisplay (VBoxContainer)
    │   ├── IntentIcon (TextureRect)
    │   └── IntentLabel (Label)
    ├── StatusEffects (HBoxContainer)
    └── ATBBar (Prototype A only)
```

### ArrowLayer system

Intent arrows drawn as Line2D nodes in a top-level Control layer (rendered above all cards). Used for both enemy intent telegraphing and (Prototype B) player assignment previews.

```gdscript
class_name ArrowLayer extends Control

var active_arrows: Array = []

func draw_arrow(from_card: Control, to_card: Control, color: Color, label: String) -> void:
    var arrow = Line2D.new()
    arrow.width = 3.0
    arrow.default_color = color
    arrow.add_point(from_card.global_position + from_card.size / 2)
    arrow.add_point(to_card.global_position + to_card.size / 2)
    add_child(arrow)
    
    var lbl = Label.new()
    lbl.text = label
    lbl.position = (arrow.get_point_position(0) + arrow.get_point_position(1)) / 2
    add_child(lbl)
    
    active_arrows.append(arrow)
    active_arrows.append(lbl)

func clear_all() -> void:
    for node in active_arrows:
        node.queue_free()
    active_arrows.clear()
```

Color conventions:
- **Red dashed** — enemy intent arrows
- **Green solid** — player buff/support assignments (Prototype B)
- **Red solid** — player attack assignments (Prototype B)

---

## 9. File Structure

```
scenes/
├── shared/
│   ├── bot_card.tscn
│   ├── enemy_card.tscn
│   ├── skill_button.tscn
│   ├── personality_scale_bar.tscn
│   ├── energy_display.tscn
│   └── action_log.tscn
├── prototype_a/
│   ├── atb_battle.tscn
│   ├── atb_bar.tscn
│   └── decision_panel.tscn
└── prototype_b/
    ├── sim_battle.tscn
    └── assignment_queue.tscn

scripts/
├── shared/
│   ├── bot_data.gd
│   ├── enemy_data.gd
│   ├── skill_data.gd
│   ├── intent_data.gd
│   ├── personality_data.gd
│   ├── charge_state.gd
│   ├── damage_calculator.gd
│   ├── tag_logger.gd
│   └── arrow_layer.gd
├── prototype_a/
│   ├── atb_battle.gd
│   ├── atb_bar.gd
│   ├── atb_timeline.gd
│   └── decision_panel.gd
└── prototype_b/
    ├── sim_battle.gd
    ├── live_preview_system.gd
    └── assignment_queue.gd

data/
├── skills/         # SkillData resources, one per skill
├── enemies/        # EnemyData resources, one per archetype
└── bots/           # BotData resources for starter bots
```

---

## 10. Build Order Recommendation

1. **Shared data models** — all the .gd resource scripts
2. **Damage calculator** — pure logic, easy to test
3. **Tag logger** — same, pure logic
4. **BotCard and EnemyCard scenes** — visual layer, can be tested with hardcoded data
5. **One prototype skill** end-to-end through both systems to validate the data flow
6. **Pick a prototype to build first** — recommended: Prototype B (Simultaneous), since it requires less new infrastructure than ATB
7. **Build that prototype to completion** with the 3v3 fight working end-to-end
8. **Then build the other prototype** reusing as much of the shared layer as possible
9. **Playtest both** with the same fixed encounter and compare feel

---

## 11. Open Implementation Questions

- Exact energy regen rate for Prototype A — needs tuning relative to skill costs
- Exact energy budget per round for Prototype B — needs tuning relative to skill costs
- How the undo system handles partial states cleanly in Prototype B
- Whether ATB bars should pause during animation playback or only during decision panels
- How Charge state visually persists across turns/rounds in both prototypes

*Strategic context for any of the above: see Design Doc §2*

---

*Related specs: `spec_personality.md` (tag logging detail), `spec_skills.md` (full skill list and leveling), `spec_enemy.md` (AI patterns expanded)*
