extends Node3D
## Reglas, marcador y estado de la vuelta. No sabe como esta hecho el campo:
## solo le pide el par, el viento, el tee, la bandera, la zona bajo la bola y
## si algo se ha chocado.

# --- calibracion de juego ---
const QUIETA := 0.3
# una bola rodando a QUIETA gira a QUIETA/RADIO rad/s: a escala real son 14
# rad/s, no los 2 que valian cuando la bola medía 40 cm
const QUIETA_GIRO := QUIETA / Util.RADIO * 2.0
const ESPERA_QUIETA := 0.2
# Un piche cae con backspin y frena de golpe, no rueda como una bola de golf:
# con el damp del cesped solo (calle 0.3) tardaba mas de 10 s en asentarse
# despues de caer, y hasta que no estaba "quieto" no se recuperaba el control.
const FRENO_ATERRIZAJE := 0.32   # fraccion de velocidad que le queda al tocar
# Tope duro ademas del freno: con poco damp (calle) el resto de velocidad que
# sobrevive al freno igual podia reptar mas de la cuenta. A partir de este
# tiempo EN EL SUELO (no cuenta el vuelo) se corta y se da por quieta.
const CAIDA_MAX := 0.5
const VEL_MARCA := 15.0
const PENA_ANIMAL := 2
const PENA_DROP := 1
const MAX_MARCAS := 30
# --- direccion en el aire (SBG) ---
const AIRE_ACEL := 11.0     # m/s2 laterales mientras se dirige
const AIRE_TIEMPO := 1.1    # segundos de timon por golpe
# --- rodar el piche con el mando ---
const CONDUCE_ACEL := 7.0   # m/s2 que mete el stick izquierdo
const CONDUCE_MAX := 4.5    # m/s: es andar, no un golpe
const GIRO_MAX := 9.0       # rad/s: por encima de esto la vuelta es un borron
# --- stamina y correa ---
# Andar es gratis pero solo alrededor de donde caiste; para ir mas lejos hay
# que saltar, y saltar cuesta stamina. La basura del campo la repone: es lo que
# obliga a desviarse de la linea recta al hoyo.
const RADIO_ANDAR := 5.0
const PASOS_LIMITE := 48
const STAMINA_MAX := 100.0
const STAMINA_BASURA := 20.0
const STAMINA_SALTO := 60.0   # lo que cuesta un salto a barra llena
# Por debajo de esto no hay impulso: ni barra, ni golpe minimo. Es el mismo
# numero que pinta de rojo el circulo y la barra, para que lo que se ve y lo
# que se puede hacer sean la misma regla.
const STAMINA_MIN := STAMINA_SALTO * 0.2
const R_RECOGE := 1.2
# --- puntos (SBG puntua, no cuenta golpes) ---
const PUNTOS_HOYO := 100
const PUNTOS_GOLPE := 25    # lo que vale cada golpe ahorrado sobre el par
# A escala real la bola son 4 cm: a 20 m ya no se ve. Se dibuja agrandada de
# modo que ocupe SIEMPRE la misma fraccion de la pantalla, calculada con el fov
# y la distancia reales de la camara. La colision sigue siendo la esfera de 4 cm.
const MODELO_BOLA := "res://modelos/PicheLowHighTest07.fbx"
const VISTA_PANTALLA := 0.14    # subelo y el piche se ve mas grande
# ----------------------------

var indice := 0
var golpes := 0
var total := 0
var tarjeta: Array[int] = []
var embocada := false
var quieto := true
var listo := false
var _t_lento := 0.0
var _t_caida := 0.0       # cuanto lleva EN EL SUELO desde que aterrizo, para CAIDA_MAX
var _golpe_volo := false  # si este golpe llego a volar (pos.y > umbral); ver CAIDA_MAX
var _v_pendiente := Vector3.ZERO
var _giro := 0.0
var _en_aire := false
var _desde := Vector3.ZERO
var _ultimo := 0.0        # distancia del ultimo golpe, para el aviso
var _diam_bola := 1.0     # tamano del modelo tal cual viene, en sus unidades
var _caja_bola := AABB()
var stamina := STAMINA_MAX
var _ancla := Vector3.ZERO               # centro del circulo en el que se anda
var _limite: MeshInstance3D
var _angulo_rueda := 0.0                 # cuanto lleva rodado
var _eje_rueda := Vector3.RIGHT          # el eje del disco: su cara plana
var _dir_rueda := Vector3.FORWARD
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
var barra_stam: ProgressBar


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
	_crear_limite()
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


