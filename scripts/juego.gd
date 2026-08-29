extends Node3D
## Reglas, marcador y estado de la vuelta. No sabe como esta hecho el campo:
## solo le pide el par, el viento, el tee, la bandera, la zona bajo la bola y
## si algo se ha chocado.

# --- calibracion de juego ---
const QUIETA := 0.3
# una bola rodando a QUIETA gira a QUIETA/RADIO rad/s: a escala real son 14
# rad/s, no los 2 que valian cuando la bola medía 40 cm
const QUIETA_GIRO := QUIETA / Util.RADIO * 2.0
const ESPERA_QUIETA := 0.35
const VEL_MARCA := 15.0
const PENA_ANIMAL := 2
const PENA_DROP := 1
const MAX_MARCAS := 30
# --- direccion en el aire (SBG) ---
const AIRE_ACEL := 11.0     # m/s2 laterales mientras se dirige
const AIRE_TIEMPO := 1.1    # segundos de timon por golpe
# --- puntos (SBG puntua, no cuenta golpes) ---
const PUNTOS_HOYO := 100
const PUNTOS_GOLPE := 25    # lo que vale cada golpe ahorrado sobre el par
# A escala real la bola son 4 cm: a 20 m ya no se ve. Se dibuja agrandada de
# modo que ocupe SIEMPRE la misma fraccion de la pantalla, calculada con el fov
# y la distancia reales de la camara. La colision sigue siendo la esfera de 4 cm.
const MODELO_BOLA := "res://modelos/PicheLowHighTest07.fbx"
const VISTA_PANTALLA := 0.075   # subelo y el piche se ve mas grande
# ----------------------------

var indice := 0
var golpes := 0
var total := 0
var tarjeta: Array[int] = []
var embocada := false
var quieto := true
var listo := false
var _t_lento := 0.0
var _v_pendiente := Vector3.ZERO
var _giro := 0.0
var _en_aire := false
var _desde := Vector3.ZERO
var _ultimo := 0.0        # distancia del ultimo golpe, para el aviso
var _diam_bola := 1.0     # tamano del modelo tal cual viene, en sus unidades
var _caja_bola := AABB()
var _aire := 0.0          # timon que le queda a este golpe
var _marcas: Array = []

var campo: Campo
var bola: RigidBody3D
var vista: Node3D
var estela: CPUParticles3D
var camara: Camera3D
var golpe: Node3D
var entorno: WorldEnvironment
var hud: Label
var msg: Label
var barra: ProgressBar
var deslizador: VSlider


func _ready() -> void:
	randomize()
	camara = Camera3D.new()
	camara.fov = 62.0
	camara.far = 4000.0
	add_child(camara)

	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-48, -35, 0)
	sol.light_energy = 1.35
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 300.0
	add_child(sol)

	var cielo_mat := ProceduralSkyMaterial.new()
	cielo_mat.sky_top_color = Color(0.32, 0.55, 0.90)
	cielo_mat.sky_horizon_color = Color(0.78, 0.87, 0.95)
	cielo_mat.ground_horizon_color = Color(0.78, 0.87, 0.95)
	cielo_mat.sun_angle_max = 12.0
	var cielo := Sky.new()
	cielo.sky_material = cielo_mat
	entorno = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = cielo
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# con 0.9 el relleno del cielo tapaba la sombra propia y el piche se veia
	# como una silueta plana; a 0.5 el sol vuelve a modelar el volumen
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_density = 0.0008
	env.fog_light_color = Color(0.78, 0.87, 0.95)
	entorno.environment = env
	add_child(entorno)

	_crear_bola()
	_crear_ui()

	golpe = $Golpe
	golpe.preparar(bola, camara)
	golpe.golpeado.connect(_on_golpeado)

	campo = Campo.new()
	add_child(campo)
	campo.excluir = [bola.get_rid()]
	msg.text = "Cargando el campo..."
	await campo.preparar()
	msg.text = ""

	golpe.suelo = Callable(campo, "altura_terreno")
	_ir_a_hoyo(0)
	listo = true
	_self_check()


