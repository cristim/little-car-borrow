extends Node3D
## Floating weapon pickup. Rotates slowly and unlocks a weapon on player
## contact.

var weapon_idx := 0
var _spin_time := 0.0

@onready var trigger: Area3D = $Trigger
@onready var mesh_pivot: Node3D = $MeshPivot


func _ready() -> void:
	trigger.body_entered.connect(_on_body_entered)
	_build_mesh()


func _process(delta: float) -> void:
	_spin_time += delta
	mesh_pivot.rotation.y = _spin_time * 1.5
	mesh_pivot.position.y = 1.0 + sin(_spin_time * 2.0) * 0.1


func _build_mesh() -> void:
	var WeaponScript: GDScript = preload("res://scenes/player/player_weapon.gd")
	var BuilderScript: GDScript = preload("res://src/weapon_mesh_builder.gd")
	if weapon_idx < 0 or weapon_idx >= WeaponScript.WEAPONS.size():
		return
	var w: Dictionary = WeaponScript.WEAPONS[weapon_idx]
	var weapon_name: String = w.get("name", "Pistol")

	var builder: RefCounted = BuilderScript.new()
	var gun: Node3D = builder.build(weapon_name, 3.0)

	# Add emission glow to all mesh materials (safe — fresh instances)
	for child in gun.get_children():
		var mi: MeshInstance3D = child as MeshInstance3D
		if mi and mi.mesh and mi.mesh.material:
			var m: StandardMaterial3D = mi.mesh.material
			m.emission_enabled = true
			m.emission = Color(0.4, 0.6, 1.0)
			m.emission_energy_multiplier = 0.5

	mesh_pivot.add_child(gun)


func _on_body_entered(body: Node3D) -> void:
	var is_player := body.is_in_group("player")
	var is_player_vehicle: bool = (body.collision_layer & 8) != 0
	if is_player or is_player_vehicle:
		var player: Node = body
		if is_player_vehicle:
			var players := get_tree().get_nodes_in_group("player")
			if players.is_empty():
				return
			player = players[0]
		var pw := player.get_node_or_null("PlayerWeapon")
		if pw and pw.has_method("unlock_weapon"):
			pw.unlock_weapon(weapon_idx)
		queue_free()
