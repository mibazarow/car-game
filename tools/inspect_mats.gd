extends SceneTree

func _initialize() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	var gs = root.get_node_or_null("GameState")
	if gs != null: gs.state = "playing"
	await process_frame
	await process_frame
	_dump(main.get_node_or_null("PlayerCar"), 0)
	_dump(main.get_node_or_null("FleeingCar"), 0)
	main.free()
	quit()

func _dump(node: Node, depth: int) -> void:
	if node == null:
		print("  <null>")
		return
	var prefix = ""
	for i in depth: prefix += "  "
	var extra = ""
	if node is MeshInstance3D: extra = " <MESH>"
	if node is Camera3D: extra += " <CAMERA>"
	print(prefix + node.name + " [" + node.get_class() + "]" + extra)
	for c in node.get_children():
		_dump(c, depth + 1)