func _crear_bola() -> void:
	bola = RigidBody3D.new()
	bola.mass = Util.MASA
	bola.physics_material_override = Util.fisica()
	bola.continuous_cd = true
	bola.freeze = true
	var col := CollisionShape3D.new()
	var esf := SphereShape3D.new()
	esf.radius = Util.RADIO
	col.shape = esf
	bola.add_child(col)

	# el .fbx es una escena entera (cuerpo, garras y ojos, cada uno con su
	# material) y trae animaciones sueltas de Blender: una camara y unas cajas
	# que, si alguna arrancara, moverian el modelo. Fuera.
	vista = (load(MODELO_BOLA) as PackedScene).instantiate()
	var reproductor := vista.get_node_or_null("AnimationPlayer")
	if reproductor:
		reproductor.free()
	# la vista se coloca a mano en coordenadas de mundo, no la arrastra la bola
	vista.top_level = true
	bola.add_child(vista)

	estela = Util.particulas(Color(1, 1, 1, 0.5), 0.4, 20)
	estela.one_shot = false
	estela.emitting = false
	bola.add_child(estela)
	add_child(bola)
	# ya en el arbol y sin mover: las cajas globales de las mallas son la caja
	# del modelo en sus propias unidades
	_caja_bola = _preparar_modelo(vista)
	_diam_bola = maxf(_caja_bola.size[_caja_bola.size.max_axis_index()], 0.0001)
	_escalar_vista(1.0)


## Junta la caja de todas las mallas del modelo y les da algo de brillo: el
## .fbx las exporta con rugosidad 1, y sin un reflejo el piche vuelve a leerse
## como una silueta plana por muy bien iluminado que este.
func _preparar_modelo(raiz: Node3D) -> AABB:
	var caja := AABB()
	var primera := true
	for n in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var c: AABB = mi.global_transform * mi.mesh.get_aabb()
		caja = c if primera else caja.merge(c)
		primera = false
		for i in mi.mesh.get_surface_count():
			var mat: StandardMaterial3D = mi.get_active_material(i)
			if mat:
				mat.roughness = 0.55
	assert(not primera, "el modelo de la bola no trae ninguna malla")
	return caja


## Escala el modelo para que ocupe VISTA_PANTALLA del alto del encuadre, este
## donde este la camara y con el fov que tenga. Nunca por debajo del tamano real.
##
## El apoyo es lo delicado: el piche gira con la bola, asi que su punto mas bajo
## cambia con la vuelta que lleve. Se calcula la caja YA GIRADA y se apoya justo
## en el punto de contacto de la bola. Antes el levante iba en ejes de la bola y
## al rodar apuntaba hacia abajo: por eso se hundia en el mapa.
func _escalar_vista(dist: float) -> void:
	var alto := 2.0 * dist * tan(deg_to_rad(camara.fov) * 0.5)
	var e := maxf(Util.RADIO * 2.0, VISTA_PANTALLA * alto) / _diam_bola
	var base := bola.global_basis.scaled(Vector3.ONE * e)
	var caja := Transform3D(base, Vector3.ZERO) * _caja_bola
	vista.global_transform = Transform3D(base, bola.global_position - Vector3(
		caja.get_center().x, caja.position.y + Util.RADIO, caja.get_center().z))


func _crear_ui() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)

	hud = Label.new()
	hud.position = Vector2(24, 18)
	hud.add_theme_font_size_override("font_size", 20)
	capa.add_child(hud)

	msg = Label.new()
	msg.add_theme_font_size_override("font_size", 44)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	capa.add_child(msg)

	barra = ProgressBar.new()
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(320, 22)
	barra.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 40)
	capa.add_child(barra)

	# el angulo es el control incomodo en tactil: un deslizador se ve y se toca
	# con el pulgar izquierdo mientras el derecho carga
	deslizador = VSlider.new()
	deslizador.min_value = 5.0
	deslizador.max_value = 55.0
	deslizador.value = 22.0
	deslizador.custom_minimum_size = Vector2(48, 220)
	deslizador.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT,
		Control.PRESET_MODE_MINSIZE, 24)
	deslizador.value_changed.connect(func(v): golpe.loft = v)
	capa.add_child(deslizador)

	if DisplayServer.is_touchscreen_available():
		var pegar := Button.new()
		pegar.text = "GOLPE"
		pegar.custom_minimum_size = Vector2(190, 190)
		pegar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT,
			Control.PRESET_MODE_MINSIZE, 32)
		pegar.button_down.connect(func(): golpe.cargar())
		pegar.button_up.connect(func(): golpe.soltar())
		capa.add_child(pegar)

		var drop := Button.new()
		drop.text = "DROP +1"
		drop.custom_minimum_size = Vector2(130, 64)
		drop.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT,
			Control.PRESET_MODE_MINSIZE, 24)
		drop.pressed.connect(_drop)
		capa.add_child(drop)


func _ir_a_hoyo(i: int) -> void:
	_marcas.clear()
	campo.ir_a(i)
	golpe.reset(campo.pos_tee(), campo.pos_bandera())
	golpe.viento = campo.viento()
	_poner_bola(campo.pos_tee())
	golpe.encuadrar()


