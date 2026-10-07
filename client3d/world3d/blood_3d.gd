## A stab: red drops burst out at chest height and fall (one-shot GPU
## particles for each BloodSplash in game.world; the stain left on the floor
## is a server puddle, see puddle_3d.gd).
extends Node3D

const BLOOD_SCRIPT := "res://game/blood_splash.gd"

var wv: Node3D
var _seen := {}   # BloodSplash instance id -> true
var _mesh := SphereMesh.new()
var _process_mat := ParticleProcessMaterial.new()


func setup(p_wv: Node3D) -> void:
	wv = p_wv
	name = "Blood"
	_mesh.radius = 0.03
	_mesh.height = 0.06
	_mesh.radial_segments = 6
	_mesh.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#9b1116")
	m.roughness = 0.15
	_mesh.material = m
	_process_mat.direction = Vector3(0, 1, 0)
	_process_mat.spread = 70.0
	_process_mat.initial_velocity_min = 1.5
	_process_mat.initial_velocity_max = 3.5
	_process_mat.gravity = Vector3(0, -9.8, 0)
	_process_mat.scale_min = 0.5
	_process_mat.scale_max = 1.3
	_process_mat.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT


func update() -> void:
	var world: Node = wv.game.get("world")
	if world == null:
		return
	var alive := {}
	for n in world.get_children():
		var s: Script = n.get_script()
		if s == null or s.resource_path != BLOOD_SCRIPT:
			continue
		var id: int = n.get_instance_id()
		alive[id] = true
		if not _seen.has(id):
			_seen[id] = true
			burst(wv.px_to_world(n.position) + Vector3(0, 1.2, 0))
	for id in _seen.keys():
		if not alive.has(id):
			_seen.erase(id)


func burst(at: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 28
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.95
	p.process_material = _process_mat
	p.draw_pass_1 = _mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = at
	# the floor stops the drops
	var floor_box := GPUParticlesCollisionBox3D.new()
	floor_box.size = Vector3(6, 0.2, 6)
	floor_box.position = Vector3(0, -1.3, 0)
	p.add_child(floor_box)
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
