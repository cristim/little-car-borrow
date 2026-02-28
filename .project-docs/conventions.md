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
