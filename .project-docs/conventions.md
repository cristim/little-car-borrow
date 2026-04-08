## CRITICAL: No `class_name` in This Project

Godot 4.5 has broken `class_name` resolution that causes cascading parse errors across the entire project. This rule applies to ALL scripts without exception.

**Never use**:
```gdscript
class_name MyClass
```

**Instead use**:
```gdscript
# For inheritance:
extends "res://path/to/parent_script.gd"

# For type checks and preloading:
const MyClass = preload("res://path/to/script.gd")
var instance: Node  # untyped, or use the preloaded const
if instance is MyClass: ...
```

This affects GEVP (Vehicle, Wheel), state machine (State, StateMachine), and all custom classes.

---

# Conventions

## GDScript Style
- Use `gdformat` and `gdlint` (via gdtoolkit) before every commit
- snake_case for functions/variables, PascalCase for classes/nodes
- Type hints on function signatures and exported vars
- Signals use past tense: `player_died`, `vehicle_entered`

## Scene Naming
- Scenes: `snake_case.tscn` (e.g., `base_vehicle.tscn`)
- Scripts: `snake_case.gd`, same name as scene when attached

## State Machine Pattern
- States are child Nodes of a StateMachine node
- State names match the node name (lowercased for lookup)
- Transitions go through `state_machine.transition_to("target")`

## Signals
- Use EventBus for cross-system signals
- Use direct signals for parent-child communication within a scene

## Type Inference Gotchas

GDScript type inference in Godot 4.5 does not always infer concrete types. Use explicit type annotations in these cases:

- `var x := dict.get("key", default)` fails when return is Variant — use `var x: Type = dict.get("key", default)` instead
- `var x := array.pop_back()` on typed arrays returns Variant — use explicit type `var x: Type = array.pop_back()`
- `var x := lerp(a, b, t)` returns Variant — use `lerpf()` for float lerp
- `var x := body.collision_layer & mask` returns Variant — use `var x: bool = ...`
- Methods called on `RefCounted` (like road_grid) return Variant — always use explicit type annotations

## RNG Rule

- `RandomNumberGenerator.new()` starts with seed 0 — NOT auto-randomized
- Always call `_rng.randomize()` on every new `RandomNumberGenerator` instance
- Only global scope `randf()` / `randi()` are auto-seeded in Godot 4
- Never remove `_rng.randomize()` calls — they are NOT deprecated for instances

## gdlint Order Rule

- `const` declarations must appear BEFORE `var` in global scope (class body)
- gdlint enforces this — violations cause lint failures in pre-commit hooks

## Group Names Reference

Canonical group strings used in this project:

| Group | Used By |
|-------|---------|
| `"player"` | Player CharacterBody3D |
| `"npc_vehicle"` | NPC traffic cars |
| `"police_vehicle"` | Police cars |
| `"vehicle_interaction"` | Vehicle InteractionZone Areas |
| `"streetlight"` | Streetlight nodes (day/night toggling) |
| `"mission_marker"` | MissionMarker nodes |
| `"helicopter"` | Helicopter CharacterBody3D |
| `"Road"` | Road/sidewalk surfaces (for GEVP tire friction) |
