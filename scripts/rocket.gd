extends Area3D
class_name Rocket
## A straight-flying projectile. Launched from the player toward the fleeing
## enemy: destroying the enemy is a win. Clipping civilian traffic just wastes
## the rocket (no crash); only driving into traffic ends the run.
## Top-down view: +Y is up, flight toward -Z (forward).

## Flight direction (normalized at launch).
var dir: Vector3 = Vector3(0, 0, -1)
## How fast the rocket travels (world units / second).
const SPEED: float = 28.0
## Seconds before the rocket disappears on its own.
const LIFETIME: float = 3.0

## How long the rocket has been alive.
var _life: float = LIFETIME

# Pseudo-3D wobble: a small lateral left/right oscillation so the rocket reads
# as a wobbling missile. Amplitude is small (stays within the lane).
const WOBBLE_AMP: float = 8.0
const WOBBLE_FREQ: float = 20.0
## Perpendicular (lateral) direction in the XZ plane, set at launch.
var _perp: Vector3 = Vector3(1, 0, 0)
## Age in seconds, drives the wobble phase.
var _age: float = 0.0

func _ready() -> void:
	hide()
	set_process(false)
	area_entered.connect(_on_area_entered)

## Launch the rocket: set its start position and direction, then activate it.
func launch(from: Vector3, direction: Vector3) -> void:
	global_position = from
	dir = direction.normalized()
	_perp = Vector3(-dir.z, 0.0, dir.x).normalized()
	_age = 0.0
	_life = LIFETIME
	show()
	set_process(true)

## Stop processing and hide the rocket (return it to the pool).
func deactivate() -> void:
	hide()
	set_process(false)

func _process(delta: float) -> void:
	_age += delta
	position += dir * SPEED * delta
	# Small lateral wobble (pseudo-3D rocket shake), amplitude ~ WOBBLE_AMP/WOBBLE_FREQ.
	position += _perp * sin(_age * WOBBLE_FREQ) * WOBBLE_AMP * delta
	_life -= delta
	if _life <= 0.0 or position.z < -25.0 or position.z > 25.0 or absf(position.x) > 20.0:
		deactivate()

## Show the win explosion at a world position.
func _spawn_explosion(at: Vector3) -> void:
	var boom: Node3D = (load("res://scenes/Explosion.tscn") as PackedScene).instantiate()
	get_tree().current_scene.add_child(boom)
	boom.global_position = at

func _on_area_entered(area: Area3D) -> void:
	if area is FleeingCar:
		_spawn_explosion(area.global_position)
		GameState.win()
		deactivate()
	elif area is TrafficCar:
		# A rocket that clips civilian traffic is a wasted shot, not a crash.
		# Only driving into traffic is a game over.
		deactivate()