func _poner_bola(donde: Vector3) -> void:
	bola.freeze = true
	bola.linear_velocity = Vector3.ZERO
	bola.angular_velocity = Vector3.ZERO
	bola.global_position = Vector3(donde.x,
		campo.altura_terreno(donde.x, donde.z) + Util.RADIO, donde.z)
	bola.angular_damp = 0.6
	quieto = true
	_en_aire = false
	_giro = 0.0
	estela.emitting = false
	_t_lento = 0.0
	_aplicar_damp()


func _aplicar_damp() -> void:
	var p := bola.global_position
	bola.linear_damp = campo.damp_suelo() * campo.factor_damp(campo.zona(p.x, p.z))


func _drop() -> void:
	if not (quieto and not embocada and listo):
		return
	golpes += PENA_DROP
	_poner_bola(bola.global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))
	_aviso("Drop  +%d" % PENA_DROP, 1.0)


func _on_golpeado(velocidad: Vector3) -> void:
	golpes += 1
	_desde = bola.global_position
	_aire = AIRE_TIEMPO
	_v_pendiente = velocidad
	# mas loft, mas efecto hacia atras; y desde el rough la bola sale sin freno
	var z := campo.zona(_desde.x, _desde.z)
	_giro = clampf(velocidad.normalized().y * 2.2, 0.25, 1.0) * campo.retiene_efecto(z)


func _process(dt: float) -> void:
	if not listo:
		return
	golpe.activo = quieto and not embocada
	# desde el rough se controla peor: el mismo dato que retiene el efecto
	golpe.estabilidad = campo.retiene_efecto(campo.zona(
		bola.global_position.x, bola.global_position.z))

	if golpe.activo and Input.is_key_pressed(KEY_R):
		_drop()

	if absf(deslizador.value - golpe.loft) > 0.1:
		deslizador.set_value_no_signal(golpe.loft)

	campo.mover_animales(dt, bola.global_position,
		not quieto and bola.linear_velocity.length() > 10.0)

	# Que la bola no se pierda de vista. Parada se dibuja a tamano real, que es
	# cuando la camara esta encima y se vería un melon al lado del palo; en
	# juego se agranda con la distancia, de modo que ocupa siempre lo mismo.
	_escalar_vista(camara.global_position.distance_to(bola.global_position))

	barra.value = golpe.fuerza * 100.0
	var p := bola.global_position
	var b := campo.pos_bandera()
	var dist := Vector2(p.x - b.x, p.z - b.z).length()
	var v := campo.viento()
	hud.text = ("Hoyo %d/%d | Par %d | Golpes %d | %d puntos | %d m al hoyo\n"
		+ "Angulo %d deg | fuerza %d%% (%.0f m/s) +-%.1f deg | %s | viento %.0f m/s\n"
		+ "Timon %s") % [
		indice + 1, Campo.HOYOS.size(), campo.par(), golpes, total, roundi(dist),
		roundi(golpe.loft), roundi(golpe.fuerza * 100), golpe.velocidad(),
		rad_to_deg(golpe.dispersion()),
		campo.nombre_zona(campo.zona(p.x, p.z)), Vector2(v.x, v.z).length(),
		"#".repeat(ceili(_aire / AIRE_TIEMPO * 10.0)) if _aire > 0.0 else "-"]


func _physics_process(dt: float) -> void:
	if not listo or embocada:
		return

	# el golpe se aplica aqui: descongelar y empujar en el mismo tick de fisica
	if _v_pendiente != Vector3.ZERO:
		bola.freeze = false
		quieto = false
		_t_lento = 0.0
		bola.apply_central_impulse(_v_pendiente * Util.MASA)
		_v_pendiente = Vector3.ZERO
		return

	if quieto:
		return

	var pos := bola.global_position
	var vel := bola.linear_velocity
	if pos.y < -60.0:
		_poner_bola(_desde)
		return

	if campo.embocada(pos):
		_embocar()
		return

	var suelo := campo.altura_terreno(pos.x, pos.z)
	var volando := pos.y > suelo + Util.RADIO + 0.4
	var zona := campo.zona(pos.x, pos.z)
	bola.linear_damp = 0.0 if volando else campo.damp_suelo() * campo.factor_damp(zona)
	estela.emitting = volando and vel.length() > 20.0
	if _en_aire and not volando and vel.length() > VEL_MARCA:
		_marca(pos, vel.length())
	_en_aire = volando

	_giro = maxf(0.0, _giro - dt / Util.VIDA_GIRO)
	bola.apply_central_force(Util.fuerza_aire(vel, campo.viento(), _giro))

	# timon: solo en el aire y solo mientras quede presupuesto. Empuja de lado,
	# perpendicular al avance, asi que corrige la linea sin regalar distancia.
	var plana := Vector3(vel.x, 0, vel.z)
	if volando and _aire > 0.0 and absf(golpe.timon) > 0.05 and plana.length() > 1.0:
		var lado := Vector3.UP.cross(plana.normalized())
		bola.apply_central_force(lado * golpe.timon * AIRE_ACEL * Util.MASA)
		_aire = maxf(0.0, _aire - dt)

	if campo.choque(pos, vel) == "animal":
		golpes += PENA_ANIMAL
		_aviso("Le diste a un animal!  +%d golpes" % PENA_ANIMAL, 1.2)

	# ponytail: el frenado es exponencial, asi que la cola es larga y la bola
	# repta un rato. Si se nota flotante, cambiarlo por resistencia a la
	# rodadura: fuerza constante en contra, no proporcional a la velocidad.
	if not volando and vel.length() < QUIETA and bola.angular_velocity.length() < QUIETA_GIRO:
		_t_lento += dt
		if _t_lento >= ESPERA_QUIETA:
			bola.freeze = true
			quieto = true
			_ultimo = Vector2(pos.x - _desde.x, pos.z - _desde.z).length()
			_aviso("%d m" % roundi(_ultimo), 1.6)
	else:
		_t_lento = 0.0


