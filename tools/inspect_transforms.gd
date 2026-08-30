extends SceneTree

func _initialize() -> void:
	var root = get_root()
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await main.ready
	var player = main.get_node("PlayerCar")
	var fleeing = main.get_node("FleeingCar")
	print("=== PLAYER CarModel transform ===")
	print(player.get_node("Body").get_node("CarModel").transform)
	print("=== FLEEING CarModel transform ===")
	print(fleeing.get_node("CarModel").transform)
	print("=== PLAYER Body transform ===")
	print(player.get_node("Body").transform)
	print("=== FLEEING (Area3D) transform ===")
	print(fleeing.transform)
	print("=== END ===")
	quit()
