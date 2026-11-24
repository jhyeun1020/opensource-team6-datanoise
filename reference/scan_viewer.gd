@tool
extends Node3D
## Shows a Polycam scan in the editor 3D view.
## Polycam GLB files have no normals and the lighting is baked into the textures,
## so a normal import renders black. This loads the file and draws it unshaded.

@export_file("*.glb") var scan_path := "res://reference/scans/medialabs_scan_2026-11-24.glb":
	set(value):
		scan_path = value
		if is_inside_tree():
			_load_scan()

func _ready() -> void:
	_load_scan()

func _load_scan() -> void:
	for c in get_children():
		if c.name == "Scan":
			c.free()
	if not FileAccess.file_exists(scan_path):
		push_warning("Scan file not found: " + scan_path)
		return
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(scan_path), state) != OK:
		push_warning("Could not load scan: " + scan_path)
		return
	var scene := doc.generate_scene(state)
	scene.name = "Scan"
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		for i in mesh.get_surface_count():
			var src := mesh.surface_get_material(i) as BaseMaterial3D
			var mat := StandardMaterial3D.new()
			if src:
				mat.albedo_texture = src.albedo_texture
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mi.set_surface_override_material(i, mat)
	add_child(scene)
