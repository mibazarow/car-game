extends SceneTree

func _initialize() -> void:
	var root = get_root()
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	var player = main.get_node("PlayerCar")
	print("=== PLAYER CAR RUNTIME STATE ===")
	print("player visible=", player.is_visible(), " pos=", player.global_position)
	var body = player.get_node("Body")
	print("body visible=", body.is_visible(), " pos=", body.position, " rot.z=", body.rotation.z)
	var cm = body.get_node("CarModel")
	print("CarModel visible=", cm.is_visible(), " transform=", cm.transform)
	for child in cm.get_children():
		print("  child:", child.name, child.get_class(), " visible=", child.is_visible())
		if child is MeshInstance3D:
			var m = child.get_mesh()
			print("   mesh=", str(m), " mesh_class=", m.get_class() if m else "null")
			if m and m.get_surface_count() > 0:
				var mat = m.get_surface_material(0)
				print("   surface_count=", m.get_surface_count())
				print("   material=", str(mat), " class=", mat.get_class() if mat else "null")
				if mat:
					print("   albedo_color=", mat.albedo_color)
					print("   transparency=", mat.transparency)
					print("   shading_mode=", mat.shading_mode)
					print("   cull_mode=", mat.cull_mode)
					print("   roughness=", mat.roughness)
					print("   albedo_texture=", str(mat.albedo_texture))
					print("   vertex_color_use_as_albedo=", mat.vertex_color_use_as_albedo)
	var cam = main.get_node("Camera")
	print("camera pos=", cam.position, " near=", cam.near, " far=", cam.far, " current=", cam.current)
	print("=== END ===")
	quit()
