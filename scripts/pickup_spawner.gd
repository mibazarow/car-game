class_name PickupSpawner
extends Node3D
## Reuses a single pickup instance; drops it onto a random lane when its
## spawn signal fires.

var _scene: PackedScene
var _group: String
var _pickup: Pickup = null

## Wire the spawner to a scene, a group name, and a spawn signal.
func setup(scene: PackedScene, group: String, spawn_signal: Signal) -> void:
	_scene = scene
	_group = group
	spawn_signal.connect(_spawn)

## Spawn (or reuse) one pickup on a random lane. Globally idempotent: no more
## than ONE active pickup of this kind is ever in the tree.
func _spawn() -> void:
	for node in get_tree().get_nodes_in_group(_group):
		var p := node as Pickup
		if p != null and p.is_active():
			return
	if _pickup != null and _pickup.is_active():
		return
	if _pickup == null:
		_pickup = _scene.instantiate()
		add_child(_pickup)
	_pickup.activate(randi_range(0, 3))
