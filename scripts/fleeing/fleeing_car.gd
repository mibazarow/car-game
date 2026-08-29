extends Node3D
## Autonomous fleeing target car (visual placeholder).
## Top-down view: +Y is up, world "forward" (travel direction) is -Z.
## The car stays pinned near the top of the screen and wanders between lanes.

# Lane center X positions (lanes 0..3, left -> right).
const LANE_X: Array[float] = [-3.0, -1.0, 1.0, 3.0]
# Fixed position near the top of the screen (negative Z).
const Z_POS: float = -10.0

# Frame-rate-independent lateral smoothing.
const MOVE_SMOOTH: float = 6.0

# How long to wait before re-rolling a lane change.
const CHANGE_INTERVAL_MIN: float = 1.5
const CHANGE_INTERVAL_MAX: float = 3.5

var current_lane: int = 1
var _change_timer: float = 0.0
var _change_interval: float = 2.5

func _ready() -> void:
	position.x = LANE_X[current_lane]
	position.z = Z_POS

func _process(delta: float) -> void:
	# Keep the car pinned at the top of the screen; the world scrolls instead.
	position.z = Z_POS

	# Countdown to the next autonomous lane change.
	_change_timer -= delta
	if _change_timer <= 0.0:
		# Pick a new lane different from the current one.
		var new_lane: int = randi_range(0, 3)
		while new_lane == current_lane:
			new_lane = randi_range(0, 3)
		current_lane = new_lane
		_change_interval = randf_range(CHANGE_INTERVAL_MIN, CHANGE_INTERVAL_MAX)
		_change_timer = _change_interval

	# Smooth approach to the target lane (frame-rate independent).
	var target_x: float = LANE_X[current_lane]
	position.x = lerp(position.x, target_x, 1.0 - exp(-MOVE_SMOOTH * delta))
