# Shared Core Spec
*Subsystem detail doc — last updated May 2026*

*Strategic context: see Design Doc §1–§6. Related: `spec_combat.md`, `spec_personality.md`*

This document defines everything both combat prototypes share: data models, calculation modules, shared UI scenes, and the prototype skill/enemy data resources. Code is written as actual GDScript and intended to be nearly copy-pasteable into the Godot 4 project.

The existing repo has folders `battle/`, `bots/`, and `systems/`. This spec assumes:
- **`systems/`** — shared logic modules (damage calc, tag logger)
- **`bots/`** — bot-related data and scenes
- **`battle/`** — battle scenes and prototype-specific controllers

Adjust naming to match what already exists in the repo.

---

## 1. File Structure (Shared Layer)

```
systems/
├── data/
│   ├── bot_data.gd               # Resource class
│   ├── enemy_data.gd             # Resource class
│   ├── skill_data.gd             # Resource class
│   ├── intent_data.gd            # Resource class
│   ├── personality_data.gd       # Resource class
│   └── charge_state.gd           # Resource class
├── damage_calculator.gd          # RefCounted utility
├── tag_logger.gd                 # RefCounted utility
└── arrow_layer.gd                # Control script

bots/
├── scenes/
│   ├── bot_card.tscn
│   ├── enemy_card.tscn
│   ├── skill_button.tscn
│   ├── personality_scale_bar.tscn
│   └── energy_display.tscn
└── scripts/
    ├── bot_card.gd
    ├── enemy_card.gd
    ├── skill_button.gd
    ├── personality_scale_bar.gd
    └── energy_display.gd

data/
├── skills/                       # .tres SkillData resources
│   ├── attack_standard.tres
│   ├── attack_power_shot.tres
│   ├── ... (14 total)
├── enemies/                      # .tres EnemyData resources
│   ├── enemy_bruiser.tres
│   ├── enemy_tactician.tres
│   ├── ... (5 total)
└── bots/                         # .tres BotData resources for test bots
```

---

## 2. Data Models

### bot_data.gd

```gdscript
class_name BotData extends Resource

@export var id: String = ""
@export var bot_name: String = ""
@export var color: Color = Color.WHITE
@export var portrait: Texture2D

# Core stats
@export var hp: int = 30
@export var max_hp: int = 30
@export var attack: int = 10
@export var defense: int = 5
@export var speed: int = 50
@export var elasticity: float = 10.0
@export var efficiency: float = 1.0

# Generation tracking
@export var generation: int = 1

# Sub-resources
@export var personality: PersonalityData
@export var charge_state: ChargeState

# Skills indexed by command type
# Dictionary[String, Array[SkillData]]
@export var skill_slots: Dictionary = {
    "attack": [],
    "defend": [],
    "support": [],
    "charge": []
}

# Runtime state — not exported, not saved
var assigned_skill: SkillData = null      # Prototype B
var assigned_target = null                # Prototype B
var action_log: Array = []                # tag logs accumulated this battle
var atb_bar_ref: Control = null           # Prototype A — reference set at battle start

func _init() -> void:
    if personality == null:
        personality = PersonalityData.new()
    if charge_state == null:
        charge_state = ChargeState.new()

func is_alive() -> bool:
    return hp > 0

func take_damage(amount: int) -> void:
    hp = max(0, hp - amount)

func heal(amount: int) -> void:
    hp = min(max_hp, hp + amount)

func clear_assignment() -> void:
    assigned_skill = null
    assigned_target = null

func get_available_skills_for_energy(available_energy: int) -> Array:
    var result := []
    for command in skill_slots:
        for skill in skill_slots[command]:
            if skill.energy_cost <= available_energy:
                result.append(skill)
    return result
```

### enemy_data.gd

```gdscript
class_name EnemyData extends Resource

@export var id: String = ""
@export var enemy_name: String = ""
@export var portrait: Texture2D
@export var personality_archetype: String = "bruiser"

# Core stats
@export var hp: int = 25
@export var max_hp: int = 25
@export var attack: int = 8
@export var defense: int = 3
@export var speed: int = 40

# Intent loop — defines AI pattern
@export var intent_loop: Array[IntentData] = []

# Runtime state
var current_intent_index: int = 0
var current_intent: IntentData = null
var status_effects: Array = []
var atb_bar_ref: Control = null

func _init() -> void:
    pass

func is_alive() -> bool:
    return hp > 0

func take_damage(amount: int) -> void:
    hp = max(0, hp - amount)

func get_next_intent() -> IntentData:
    if intent_loop.is_empty():
        return null
    return intent_loop[current_intent_index]

func advance_intent() -> void:
    if intent_loop.is_empty():
        return
    current_intent_index = (current_intent_index + 1) % intent_loop.size()
    current_intent = intent_loop[current_intent_index]
```

