extends Node3D
## Listens for the nitro-spawn signal and reuses a single NitroPickup instance
## to drop a pickup onto a random lane whenever one is due.

@onready var _scene := preload("res://scenes/NitroPickup.tscn")
var _pickup: NitroPickup = null

func _ready() -> void:
	GameState.nitro_should_spawn.connect(_spawn)

## Spawn (or reuse) a nitro pickup on a random lane.
func _spawn() -> void:
	if _pickup != null and _pickup.is_active():
		return
	if _pickup == null:
		_pickup = _scene.instantiate()
		add_child(_pickup)
	_pickup.activate(randi_range(0, 3))
