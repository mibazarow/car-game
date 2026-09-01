extends CPUParticles3D
## One-shot explosion burst shown when the rocket destroys the fleeing enemy
## (win). Self-configures on ready and self-frees after it finishes emitting.

func _ready() -> void:
	one_shot = true
	explosiveness = 1.0
	amount = 60
	lifetime = 1.0
	direction = Vector3(0, 0, -1)
	spread = 180.0
	initial_velocity_min = 6.0
	initial_velocity_max = 14.0
	gravity = Vector3(0, 3, 0)
	scale_amount_min = 0.3
	scale_amount_max = 1.1

	var mat := ParticleProcessMaterial.new()
	mat.direction = direction
	mat.spread = spread
	mat.initial_velocity_min = initial_velocity_min
	mat.initial_velocity_max = initial_velocity_max
	mat.gravity = gravity
	mat.scale_amount_min = scale_amount_min
	mat.scale_amount_max = scale_amount_max
	particle_process_material = mat

	# Visible particle: a small sphere (colored by the ramp, reads as a spark).
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	mesh = sphere

	# Color over life: bright yellow -> orange -> red -> transparent.
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	ramp.colors = PackedColorArray([
		Color(1.0, 0.9, 0.3, 1.0),
		Color(1.0, 0.45, 0.1, 1.0),
		Color(0.65, 0.08, 0.05, 0.7),
		Color(0.2, 0.0, 0.0, 0.0),
	])
	color_ramp = ramp

	emitting = true
	finished.connect(queue_free)
