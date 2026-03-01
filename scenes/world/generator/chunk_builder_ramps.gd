extends RefCounted
## Builds fun ramps on boulevards using shared material.

var _grid: RefCounted
var _ramp_mat: StandardMaterial3D


func init(grid: RefCounted, ramp_mat: StandardMaterial3D) -> void:
	_grid = grid
	_ramp_mat = ramp_mat


func build(chunk: Node3D, ox: float, oz: float) -> void:
	var boulevard_x: float = _grid.get_road_center_local(_grid.BOULEVARD_INDEX) + ox
	var ramp_data := [
		[Vector3(boulevard_x, 0.4, -80.0 + oz), Vector3(-15.0, 0.0, 0.0)],
		[Vector3(boulevard_x, 0.4, 80.0 + oz), Vector3(15.0, 0.0, 0.0)],
		[Vector3(-60.0 + ox, 0.4, _grid.get_road_center_local(7) + oz), Vector3(0.0, 0.0, 15.0)],
		[Vector3(60.0 + ox, 0.4, _grid.get_road_center_local(3) + oz), Vector3(0.0, 0.0, -15.0)],
	]

	for r_idx in range(ramp_data.size()):
		var rpos: Vector3 = ramp_data[r_idx][0]
		var rrot: Vector3 = ramp_data[r_idx][1]
		var body := StaticBody3D.new()
		body.name = "Ramp_%d" % r_idx
		body.position = rpos
		body.rotation_degrees = rrot
		body.collision_layer = 1
		body.collision_mask = 0
		body.add_to_group("Road")

		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(4.0, 0.3, 6.0)
		col.shape = shape
		body.add_child(col)

		var mesh_inst := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(4.0, 0.3, 6.0)
		box_mesh.material = _ramp_mat
		mesh_inst.mesh = box_mesh
		body.add_child(mesh_inst)

		chunk.add_child(body)
