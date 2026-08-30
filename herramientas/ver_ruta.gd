extends SceneTree
## Foto del mapa desde arriba con una cuadricula de coordenadas encima y la
## ruta de la camioneta dibujada, para poder trazar el camino sin el editor.
##
##   godot --path . --script res://herramientas/ver_ruta.gd --resolution 1400x1400 \
##     -- res://escenas/mapas/Cerro.tscn 380 700 1440 1800
##
## Los cuatro numeros son la zona a mirar: x0 x1 z0 z1 en coordenadas de mundo.
## Sale user://ruta.png. Las lineas van cada 25 m y los numeros cada 50.
##
## Para que sirve: leer del dibujo por donde pasa la calzada de verdad y
## dictar los puntos, en vez de adivinarlos de un mapa de pendientes.

const PASO := 25.0
const ALTO := 400.0        # por encima de lo mas alto del mapa


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a := OS.get_cmdline_user_args()
	var x0 := float(a[1]); var x1 := float(a[2])
	var z0 := float(a[3]); var z1 := float(a[4])

	var mapa: Node3D = (load(a[0]) as PackedScene).instantiate()
	get_root().add_child(mapa)
	await process_frame

	_luz()
	_cuadricula(x0, x1, z0, z1)
	_ruta(mapa)
	_camara(x0, x1, z0, z1)

	await create_timer(2.0).timeout
	await process_frame
	get_root().get_texture().get_image().save_png("user://ruta.png")
	print("x de %d a %d, z de %d a %d | cuadricula cada %d m"
		% [x0, x1, z0, z1, PASO])
	print("ruta: ", ProjectSettings.globalize_path("user://ruta.png"))
	quit()


func _luz() -> void:
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-70, 30, 0)
	get_root().add_child(l)
	var w := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.06, 0.06, 0.09)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.85, 0.95)
	e.ambient_light_energy = 0.7
	w.environment = e
	get_root().add_child(w)


## Camara cenital ortogonal: en ortogonal un metro son siempre los mismos
## pixeles, asi que la cuadricula se lee como un plano y no como una foto.
func _camara(x0: float, x1: float, z0: float, z1: float) -> void:
	var c := Camera3D.new()
	c.projection = Camera3D.PROJECTION_ORTHOGONAL
	c.size = maxf(x1 - x0, z1 - z0)
	c.far = 4000.0
	c.position = Vector3((x0 + x1) * 0.5, ALTO + 500.0, (z0 + z1) * 0.5)
	c.rotation_degrees = Vector3(-90, 0, 0)
	get_root().add_child(c)
	c.make_current()


func _cuadricula(x0: float, x1: float, z0: float, z1: float) -> void:
	var m := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = _mat(Color(0.2, 0.9, 1.0, 0.55))
	get_root().add_child(mi)
	m.surface_begin(Mesh.PRIMITIVE_LINES)
	var x := ceilf(x0 / PASO) * PASO
	while x <= x1:
		m.surface_add_vertex(Vector3(x, ALTO, z0))
		m.surface_add_vertex(Vector3(x, ALTO, z1))
		if fmod(x, PASO * 2.0) == 0.0:
			_texto("x %d" % roundi(x), Vector3(x, ALTO, z0 + 12.0), Color(0.3, 1, 1))
		x += PASO
	var z := ceilf(z0 / PASO) * PASO
	while z <= z1:
		m.surface_add_vertex(Vector3(x0, ALTO, z))
		m.surface_add_vertex(Vector3(x1, ALTO, z))
		if fmod(z, PASO * 2.0) == 0.0:
			_texto("z %d" % roundi(z), Vector3(x0 + 22.0, ALTO, z), Color(0.3, 1, 1))
		z += PASO
	m.surface_end()


## La ruta actual, con sus puntos numerados: asi se ve de un vistazo cuanto se
## aparta del camino de verdad y que punto hay que mover.
func _ruta(mapa: Node3D) -> void:
	var camino := mapa.get_node_or_null("Ruta") as Path3D
	if camino == null or camino.curve == null:
		return
	var m := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = _mat(Color(1.0, 0.35, 0.1))
	get_root().add_child(mi)
	m.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in camino.curve.point_count:
		var p := camino.curve.get_point_position(i)
		m.surface_add_vertex(Vector3(p.x, ALTO, p.z))
		_texto("%d (%d,%d)" % [i, roundi(p.x), roundi(p.z)],
			Vector3(p.x + 6.0, ALTO, p.z), Color(1, 0.6, 0.2))
	m.surface_end()


func _texto(t: String, donde: Vector3, c: Color) -> void:
	var l := Label3D.new()
	l.text = t
	l.font_size = 96
	l.pixel_size = 0.08
	l.modulate = c
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.no_depth_test = true
	l.position = donde
	l.rotation_degrees = Vector3(-90, 0, 0)   # tumbado, mirando a la camara
	get_root().add_child(l)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	return m
