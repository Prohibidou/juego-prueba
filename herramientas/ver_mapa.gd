extends Node3D
## Renderiza el campo desde arriba para poder situar tees y banderas.
##   godot --path . res://herramientas/VerMapa.tscn
## Deja user://mapa.png y un plano de coordenadas en user://mapa.log

const CURSO := "res://resources-3d/PGJ_MAPA_MUELLE_v1.glb"
const ESCALA := 1.0     # este ya viene en metros reales, no en escala Sketchfab

var _log: FileAccess


func _ready() -> void:
	_log = FileAccess.open("user://mapa.log", FileAccess.WRITE)
	DisplayServer.window_set_size(Vector2i(1100, 1100))

	var curso: Node3D = load(CURSO).instantiate()
	add_child(curso)
	curso.scale = Vector3.ONE * ESCALA
	curso.position = Vector3.ZERO
	await get_tree().process_frame

	var caja := _aabb(curso)
	_traza("AABB en mundo: pos %s  tam %s" % [str(caja.position.round()), str(caja.size.round())])
	_traza("centro %s" % str(caja.get_center().round()))

	# se recoloca para que la esquina quede en el origen: coordenadas comodas
	curso.position -= caja.position
	await get_tree().process_frame
	caja = _aabb(curso)
	_traza("recolocado -> pos %s  tam %s" % [str(caja.position.round()), str(caja.size.round())])

	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-70, -30, 0)
	luz.light_energy = 1.3
	add_child(luz)
	var ent := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.12, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.7)
	env.ambient_light_energy = 1.0
	ent.environment = env
	add_child(ent)

	var lado: float = maxf(caja.size.x, caja.size.z)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = lado
	cam.far = 4000.0
	cam.position = Vector3(caja.get_center().x, caja.position.y + caja.size.y + 500.0,
		caja.get_center().z)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	add_child(cam)
	cam.current = true
	_traza("camara ortogonal de %.0f m de lado, centrada en (%.0f, %.0f)"
		% [lado, caja.get_center().x, caja.get_center().z])
	_traza("la imagen de 1100 px cubre %.0f m: 1 px = %.2f m" % [lado, lado / 1100.0])
	_traza("esquina inferior izquierda de la imagen = (x=%.0f, z=%.0f)"
		% [caja.get_center().x - lado / 2.0, caja.get_center().z + lado / 2.0])

	for i in 8:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://mapa.png")
	_traza("guardado user://mapa.png (%dx%d)" % [img.get_width(), img.get_height()])
	get_tree().quit()


func _traza(s: String) -> void:
	print(s)
	_log.store_line(s)
	_log.flush()


func _aabb(n: Node) -> AABB:
	var caja := AABB()
	var primero := true
	for m: MeshInstance3D in _mallas(n):
		var c: AABB = m.global_transform * m.get_aabb()
		if primero:
			caja = c
			primero = false
		else:
			caja = caja.merge(c)
	return caja


func _mallas(n: Node) -> Array[MeshInstance3D]:
	var r: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		r.append(n)
	for h in n.get_children():
		r.append_array(_mallas(h))
	return r