## El piche no es una bola, es un disco: su lado corto es la X del modelo
## (1.43 contra 2.05 y 2.17), asi que esa es la cara plana. Rueda como una
## RUEDA, con la cara plana de eje; acumulando la vuelta sin mas caia de canto
## y avanzaba de costado.
##
## Tampoco vale la vuelta del cuerpo rigido: la esfera de colision son 2 cm y a
## 4 m/s giraria a 200 rad/s, un borron. Se rueda como rodaria un disco del
## tamano DIBUJADO, con tope para que a velocidad de drive siga leyendose.
func _rodar(e: float, dt: float) -> Basis:
	var plana := Vector3(bola.linear_velocity.x, 0.0, bola.linear_velocity.z)
	if plana.length() > 0.05:
		# el eje se recoloca con el rumbo: la rueda gira para seguir la linea
		_dir_rueda = plana.normalized()
		_eje_rueda = Vector3.UP.cross(_dir_rueda)
		var radio := _diam_bola * e * 0.5
		if dt > 0.0 and radio > 0.0:
			_angulo_rueda += minf(plana.length() / radio, GIRO_MAX) * dt
	return Basis(_eje_rueda, _angulo_rueda) \
		* Basis(_eje_rueda, Vector3.UP, _dir_rueda)


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
func _escalar_vista(dist: float, dt := 0.0) -> void:
	var alto := 2.0 * dist * tan(deg_to_rad(camara.fov) * 0.5)
	var e := maxf(Util.RADIO * 2.0, VISTA_PANTALLA * alto) / _diam_bola
	var base := _rodar(e, dt).scaled(Vector3.ONE * e)
	var caja := Transform3D(base, Vector3.ZERO) * _caja_bola
	vista.global_transform = Transform3D(base, bola.global_position - Vector3(
		caja.get_center().x, caja.position.y + Util.RADIO, caja.get_center().z))


## El circulo hasta donde se puede andar. Se dibuja una vez por anclaje, no por
## fotograma: cada punto es un rayo contra el terreno y son 48.
func _crear_limite() -> void:
	_limite = MeshInstance3D.new()
	_limite.mesh = ImmediateMesh.new()
	var m := Util.mat(Color.WHITE)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_limite.material_override = m
	_limite.top_level = true
	add_child(_limite)


## Fija el centro del circulo donde esta la bola y redibuja el borde.
func _anclar() -> void:
	_ancla = bola.global_position
	var im: ImmediateMesh = _limite.mesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in PASOS_LIMITE + 1:
		var a := TAU * i / PASOS_LIMITE
		var x := _ancla.x + cos(a) * RADIO_ANDAR
		var z := _ancla.z + sin(a) * RADIO_ANDAR
		im.surface_add_vertex(Vector3(x, campo.altura_terreno(x, z) + 0.06, z))
	im.surface_end()


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

	barra_stam = ProgressBar.new()
	barra_stam.show_percentage = false
	barra_stam.max_value = STAMINA_MAX
	barra_stam.custom_minimum_size = Vector2(320, 14)
	barra_stam.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM,
		Control.PRESET_MODE_MINSIZE, 72)
	capa.add_child(barra_stam)

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
	stamina = STAMINA_MAX
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
	_t_caida = 0.0
	_aplicar_damp()
	_anclar()


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
	# fuerza sigue puesta: golpe.gd la borra despues de emitir
	stamina = maxf(0.0, stamina - STAMINA_SALTO * golpe.fuerza)
	_desde = bola.global_position
	_aire = AIRE_TIEMPO
	_v_pendiente = velocidad
	_golpe_volo = false
	# el angulo de salida ya es fijo, asi que el efecto sale casi constante; lo
	# que si cambia es el rough, de donde la bola sale sin freno
	var z := campo.zona(_desde.x, _desde.z)
	_giro = clampf(velocidad.normalized().y * 2.2, 0.25, 1.0) * campo.retiene_efecto(z)