### skill_data.gd

```gdscript
class_name SkillData extends Resource

@export var skill_name: String = ""
@export var command_type: String = "attack"   # attack | defend | support | charge
@export var energy_cost: int = 1
@export var multiplier: float = 1.0
@export var effect_type: String = "damage"    # damage | defend | buff | charge | heal
@export var effect_value: float = 0.0
@export var target_type: String = "single_enemy"
    # single_enemy | all_enemies | random_enemy
    # self | single_ally | all_allies
@export var hit_count_min: int = 1
@export var hit_count_max: int = 1
@export var armor_piercing: bool = false
@export var level: int = 1
@export var max_level: int = 5
@export var tags: Array[String] = []

# Optional secondary effect (e.g. Crippling Shot reduces target Attack)
@export var secondary_effect_type: String = ""    # "reduce_attack" | "share_defense" | "self_damage"
@export var secondary_effect_value: float = 0.0

func is_variance_skill() -> bool:
    return hit_count_min != hit_count_max

func get_display_damage_range(attacker: BotData) -> String:
    if not is_variance_skill():
        var base = int(attacker.attack * multiplier)
        return str(base)
    var min_dmg = int(attacker.attack * multiplier * hit_count_min)
    var max_dmg = int(attacker.attack * multiplier * hit_count_max)
    return "%d-%d" % [min_dmg, max_dmg]
```

### intent_data.gd

```gdscript
class_name IntentData extends Resource

@export var intent_type: String = "attack"
    # attack | defend | power_up | buff_ally | recover | attack_weakest
@export var value: int = 0
@export var target_resolution: String = "fixed"
    # fixed | weakest_bot | strongest_bot | random_bot | self | ally
@export var display_label: String = ""
@export var display_icon: Texture2D
```

### personality_data.gd

```gdscript
class_name PersonalityData extends Resource

# Each scale: -5.0 to +5.0, 0 is neutral
@export var aggressive_defensive: float = 0.0
@export var solitary_supportive: float = 0.0
@export var reactive_methodical: float = 0.0

# Which scales are active based on generation
# Gen 1: 1 scale. Gen 2: 2 scales. Gen 3+: all 3.
@export var active_scales: Array[String] = ["aggressive_defensive"]

func get_scale(scale_name: String) -> float:
    match scale_name:
        "aggressive_defensive": return aggressive_defensive
        "solitary_supportive": return solitary_supportive
        "reactive_methodical": return reactive_methodical
    return 0.0

func set_scale(scale_name: String, value: float) -> void:
    var clamped := clamp(value, -5.0, 5.0)
    match scale_name:
        "aggressive_defensive": aggressive_defensive = clamped
        "solitary_supportive": solitary_supportive = clamped
        "reactive_methodical": reactive_methodical = clamped

func is_scale_active(scale_name: String) -> bool:
    return scale_name in active_scales

func get_emergent_label() -> String:
    # Returns the best-fit label based on current scale positions
    # Full crystallization logic — see spec_personality.md §9
    
    if active_scales.size() < 3:
        return _get_partial_label()
    
    var agg_def = "Aggressive" if aggressive_defensive < -2.0 else ("Defensive" if aggressive_defensive > 2.0 else "")
    var sol_sup = "Solitary" if solitary_supportive < -2.0 else ("Supportive" if solitary_supportive > 2.0 else "")
    var rea_met = "Reactive" if reactive_methodical < -2.0 else ("Methodical" if reactive_methodical > 2.0 else "")
    
    if agg_def == "" or sol_sup == "" or rea_met == "":
        return "Developing"
    
    var key = "%s/%s/%s" % [agg_def, sol_sup, rea_met]
    match key:
        "Aggressive/Solitary/Reactive": return "Berserker"
        "Aggressive/Solitary/Methodical": return "Assassin"
        "Aggressive/Supportive/Reactive": return "Aggressor"
        "Aggressive/Supportive/Methodical": return "Vanguard"
        "Defensive/Solitary/Reactive": return "Coward"
        "Defensive/Solitary/Methodical": return "Fortress"
        "Defensive/Supportive/Reactive": return "Savior"
        "Defensive/Supportive/Methodical": return "Commander"
    return "Developing"

func _get_partial_label() -> String:
    # Gen 1 / Gen 2 partial labels — placeholder names
    if active_scales.size() == 1:
        var scale = active_scales[0]
        var val = get_scale(scale)
        if abs(val) < 2.0: return "Developing"
        match scale:
            "aggressive_defensive": return "Striker" if val < 0 else "Guard"
            "solitary_supportive": return "Loner" if val < 0 else "Helper"
            "reactive_methodical": return "Reflexive" if val < 0 else "Planner"
    return "Developing"
```

