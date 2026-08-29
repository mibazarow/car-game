extends Area3D
class_name NitroPickup
## A flat yellow circle that sits STATICALLY on a lane at the player's row.
## The player steers into it to activate nitro (~2s), during which the fleeing
## target car approaches. Top-down view: +Y is up, road scrolls +Z; this pickup
## does NOT scroll (it stays in one place).
## Detected via Area3D (collision_layer = 8).

# Lane center X positions (lanes 0..3, left -> right).
const LANE_X: Array[float] = [-3.0, -1.0, 1.0, 3.0]
# The pickup is placed at the player's row (PLAYER_Z) so it is reachable by
# steering sideways; it never moves down the road.
const PICKUP_Z: float = 4.0
# Seconds before the pickup disappears if not collected.
const LIFETIME: float = 10.0

## Whether this pickup is currently active (placed / visible).
var active: bool = false
var _life: float = 0.0

## Place the pickup on a lane at the player's row and arm its lifetime.
func activate(lane: int) -> void:
	position.x = LANE_X[clampi(lane, 0, 3)]
	position.z = PICKUP_Z
	_life = LIFETIME
	active = true
	set_process(true)
	show()

## Return the pickup to the pool: stop processing and hide it.
func deactivate() -> void:
	active = false
	set_process(false)
	hide()

## Whether this pickup is currently active.
func is_active() -> bool:
	return active

## Lifetime countdown: the static pickup vanishes if it is not collected.
func _process(delta: float) -> void:
	if not active:
		return
	if GameState.state != "playing":
		return
	_life -= delta
	if _life <= 0.0:
		deactivate()