func _process(dt: float) -> void:
	if not listo:
		return
	golpe.activo = quieto and not embocada
	# desde el rough se controla peor: el mismo dato que retiene el efecto
	golpe.estabilidad = campo.retiene_efecto(campo.zona(
		bola.global_position.x, bola.global_position.z))
	# sin stamina no hay impulso: la barra no sube y cargar() ni empieza
	golpe.tope = clampf(stamina / STAMINA_SALTO, 0.0, 1.0)
	golpe.puede_saltar = stamina >= STAMINA_MIN

	var cogidas := campo.recoger(bola.global_position, R_RECOGE)
	if cogidas > 0:
		stamina = minf(STAMINA_MAX, stamina + cogidas * STAMINA_BASURA)
		_aviso("+%d stamina" % roundi(cogidas * STAMINA_BASURA), 0.8)

	# verde mientras quede para saltar, rojo cuando ya no
	var hay := stamina >= STAMINA_MIN
	_limite.visible = golpe.activo
	_limite.material_override.albedo_color = (Color(0.45, 1.0, 0.55, 0.8)
		if hay else Color(1.0, 0.4, 0.35, 0.8))
	barra_stam.value = stamina
	barra_stam.modulate = Color(0.45, 1.0, 0.55) if hay else Color(1.0, 0.4, 0.35)

	if golpe.activo and Input.is_key_pressed(KEY_R):
		_drop()

	campo.mover_animales(dt, bola.global_position,
		not quieto and bola.linear_velocity.length() > 10.0)

	# Que la bola no se pierda de vista. Parada se dibuja a tamano real, que es
	# cuando la camara esta encima y se vería un melon al lado del palo; en
	# juego se agranda con la distancia, de modo que ocupa siempre lo mismo.
	_escalar_vista(camara.global_position.distance_to(bola.global_position), dt)

	barra.value = golpe.fuerza * 100.0
	var p := bola.global_position
	var b := campo.pos_bandera()
	var dist := Vector2(p.x - b.x, p.z - b.z).length()
	var v := campo.viento()
	hud.text = ("Hoyo %d/%d | Par %d | Golpes %d | %d puntos | %d m al hoyo\n"
		+ "Stamina %d | basura %d | Fuerza %d%% (%.0f m/s) +-%.1f deg | %s | viento %.0f m/s\n"
		+ "Timon %s") % [
		indice + 1, Campo.HOYOS.size(), campo.par(), golpes, total, roundi(dist),
		roundi(stamina), campo.basura.size(),
		roundi(golpe.fuerza * 100), golpe.velocidad(),
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
		_conducir()
		_atar()
		# tambien vale meterlo rodando: es la parte de "llevalo tu" de SBG
		if campo.embocada(bola.global_position):
			_embocar()
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
	_golpe_volo = _golpe_volo or volando
	var zona := campo.zona(pos.x, pos.z)
	bola.linear_damp = 0.0 if volando else campo.damp_suelo() * campo.factor_damp(zona)
	estela.emitting = volando and vel.length() > 20.0
	if _en_aire and not volando:
		if vel.length() > VEL_MARCA:
			_marca(pos, vel.length())
		# el toque de aterrizaje: como el piche cae con backspin, aqui pierde
		# de golpe casi toda la velocidad en vez de seguir rodando largo. El
		# giro tambien se corta, si no la friccion lo va reacelerando y el
		# check de "quieto" (que mira angular_velocity) no llega a cumplirse.
		bola.linear_velocity *= FRENO_ATERRIZAJE
		bola.angular_velocity *= FRENO_ATERRIZAJE
		vel = bola.linear_velocity
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
	if not volando:
		var casi_quieta := vel.length() < QUIETA and bola.angular_velocity.length() < QUIETA_GIRO
		_t_lento = _t_lento + dt if casi_quieta else 0.0
		# CAIDA_MAX solo corta el REBOTE despues de un golpe que voló: para un
		# piche corto que nunca despega (un putt) no hay caida que cortar, y
		# aplicarlo igual lo paraba en seco a mitad de rodada. Sin volar de
		# por medio, se frena solo como siempre: gradual, con el damp del suelo.
		var corte_por_tiempo := false
		if _golpe_volo:
			_t_caida += dt
			corte_por_tiempo = _t_caida >= CAIDA_MAX
		if _t_lento >= ESPERA_QUIETA or corte_por_tiempo:
			bola.linear_velocity = Vector3.ZERO
			bola.angular_velocity = Vector3.ZERO
			bola.freeze = true
			quieto = true
			_ultimo = Vector2(pos.x - _desde.x, pos.z - _desde.z).length()
			_anclar()
			_aviso("%d m" % roundi(_ultimo), 1.6)
	else:
		_t_lento = 0.0
		_t_caida = 0.0


## El stick izquierdo rueda el piche mientras esta parado. En el aire ese mismo
## stick es el timon, asi que no se pisan. El tope de velocidad es lo que separa
## andar de pegar: para cruzar el campo hay que golpear.
func _conducir() -> void:
	var dir: Vector3 = golpe.mando()
	if dir == Vector3.ZERO:
		return
	if Vector3(bola.linear_velocity.x, 0, bola.linear_velocity.z).length() > CONDUCE_MAX:
		return
	# la correa: andando no se sale del circulo. En el borde se deja empujar
	# hacia dentro, si no se quedaria pegado al limite sin poder volver.
	var fuera := Vector2(bola.global_position.x - _ancla.x,
		bola.global_position.z - _ancla.z)
	if fuera.length() >= RADIO_ANDAR and Vector2(dir.x, dir.z).dot(fuera.normalized()) > 0.0:
		return
	bola.freeze = false      # congelada no admite fuerzas
	bola.apply_central_force(dir * CONDUCE_ACEL * Util.MASA)


## Andando no se sale del circulo. No basta con dejar de empujar: con la
## inercia se cruzaba igual. Se le quita la velocidad que apunta hacia fuera y
## se le devuelve al borde.
##
## ponytail: mover un cuerpo rigido a mano fuera de _integrate_forces no es lo
## fino, pero aqui son centimetros y solo en el borde. Si diera guerra, lo suyo
## seria un muro de colision cilindrico que se mueve con el ancla.
func _atar() -> void:
	var d := Vector2(bola.global_position.x - _ancla.x,
		bola.global_position.z - _ancla.z)
	if d.length() <= RADIO_ANDAR:
		return
	var n := d.normalized()
	var fuera := Vector3(n.x, 0, n.y)
	var salida := bola.linear_velocity.dot(fuera)
	if salida > 0.0:
		bola.linear_velocity -= fuera * salida
	bola.global_position = Vector3(_ancla.x + n.x * RADIO_ANDAR,
		bola.global_position.y, _ancla.z + n.y * RADIO_ANDAR)


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
	_angulo_rueda = 2.1
	_escalar_vista(6.0)
	var apoyo: AABB = vista.global_transform * _caja_bola
	assert(absf(apoyo.position.y - (bola.global_position.y - Util.RADIO)) < 0.001,
		"el piche no se apoya en el suelo al girar")
	# y rodar como una rueda: la cara plana del disco se queda en el eje de
	# giro, perpendicular a la marcha, en vez de irse de canto
	bola.linear_velocity = Vector3(3.0, 0, 0)
	var antes := _angulo_rueda
	_escalar_vista(6.0, 0.1)
	assert(_angulo_rueda > antes, "el piche no rueda")
	assert(is_zero_approx(_eje_rueda.dot(bola.linear_velocity.normalized())),
		"la cara plana del disco no queda perpendicular a la marcha")
	bola.linear_velocity = Vector3.ZERO
	_angulo_rueda = 0.0
	assert(campo.basura.size() > 0, "el hoyo se quedo sin basura que recoger")
	# la correa: se le empuja lejos y tiene que volver al borde
	var centro := bola.global_position
	bola.global_position = centro + Vector3(RADIO_ANDAR * 3.0, 0, 0)
	bola.linear_velocity = Vector3(9.0, 0, 0)
	_atar()
	assert(Vector2(bola.global_position.x - _ancla.x,
		bola.global_position.z - _ancla.z).length() <= RADIO_ANDAR + 0.001,
		"el piche se sale del area")
	assert(bola.linear_velocity.x <= 0.001, "no se le quita la velocidad de salida")
	bola.global_position = centro
	bola.linear_velocity = Vector3.ZERO
	# y sin stamina no hay impulso
	var stamina_previa := stamina
	stamina = 0.0
	golpe.puede_saltar = false
	golpe.activo = true
	golpe.cargar()
	golpe.soltar()
	assert(_v_pendiente == Vector3.ZERO, "salio impulso sin stamina")
	stamina = stamina_previa
	golpe.puede_saltar = true
	print("modelo %s | caja %s | diametro %.2f u"
		% [MODELO_BOLA.get_file(), str(_caja_bola), _diam_bola])
	print("self-check OK | tee %s | bandera %s | %d m | par %d"
		% [str(t.round()), str(b.round()),
		   roundi(Vector2(t.x - b.x, t.z - b.z).length()), campo.par()])
	if DisplayServer.get_name() == "headless":
		await get_tree().create_timer(0.5).timeout
		golpe.activo = true      # soltar() sale de vacio si no hubo cargar()
		golpe.cargar()
		golpe.fuerza = 1.0
		golpe.soltar()
		assert(_v_pendiente != Vector3.ZERO, "el golpe no salio")
		assert(stamina < STAMINA_MAX, "el salto no gasta stamina")