### charge_state.gd

```gdscript
class_name ChargeState extends Resource

@export var is_charged: bool = false
@export var is_overloaded: bool = false
@export var multiplier: float = 1.0

func apply_charge() -> void:
    is_charged = true
    is_overloaded = false
    multiplier = 2.0

func apply_overload() -> void:
    is_charged = false
    is_overloaded = true
    multiplier = 3.0

func consume() -> void:
    is_charged = false
    is_overloaded = false
    multiplier = 1.0

func is_active() -> bool:
    return is_charged or is_overloaded

func get_label() -> String:
    if is_overloaded: return "OVERLOADED x3"
    if is_charged: return "CHARGED x2"
    return ""
```

---

## 3. Damage Calculator

### damage_calculator.gd

```gdscript
class_name DamageCalculator extends RefCounted

static func calculate_attack(attacker: BotData, skill: SkillData, target) -> int:
    var base_damage: float = attacker.attack * skill.multiplier
    
    if attacker.charge_state.is_active():
        base_damage *= attacker.charge_state.multiplier
    
    var target_defense: int = target.defense if "defense" in target else 0
    
    var final_damage: float = base_damage
    if not skill.armor_piercing:
        final_damage = max(0.0, base_damage - target_defense)
    
    return int(final_damage)

static func calculate_attack_range(attacker: BotData, skill: SkillData, target) -> Vector2i:
    # For variance skills like Frenzy. Returns Vector2i(min, max).
    var per_hit: float = attacker.attack * skill.multiplier
    if attacker.charge_state.is_active():
        per_hit *= attacker.charge_state.multiplier
    
    var target_defense: int = target.defense if "defense" in target else 0
    if not skill.armor_piercing:
        per_hit = max(0.0, per_hit - target_defense)
    
    var min_total = int(per_hit * skill.hit_count_min)
    var max_total = int(per_hit * skill.hit_count_max)
    return Vector2i(min_total, max_total)

static func calculate_defend_bonus(bot: BotData, skill: SkillData) -> int:
    return int(bot.defense * skill.multiplier)

static func calculate_incoming_damage(
    enemy: EnemyData,
    intent: IntentData,
    target_bot: BotData,
    target_assignment: SkillData = null
) -> int:
    if intent.intent_type != "attack" and intent.intent_type != "attack_weakest":
        return 0
    
    var base: int = intent.value
    
    if target_assignment != null and target_assignment.command_type == "defend":
        var defend_bonus := calculate_defend_bonus(target_bot, target_assignment)
        base = max(0, base - defend_bonus)
    
    base = max(0, base - target_bot.defense)
    
    return base

static func will_die(unit, incoming_damage: int) -> bool:
    return unit.hp - incoming_damage <= 0
```

---

## 4. Tag Logger

### tag_logger.gd