func _marca(pos: Vector3, v: float) -> void:
	var r := clampf(v * 0.005, 0.06, 0.35)
	var m := Util.disco(r, 0.02, Color(0.30, 0.24, 0.14))
	m.position = Vector3(pos.x, campo.altura_terreno(pos.x, pos.z) + 0.02, pos.z)
	campo.add_child(m)
	_marcas.append(m)
	if _marcas.size() > MAX_MARCAS:
		var viejo: Node3D = _marcas.pop_front()
		if is_instance_valid(viejo):
			viejo.queue_free()
	Util.reventar(campo, pos, Color(0.35, 0.30, 0.18), 10)


func _aviso(texto: String, seg: float) -> void:
	msg.text = texto
	await get_tree().create_timer(seg).timeout
	if msg.text == texto:
		msg.text = ""


func _embocar() -> void:
	embocada = true
	bola.freeze = true
	estela.emitting = false
	tarjeta.append(golpes)
	var d := golpes - campo.par()
	# SBG puntua en vez de contar golpes: terminar vale, ahorrar golpes vale mas
	var puntos := maxi(0, PUNTOS_HOYO - d * PUNTOS_GOLPE)
	total += puntos
	msg.text = "%s  +%d" % [
		"Birdie!" if d < 0 else ("Par" if d == 0 else "+%d" % d), puntos]
	await get_tree().create_timer(1.8).timeout
	msg.text = ""
	golpes = 0
	indice += 1
	if indice >= Campo.HOYOS.size():
		indice = 0
		total = 0
		tarjeta.clear()
	_ir_a_hoyo(indice)
	embocada = false


# ponytail: un solo chequeo, salta si el campo o el hoyo se montan mal
func _self_check() -> void:
	var t := campo.pos_tee()
	var b := campo.pos_bandera()
	assert(t != Vector3.ZERO and b != Vector3.ZERO, "tee o bandera sin colocar")
	assert(absf(t.y) > 0.01, "el rayo de altura no encuentra el campo bajo el tee")
	assert(campo.R_COPA > Util.RADIO * 1.5, "la copa no admite la bola")
	# el piche tiene que ocupar lo mismo en pantalla este cerca o lejos
	_escalar_vista(4.0)
	var cerca := _diam_bola * vista.scale.x / 4.0
	_escalar_vista(40.0)
	assert(is_equal_approx(cerca, _diam_bola * vista.scale.x / 40.0),
		"la bola no mantiene el tamano en pantalla")
	# y apoyarse en el suelo con cualquier vuelta, que es lo que se hundia
	bola.global_rotation = Vector3(1.1, 0.7, -0.4)
	_escalar_vista(6.0)
	var apoyo: AABB = vista.global_transform * _caja_bola
	assert(absf(apoyo.position.y - (bola.global_position.y - Util.RADIO)) < 0.001,
		"el piche no se apoya en el suelo al girar")
	bola.global_rotation = Vector3.ZERO
	print("modelo %s | caja %s | diametro %.2f u"
		% [MODELO_BOLA.get_file(), str(_caja_bola), _diam_bola])
	print("self-check OK | tee %s | bandera %s | %d m | par %d"
		% [str(t.round()), str(b.round()),
		   roundi(Vector2(t.x - b.x, t.z - b.z).length()), campo.par()])
	if DisplayServer.get_name() == "headless":
		await get_tree().create_timer(0.5).timeout
		golpe.fuerza = 1.0
		golpe.soltar()
