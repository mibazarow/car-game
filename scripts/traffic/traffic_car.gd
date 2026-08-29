extends Area3D
class_name TrafficCar
## Placeholder traffic car (enemy). A purple box that scrolls toward the
## player along the endless 4-lane road. Detected via Area3D for game-over.
## Top-down view: +Y is up, world "forward" (travel) is -Z, road scrolls +Z.

# Lane center X positions (lanes 0..3, left -> right).
const LANE_X: Array[float] = [-3.0, -1.0, 1.0, 3.0]

# Where a freshly spawned car enters (top of screen, negative Z).
const SPAWN_Z: float = -17.0
# Past this Z the car has passed the player and is recycled.
const RECYCLE_Z: float = 18.0
# Awarded once per car when it passes the player.
const PASS_POINTS := 1

## This car's own forward driving speed (units/s), its own `w`.
var forward_speed: float = 0.0
## World-space Z velocity: GameState.speed - forward_speed (always > 0 here).
var speed_z: float = 0.0
## Which lane this car occupies.
var lane: int = 0
## Whether the car is currently in use (spawned / active).
var active: bool = false

## Activate this car on a given lane with a given forward speed.
func activate(new_lane: int, new_forward_speed: float) -> void:
	lane = clamp(new_lane, 0, 3)
	forward_speed = new_forward_speed
	speed_z = GameState.speed - forward_speed
	position.x = LANE_X[lane]
	position.z = SPAWN_Z
	active = true
	set_process(true)
	show()

## Return this car to the pool: stop processing and hide it.
func deactivate() -> void:
	active = false
	set_process(false)
	hide()

signal recycled(car: TrafficCar)

## Whether this car is currently active.
func is_active() -> bool:
	return active

func _ready() -> void:
	add_to_group("traffic")

func _physics_process(delta: float) -> void:
	speed_z = GameState.speed - forward_speed
	position.z += speed_z * delta
	if position.z > RECYCLE_Z:
		if GameState.state == "playing":
			GameState.add_score(PASS_POINTS)
		deactivate()
		recycled.emit(self)