```gdscript
class_name TagLogger extends RefCounted

# Logs an action as tags on the acting bot's action_log array.
# The action_log is processed at end of battle (see spec_personality.md).

static func log_action(
    bot: BotData,
    skill: SkillData,
    target,
    bots_on_field: Array,
    enemies_on_field: Array
) -> void:
    var entry := {
        "skill_name": skill.skill_name,
        "target_id": _get_target_id(target),
        "tags": []
    }
    
    # Action tags from the skill itself
    for tag in skill.tags:
        entry.tags.append(tag)
    
    # Target tags
    var target_tags := _compute_target_tags(skill, target, bots_on_field, enemies_on_field)
    for tag in target_tags:
        entry.tags.append(tag)
    
    # Context tags
    var context_tags := _compute_context_tags(bot, bots_on_field, enemies_on_field)
    for tag in context_tags:
        entry.tags.append(tag)
    
    bot.action_log.append(entry)

static func _get_target_id(target) -> String:
    if target == null:
        return ""
    if "id" in target:
        return target.id
    return ""

static func _compute_target_tags(
    skill: SkillData,
    target,
    bots: Array,
    enemies: Array
) -> Array:
    var tags := []
    
    if skill.target_type == "self":
        tags.append("target-self")
        return tags
    
    if skill.target_type == "all_enemies":
        tags.append("target-all-enemies")
        return tags
    
    if skill.target_type == "all_allies":
        tags.append("target-all-allies")
        return tags
    
    # Single-target — analyze the target
    if target is EnemyData:
        var hp_pct: float = float(target.hp) / float(target.max_hp)
        if hp_pct < 0.34:
            tags.append("target-lowest-hp-enemy")
        elif hp_pct > 0.75:
            tags.append("target-highest-hp-enemy")
        
        # Was this enemy targeting one of our bots?
        if target.current_intent != null:
            if target.current_intent.intent_type in ["attack", "attack_weakest"]:
                tags.append("target-enemy-threatening-ally")
    
    elif target is BotData:
        var hp_pct: float = float(target.hp) / float(target.max_hp)
        if hp_pct < 0.34:
            tags.append("target-weakest-ally")
    
    return tags

static func _compute_context_tags(
    bot: BotData,
    bots: Array,
    enemies: Array
) -> Array:
    var tags := []
    
    var self_pct: float = float(bot.hp) / float(bot.max_hp)
    if self_pct < 0.15:
        tags.append("self-is-critical")
    elif self_pct < 0.34:
        tags.append("self-is-low-hp")
    
    var any_ally_low := false
    for ally in bots:
        if ally == bot or not ally.is_alive(): continue
        if float(ally.hp) / float(ally.max_hp) < 0.34:
            any_ally_low = true
            break
    if any_ally_low:
        tags.append("ally-is-low-hp")
    
    var any_enemy_low := false
    for enemy in enemies:
        if not enemy.is_alive(): continue
        if float(enemy.hp) / float(enemy.max_hp) < 0.34:
            any_enemy_low = true
            break
    if any_enemy_low:
        tags.append("enemy-is-low-hp")
    
    # Is anything threatening our team this turn?
    var threat_present := false
    for enemy in enemies:
        if not enemy.is_alive(): continue
        if enemy.current_intent != null and enemy.current_intent.intent_type in ["attack", "attack_weakest"]:
            threat_present = true
            break
    if threat_present:
        tags.append("responding-to-threat")
    else:
        tags.append("no-immediate-threat")
    
    if bot.charge_state.is_active():
        tags.append("bot-is-charged")
    
    var alive_allies := 0
    for ally in bots:
        if ally.is_alive(): alive_allies += 1
    if alive_allies == 1:
        tags.append("last-bot-standing")
    
    return tags
```

---

## 5. Arrow Layer

### arrow_layer.gd

```gdscript
class_name ArrowLayer extends Control

# Top-level Control rendered above all cards.
# Used for enemy intent arrows (red dashed) and player assignment arrows (Prototype B only).

var active_arrows: Array[Node] = []

func draw_arrow(
    from_node: Control,
    to_node: Control,
    color: Color,
    label: String,
    dashed: bool = false
) -> void:
    var arrow := Line2D.new()
    arrow.width = 3.0
    arrow.default_color = color
    
    var from_center := from_node.global_position + from_node.size / 2
    var to_center := to_node.global_position + to_node.size / 2
    arrow.add_point(from_center)
    arrow.add_point(to_center)
    
    if dashed:
        # Simple dashed simulation — Godot's Line2D doesn't natively dash, so we
        # approximate by drawing multiple short segments.
        arrow = _make_dashed_line(from_center, to_center, color)
    
    add_child(arrow)
    active_arrows.append(arrow)
    
    if label != "":
        var lbl := Label.new()
        lbl.text = label
        lbl.position = (from_center + to_center) / 2
        lbl.add_theme_color_override("font_color", color)
        add_child(lbl)
        active_arrows.append(lbl)

func _make_dashed_line(from: Vector2, to: Vector2, color: Color) -> Node:
    var container := Node2D.new()
    var direction := (to - from).normalized()
    var total_distance := from.distance_to(to)
    var dash_length := 8.0
    var gap_length := 6.0
    var step := dash_length + gap_length
    var distance := 0.0
    
    while distance < total_distance:
        var segment_start := from + direction * distance
        var segment_end_distance := min(distance + dash_length, total_distance)
        var segment_end := from + direction * segment_end_distance
        var segment := Line2D.new()
        segment.add_point(segment_start)
        segment.add_point(segment_end)
        segment.width = 3.0
        segment.default_color = color
        container.add_child(segment)
        distance += step
    
    return container

func clear_all() -> void:
    for node in active_arrows:
        node.queue_free()
    active_arrows.clear()
```

---

## 6. Shared UI Scenes

### bot_card.tscn structure

