extends Area3D
class_name Rocket
## A straight-flying projectile. Launched from the player toward the fleeing
## enemy: destroying the enemy is a win, hitting civilian traffic is a crash.
## Top-down view: +Y is up, flight toward -Z (forward).

## Flight direction (normalized at launch).
var dir: Vector3 = Vector3(0, 0, -1)
## How fast the rocket travels (world units / second).
const SPEED: float = 45.0
## Seconds before the rocket disappears on its own.
const LIFETIME: float = 3.0

## How long the rocket has been alive.
var _life: float = LIFETIME

func _ready() -> void:
	hide()
	set_process(false)
	area_entered.connect(_on_area_entered)

## Launch the rocket: set its start position and direction, then activate it.
func launch(from: Vector3, direction: Vector3) -> void:
	global_position = from
	dir = direction.normalized()
	_life = LIFETIME
	show()
	set_process(true)

## Stop processing and hide the rocket (return it to the pool).
func deactivate() -> void:
	hide()
	set_process(false)

func _process(delta: float) -> void:
	position += dir * SPEED * delta
	_life -= delta
	if _life <= 0.0 or position.z < -25.0 or position.z > 25.0 or absf(position.x) > 20.0:
		deactivate()

func _on_area_entered(area: Area3D) -> void:
	if area is TrafficCar:
		GameState.game_over()
		deactivate()
	elif area is FleeingCar:
		GameState.victory()
		deactivate()
