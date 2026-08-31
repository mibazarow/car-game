extends PickupSpawner

func _ready() -> void:
	setup(preload("res://scenes/NitroPickup.tscn"), "nitro", GameState.nitro_should_spawn)