```
BotCard (PanelContainer)
└── VBoxContainer
    ├── Header (HBoxContainer)
    │   ├── BotName (Label)
    │   └── ColorIndicator (ColorRect)
    ├── Portrait (TextureRect)
    ├── HPBar (HBoxContainer)
    │   ├── HPBarFill (ProgressBar)
    │   └── HPLabel (Label)
    ├── PreviewOverlay (Control)
    │   ├── DamagePreviewBar (ColorRect)
    │   ├── SkullIcon (TextureRect)
    │   └── SavedIcon (TextureRect)
    ├── StatsRow (HBoxContainer)
    │   ├── AttackLabel (Label)
    │   ├── DefenseLabel (Label)
    │   └── SpeedLabel (Label)
    ├── PersonalityBars (VBoxContainer)
    │   ├── Scale1Bar (PersonalityScaleBar instance)
    │   ├── Scale2Bar (PersonalityScaleBar instance)
    │   └── Scale3Bar (PersonalityScaleBar instance)
    ├── ChargeIndicator (Label)        # hidden unless charged
    ├── AssignedSkillDisplay (Label)   # used in Prototype B
    ├── ATBBarContainer (Control)      # used in Prototype A
    └── SkillSlots (HBoxContainer)     # populated dynamically
```

### bot_card.gd

```gdscript
class_name BotCard extends PanelContainer

signal bot_card_clicked(bot: BotData)
signal skill_pressed(bot: BotData, skill: SkillData)

@export var bot: BotData

@onready var bot_name_label: Label = $VBoxContainer/Header/BotName
@onready var color_indicator: ColorRect = $VBoxContainer/Header/ColorIndicator
@onready var portrait: TextureRect = $VBoxContainer/Portrait
@onready var hp_bar: ProgressBar = $VBoxContainer/HPBar/HPBarFill
@onready var hp_label: Label = $VBoxContainer/HPBar/HPLabel
@onready var preview_overlay: Control = $VBoxContainer/PreviewOverlay
@onready var damage_preview_bar: ColorRect = $VBoxContainer/PreviewOverlay/DamagePreviewBar
@onready var skull_icon: TextureRect = $VBoxContainer/PreviewOverlay/SkullIcon
@onready var saved_icon: TextureRect = $VBoxContainer/PreviewOverlay/SavedIcon
@onready var attack_label: Label = $VBoxContainer/StatsRow/AttackLabel
@onready var defense_label: Label = $VBoxContainer/StatsRow/DefenseLabel
@onready var speed_label: Label = $VBoxContainer/StatsRow/SpeedLabel
@onready var scale_bars: Array[Node] = [
    $VBoxContainer/PersonalityBars/Scale1Bar,
    $VBoxContainer/PersonalityBars/Scale2Bar,
    $VBoxContainer/PersonalityBars/Scale3Bar
]
@onready var charge_indicator: Label = $VBoxContainer/ChargeIndicator
@onready var assigned_skill_display: Label = $VBoxContainer/AssignedSkillDisplay
@onready var skill_slots: HBoxContainer = $VBoxContainer/SkillSlots

func _ready() -> void:
    refresh()
    gui_input.connect(_on_gui_input)

func refresh() -> void:
    if bot == null: return
    bot_name_label.text = bot.bot_name
    color_indicator.color = bot.color
    if bot.portrait: portrait.texture = bot.portrait
    
    hp_bar.max_value = bot.max_hp
    hp_bar.value = bot.hp
    hp_label.text = "%d/%d" % [bot.hp, bot.max_hp]
    
    attack_label.text = "ATK %d" % bot.attack
    defense_label.text = "DEF %d" % bot.defense
    speed_label.text = "SPD %d" % bot.speed
    
    _refresh_personality_bars()
    _refresh_charge_indicator()
    _refresh_assigned_skill()
    
    clear_damage_preview()

func _refresh_personality_bars() -> void:
    var scales := ["aggressive_defensive", "solitary_supportive", "reactive_methodical"]
    for i in range(scale_bars.size()):
        var bar = scale_bars[i]
        var scale_name = scales[i]
        var active = bot.personality.is_scale_active(scale_name)
        bar.setup(scale_name, bot.personality.get_scale(scale_name), active)

func _refresh_charge_indicator() -> void:
    var label := bot.charge_state.get_label()
    charge_indicator.visible = label != ""
    charge_indicator.text = label

func _refresh_assigned_skill() -> void:
    if bot.assigned_skill != null:
        assigned_skill_display.visible = true
        assigned_skill_display.text = "▶ " + bot.assigned_skill.skill_name
    else:
        assigned_skill_display.visible = false

func show_damage_preview(amount: int, will_die: bool) -> void:
    if amount <= 0:
        clear_damage_preview()
        return
    var pct = float(amount) / float(bot.max_hp)
    damage_preview_bar.visible = true
    damage_preview_bar.size.x = hp_bar.size.x * pct
    damage_preview_bar.position.x = hp_bar.position.x + hp_bar.size.x * (float(bot.hp - amount) / bot.max_hp)
    skull_icon.visible = will_die

func show_saved_preview() -> void:
    saved_icon.visible = true

func clear_damage_preview() -> void:
    damage_preview_bar.visible = false
    skull_icon.visible = false
    saved_icon.visible = false

func populate_skill_slots(available_energy: int) -> void:
    for child in skill_slots.get_children():
        child.queue_free()
    
    for command in bot.skill_slots:
        for skill in bot.skill_slots[command]:
            var btn := preload("res://bots/scenes/skill_button.tscn").instantiate()
            btn.setup(skill, available_energy)
            btn.skill_pressed.connect(func(s): emit_signal("skill_pressed", bot, s))
            skill_slots.add_child(btn)

func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        emit_signal("bot_card_clicked", bot)
```

