extends SceneTree

func _initialize() -> void:
	var root = get_root()
	# Load the imported police scene directly and inspect its mesh/material/texture
	var police = load("res://.godot/imported/1_police_hero_car_.glb-58f54ee87ae2217be163b39e3cd7e028.scn")
	print("police scene=", str(police))
	var inst = police.instantiate()
	root.add_child(inst)
	var mi = inst.get_node("geometry_0")
	print("geometry_0=", str(mi), " class=", mi.get_class())
	if mi is MeshInstance3D:
		var m = mi.get_mesh()
		print("mesh=", str(m), " class=", m.get_class(), " surfaces=", m.get_surface_count())
		if m.get_surface_count() > 0:
			var mat = mi.get_active_material(0)
			print("material=", str(mat), " class=", mat.get_class())
			if mat:
				print("albedo_color=", mat.albedo_color, " transparency=", mat.transparency, " cull=", mat.cull_mode)
				var tex = mat.albedo_texture
				print("albedo_texture=", str(tex), " class=", tex.get_class() if tex else "null")
				if tex is Texture2D:
					print("texture_size=", tex.get_size())
				# try to get the image
	# also load the texture resource directly
	var tex_res = load("res://.godot/imported/1_police_hero_car__Image_0.png-84d48549aa1a69b7ddcbb2cb3d989dde.ctex")
	print("loaded tex=", str(tex_res), " class=", tex_res.get_class() if tex_res else "null")
	if tex_res is Texture2D:
		print("tex_size=", tex_res.get_size())
	quit()
