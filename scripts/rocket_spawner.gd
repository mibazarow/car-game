extends PickupSpawner

func _ready() -> void:
	setup(preload("res://scenes/RocketPickup.tscn"), "rocket", GameState.rocket_should_spawn)