### enemy_card.gd

```gdscript
class_name EnemyCard extends PanelContainer

signal enemy_card_clicked(enemy: EnemyData)

@export var enemy: EnemyData

@onready var enemy_name_label: Label = $VBoxContainer/EnemyName
@onready var portrait: TextureRect = $VBoxContainer/Portrait
@onready var hp_bar: ProgressBar = $VBoxContainer/HPBar/HPBarFill
@onready var hp_label: Label = $VBoxContainer/HPBar/HPLabel
@onready var damage_preview_bar: ColorRect = $VBoxContainer/PreviewOverlay/DamagePreviewBar
@onready var skull_icon: TextureRect = $VBoxContainer/PreviewOverlay/SkullIcon
@onready var intent_icon: TextureRect = $VBoxContainer/IntentDisplay/IntentIcon
@onready var intent_label: Label = $VBoxContainer/IntentDisplay/IntentLabel

func _ready() -> void:
    refresh()
    gui_input.connect(_on_gui_input)

func refresh() -> void:
    if enemy == null: return
    enemy_name_label.text = enemy.enemy_name
    if enemy.portrait: portrait.texture = enemy.portrait
    
    hp_bar.max_value = enemy.max_hp
    hp_bar.value = enemy.hp
    hp_label.text = "%d/%d" % [enemy.hp, enemy.max_hp]
    
    _refresh_intent()
    clear_damage_preview()

func _refresh_intent() -> void:
    if enemy.current_intent == null:
        intent_label.text = ""
        return
    intent_label.text = enemy.current_intent.display_label
    if enemy.current_intent.display_icon:
        intent_icon.texture = enemy.current_intent.display_icon

func update_intent_value(new_value: int) -> void:
    # Called when a debuff like Crippling Shot changes the projected damage.
    if enemy.current_intent == null: return
    intent_label.text = "%s %d" % [enemy.current_intent.intent_type.capitalize(), new_value]

func show_damage_preview(amount: int, will_die: bool) -> void:
    if amount <= 0:
        clear_damage_preview()
        return
    var pct = float(amount) / float(enemy.max_hp)
    damage_preview_bar.visible = true
    damage_preview_bar.size.x = hp_bar.size.x * pct
    skull_icon.visible = will_die

func clear_damage_preview() -> void:
    damage_preview_bar.visible = false
    skull_icon.visible = false

func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        emit_signal("enemy_card_clicked", enemy)
```

### skill_button.gd

```gdscript
class_name SkillButton extends Button

signal skill_pressed(skill: SkillData)

var skill: SkillData

@onready var skill_name_label: Label = $SkillName
@onready var energy_cost_label: Label = $EnergyCost
@onready var cost_indicator: ColorRect = $CostIndicator

func setup(skill_data: SkillData, available_energy: int) -> void:
    skill = skill_data
    skill_name_label.text = skill.skill_name
    energy_cost_label.text = "%d⚡" % skill.energy_cost
    
    var affordable := skill.energy_cost <= available_energy
    cost_indicator.color = Color.GREEN if affordable else Color.RED
    disabled = not affordable
    
    pressed.connect(func(): emit_signal("skill_pressed", skill))
```

### personality_scale_bar.gd

```gdscript
class_name PersonalityScaleBar extends HBoxContainer

@onready var left_label: Label = $LeftLabel
@onready var right_label: Label = $RightLabel
@onready var left_fill: ColorRect = $BarContainer/LeftFill
@onready var right_fill: ColorRect = $BarContainer/RightFill
@onready var bar_container: Control = $BarContainer

func setup(scale_name: String, value: float, active: bool) -> void:
    match scale_name:
        "aggressive_defensive":
            left_label.text = "Aggressive"
            right_label.text = "Defensive"
        "solitary_supportive":
            left_label.text = "Solitary"
            right_label.text = "Supportive"
        "reactive_methodical":
            left_label.text = "Reactive"
            right_label.text = "Methodical"
    
    var max_width: float = bar_container.size.x / 2.0
    var fill_pct: float = abs(value) / 5.0
    var fill_width: float = max_width * fill_pct
    
    if value < 0:
        left_fill.visible = true
        right_fill.visible = false
        left_fill.size.x = fill_width
        left_fill.position.x = max_width - fill_width
    elif value > 0:
        left_fill.visible = false
        right_fill.visible = true
        right_fill.size.x = fill_width
        right_fill.position.x = max_width
    else:
        left_fill.visible = false
        right_fill.visible = false
    
    if not active:
        modulate = Color(0.5, 0.5, 0.5, 0.5)
    else:
        modulate = Color.WHITE
```

