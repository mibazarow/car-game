extends Node3D
## Listens for the rocket-spawn signal and reuses a single RocketPickup instance
## to drop a pickup onto a random lane whenever one is due.

@onready var _scene := preload("res://scenes/RocketPickup.tscn")
var _pickup: RocketPickup = null

func _ready() -> void:
	GameState.rocket_should_spawn.connect(_spawn)

## Spawn (or reuse) a rocket pickup on a random lane. Globally idempotent:
## no matter how many times this fires (or how many stale spawners remain after
## scene reloads), there is never more than ONE active rocket pickup in the tree.
func _spawn() -> void:
	for node in get_tree().get_nodes_in_group("rocket"):
		var p := node as RocketPickup
		if p != null and p.is_active():
			return
	if _pickup != null and _pickup.is_active():
		return
	if _pickup == null:
		_pickup = _scene.instantiate()
		add_child(_pickup)
	_pickup.activate(randi_range(0, 3))
