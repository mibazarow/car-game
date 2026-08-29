extends Area3D
class_name FleeingCar
## Autonomous fleeing target car that descends the road and can be caught.
## Top-down view: +Y is up, world "forward" (travel direction) is -Z.
## The car drives forward (own FORWARD_SPEED) while the road scrolls faster,
## so it descends toward the player. If it passes the player row it respawns
## at the top. Detected via Area3D; overlapping it awards score.

# Lane center X positions (lanes 0..3, left -> right).
const LANE_X: Array[float] = [-3.0, -1.0, 1.0, 3.0]
# Where the car spawns (top of the screen, negative Z).
const Z_SPAWN: float = -13.0
# Past this Z the car has escaped the player and must respawn at the top.
const Z_PASS: float = 6.0
# The car's own forward driving speed. Must exceed traffic speeds (3..7) so
# the car descends slower than traffic and stays ahead of it.
const FORWARD_SPEED: float = 9.0
# Frame-rate-independent lateral smoothing.
const MOVE_SMOOTH: float = 6.0
# Lane-change interval bounds (seconds).
const CHANGE_MIN: float = 1.2
const CHANGE_MAX: float = 2.5

var lane: int = 1
var _change_timer: float = 0.0
var _change_interval: float = 2.0

func _ready() -> void:
	add_to_group("fleeing")
	position.x = LANE_X[lane]
	position.z = Z_SPAWN

## Relocate the car to the top in a random lane (any lane).
func respawn() -> void:
	lane = randi_range(0, 3)
	position.x = LANE_X[lane]
	position.z = Z_SPAWN
	_change_timer = randf_range(CHANGE_MIN, CHANGE_MAX)

func _physics_process(delta: float) -> void:
	# Descend toward the player: world scrolls at GameState.speed, the car
	# drives forward at FORWARD_SPEED, so net world-Z motion is (speed - w).
	var speed_z: float = GameState.speed - FORWARD_SPEED
	position.z += speed_z * delta

	# Countdown to the next autonomous lane change.
	_change_timer -= delta
	if _change_timer <= 0.0:
		# Pick a new lane different from the current one.
		var new_lane: int = randi_range(0, 3)
		while new_lane == lane:
			new_lane = randi_range(0, 3)
		lane = new_lane
		_change_interval = randf_range(CHANGE_MIN, CHANGE_MAX)
		_change_timer = _change_interval

	# Smooth approach to the target lane (frame-rate independent).
	var target_x: float = LANE_X[lane]
	position.x = lerp(position.x, target_x, 1.0 - exp(-MOVE_SMOOTH * delta))

	# Escaped past the player: respawn at the top.
	if position.z > Z_PASS:
		respawn()