### energy_display.gd

```gdscript
class_name EnergyDisplay extends HBoxContainer

@onready var energy_label: Label = $EnergyLabel
@onready var energy_bar: ProgressBar = $EnergyBar

var max_energy: float = 10.0

func setup(max_energy_value: float) -> void:
    max_energy = max_energy_value
    energy_bar.max_value = max_energy
    update_energy(max_energy)

func update_energy(current: float, display_decimal: bool = false) -> void:
    energy_bar.value = current
    if display_decimal:
        energy_label.text = "%.1f / %.0f" % [current, max_energy]
    else:
        energy_label.text = "%d / %d" % [int(current), int(max_energy)]
```

---

## 7. Prototype Skill Data Resources

Create these as `.tres` files in `data/skills/`. Each is a SkillData resource with the fields filled in.

### attack_standard.tres
```
skill_name = "Standard Attack"
command_type = "attack"
energy_cost = 1
multiplier = 1.0
effect_type = "damage"
target_type = "single_enemy"
tags = ["dealing-damage"]
```

### attack_power_shot.tres
```
skill_name = "Power Shot"
command_type = "attack"
energy_cost = 2
multiplier = 1.5
effect_type = "damage"
target_type = "single_enemy"
tags = ["dealing-damage", "single-target-attack"]
```

### attack_spread_shot.tres
```
skill_name = "Spread Shot"
command_type = "attack"
energy_cost = 2
multiplier = 0.75
effect_type = "damage"
target_type = "all_enemies"
tags = ["dealing-damage", "aoe-attack"]
```

### attack_frenzy.tres
```
skill_name = "Frenzy"
command_type = "attack"
energy_cost = 2
multiplier = 0.5
effect_type = "damage"
target_type = "random_enemy"
hit_count_min = 2
hit_count_max = 4
tags = ["dealing-damage", "random-multi-hit"]
```

### attack_crippling_shot.tres
```
skill_name = "Crippling Shot"
command_type = "attack"
energy_cost = 2
multiplier = 1.0
effect_type = "damage"
target_type = "single_enemy"
secondary_effect_type = "reduce_attack"
secondary_effect_value = 2.0
tags = ["dealing-damage", "single-target-attack"]
```

### defend_standard.tres
```
skill_name = "Standard Defend"
command_type = "defend"
energy_cost = 1
multiplier = 1.0
effect_type = "defend"
target_type = "self"
tags = ["absorbing-damage"]
```

### defend_counter_stance.tres
```
skill_name = "Counter Stance"
command_type = "defend"
energy_cost = 2
multiplier = 1.0
effect_type = "defend"
target_type = "self"
secondary_effect_type = "retaliate"
secondary_effect_value = 0.5
tags = ["absorbing-damage"]
```

### defend_bulwark.tres
```
skill_name = "Bulwark"
command_type = "defend"
energy_cost = 2
multiplier = 1.0
effect_type = "defend"
target_type = "self"
secondary_effect_type = "share_defense"
secondary_effect_value = 0.5
tags = ["absorbing-damage", "buffing-ally"]
```

### support_standard.tres
```
skill_name = "Standard Support"
command_type = "support"
energy_cost = 1
multiplier = 1.0
effect_type = "buff"
effect_value = 2.0
target_type = "all_allies"
tags = ["buffing-ally", "target-all-allies"]
```

### support_battle_cry.tres
```
skill_name = "Battle Cry"
command_type = "support"
energy_cost = 2
multiplier = 1.0
effect_type = "buff"
effect_value = 4.0
target_type = "single_ally"
tags = ["buffing-ally"]
```

### support_medic_protocol.tres
```
skill_name = "Medic Protocol"
command_type = "support"
energy_cost = 2
multiplier = 1.0
effect_type = "heal"
effect_value = 6.0
target_type = "single_ally"
tags = ["healing-ally", "buffing-ally"]
```

### charge_standard.tres
```
skill_name = "Standard Charge"
command_type = "charge"
energy_cost = 1
multiplier = 1.0
effect_type = "charge"
target_type = "self"
tags = ["planning-ahead", "buffing-self"]
```

### charge_overload.tres
```
skill_name = "Overload"
command_type = "charge"
energy_cost = 2
multiplier = 1.0
effect_type = "charge"
target_type = "self"
secondary_effect_type = "self_damage"
secondary_effect_value = 3.0
tags = ["planning-ahead", "buffing-self", "reckless-action"]
```

### charge_team_charge.tres
```
skill_name = "Team Charge"
command_type = "charge"
energy_cost = 2
multiplier = 1.0
effect_type = "charge"
target_type = "self"
secondary_effect_type = "buff_ally_attack"
secondary_effect_value = 2.0
tags = ["planning-ahead", "buffing-ally"]
```

---

## 8. Prototype Enemy Data Resources

Create these as `.tres` files in `data/enemies/`. Each is an EnemyData resource with an intent_loop array of IntentData resources.

### enemy_bruiser.tres
```
enemy_name = "Bruiser"
personality_archetype = "bruiser"
hp = 30
max_hp = 30
attack = 10
defense = 4
speed = 35
intent_loop = [
    {intent_type: "attack", value: 10, target_resolution: "random_bot", display_label: "Attack 10"},
    {intent_type: "attack", value: 10, target_resolution: "random_bot", display_label: "Attack 10"},
    {intent_type: "defend", value: 6, target_resolution: "self", display_label: "Defend"}
]
```

### enemy_tactician.tres
```
enemy_name = "Tactician"
personality_archetype = "tactician"
hp = 25
max_hp = 25
attack = 8
defense = 5
speed = 30
intent_loop = [
    {intent_type: "defend", value: 6, target_resolution: "self", display_label: "Defend"},
    {intent_type: "power_up", value: 4, target_resolution: "self", display_label: "Power Up +4"},
    {intent_type: "attack", value: 12, target_resolution: "random_bot", display_label: "Attack 12"},
    {intent_type: "attack", value: 12, target_resolution: "random_bot", display_label: "Attack 12"}
]
```

### enemy_berserker.tres
```
enemy_name = "Berserker"
personality_archetype = "berserker"
hp = 28
max_hp = 28
attack = 9
defense = 2
speed = 50
intent_loop = [
    {intent_type: "attack", value: 9, target_resolution: "random_bot", display_label: "Attack 9"},
    {intent_type: "attack", value: 9, target_resolution: "random_bot", display_label: "Attack 9"},
    {intent_type: "attack", value: 9, target_resolution: "random_bot", display_label: "Attack 9"},
    {intent_type: "recover", value: 8, target_resolution: "self", display_label: "Recover +8 HP"}
]
```

### enemy_supporter.tres
```
enemy_name = "Supporter"
personality_archetype = "supporter"
hp = 22
max_hp = 22
attack = 6
defense = 3
speed = 40
intent_loop = [
    {intent_type: "buff_ally", value: 3, target_resolution: "ally", display_label: "Buff Ally +3 ATK"},
    {intent_type: "defend", value: 5, target_resolution: "self", display_label: "Defend"},
    {intent_type: "attack", value: 6, target_resolution: "random_bot", display_label: "Attack 6"}
]
```

### enemy_predator.tres
```
enemy_name = "Predator"
personality_archetype = "predator"
hp = 26
max_hp = 26
attack = 11
defense = 3
speed = 55
intent_loop = [
    {intent_type: "attack_weakest", value: 11, target_resolution: "weakest_bot", display_label: "Attack Weakest 11"},
    {intent_type: "attack_weakest", value: 11, target_resolution: "weakest_bot", display_label: "Attack Weakest 11"},
    {intent_type: "defend", value: 5, target_resolution: "self", display_label: "Defend"}
]
```

---

## 9. Build Order

1. Create the six data model resource scripts (BotData, EnemyData, SkillData, IntentData, PersonalityData, ChargeState)
2. Create the DamageCalculator and TagLogger utility scripts — pure logic, easy to test in isolation
3. Build the shared UI scenes — BotCard, EnemyCard, SkillButton, PersonalityScaleBar, EnergyDisplay
4. Build the ArrowLayer
5. Create the 14 skill .tres resources
6. Create the 5 enemy .tres resources
7. Create test bot .tres resources for the prototype
8. **Stop here** — verify everything renders and instantiates correctly before touching either prototype
9. Then proceed to either `spec_prototype_a.md` or `spec_prototype_b.md` (recommended: Prototype B first)

---

## 10. Open Implementation Questions

- Should BotData track personality history (which scales have moved how much over time) for debugging? Currently no — only current values.
- Whether to use Godot's built-in `Resource` save/load for bots or a custom serialization layer for inheritance/breeding.
- How portrait assignments work for procedurally generated bots later — out of scope for prototype but worth noting.

*Strategic context: see Design Doc §1–§6. Personality processing logic: `spec_personality.md`. Prototype-specific code: `spec_prototype_a.md` and `spec_prototype_b.md`.*
