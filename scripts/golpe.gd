extends Node3D
## El swing: apuntado, potencia, palo con animacion y camara.
## No conoce las reglas: cuando el jugador suelta, emite la velocidad de salida.

signal golpeado(velocidad: Vector3)

# --- calibracion de la fuerza ---
const VEL_MIN := 4.0        # un putt corto
const VEL_MAX := 68.0       # un drive completo
const CARGA_POR_SEG := 0.5  # 2 s de barra entera: antes era 0.9 s y todo salia a tope
# La distancia va con el CUADRADO de la velocidad, asi que una barra lineal se
# siente "todo o nada". Con CURVA<1 la barra se lee casi como distancia.
const CURVA := 0.75
const LOFT_MIN := 5.0
const LOFT_MAX := 55.0
# --------------------------------

# --- camara ---
const CAM_ALTO_TIRO := 1.7
const CAM_ATRAS_TIRO := 3.2
# La camara se aleja y abre el angulo con la velocidad: encuadra igual un putt
# que un drive, y el ensanchado del fov da la sensacion de velocidad.
const CAM_ATRAS_MIN := 5.0
const CAM_ATRAS_MAX := 14.0
const CAM_ALTO_MIN := 1.6
const CAM_ALTO_MAX := 5.5
const CAM_FOV := 62.0
const CAM_FOV_MAX := 82.0
const CAM_VEL_REF := 55.0      # m/s a los que la camara esta del todo abierta
const CAM_SUAVIZADO := 14.0
const CAM_FOV_SUAVIZADO := 4.0 # el fov va mas lento que la posicion: asi se nota
# --------------

# --- swing ---
# El hombro manda: el palo cuelga de el y barre un plano inclinado que pasa por
# la bola, en vez de girar en horizontal a su alrededor como un helicoptero.
# El largo y la inclinacion salen de HOMBRO, asi que la cabeza cae SIEMPRE
# sobre la bola con _swing = 0.
const HOMBRO := Vector3(0.45, 0.95, 0)
const BACKSWING := 2.6         # rad de subida a barra llena (~150 grados)
const ACOMPANA := -2.4         # rad de acompanamiento tras el impacto
# -------------

const LARGO_MIRA := 60.0    # metros de linea de apuntado
const PASOS_MIRA := 30

var mira := 0.0
var loft := 22.0
var fuerza := 0.0
var activo := false
var viento := Vector3.ZERO
var suelo: Callable          # (x, z) -> altura del terreno

var _bola: RigidBody3D
var _camara: Camera3D
var _pivote: Node3D          # en la bola, orientado a la mira
var _plano: Node3D           # en el hombro: el palo barre su plano inclinado
var _linea: MeshInstance3D
var _cargando := false
var _swing := 0.0            # angulo en el plano: >0 atras, 0 impacto, <0 acompanando
var _animando := false       # el palo sigue visible aunque la bola ya salio
var _pos_golpe := Vector3.ZERO
var _dir_camara := Vector3.FORWARD


func preparar(bola: RigidBody3D, camara: Camera3D) -> void:
	_bola = bola
	_camara = camara

	# el driver viene en centimetros, con el mastil sobre +Z y el origen en la
	# cabeza: se pone en pie (+Z -> +Y) colgando del hombro
	_pivote = Node3D.new()          # en la bola, orientado a la mira
	_plano = Node3D.new()           # en el hombro, inclinado: el plano de swing
	_plano.position = HOMBRO
	_plano.rotation.z = atan2(-HOMBRO.x, HOMBRO.y)
	var mi := MeshInstance3D.new()
	mi.mesh = load("res://modelos/driver.obj")
	mi.scale = Vector3.ONE * 0.01
	mi.rotation.x = -PI / 2.0
	mi.position = Vector3(0, -Vector2(HOMBRO.x, HOMBRO.y).length(), 0)
	_plano.add_child(mi)
	_pivote.add_child(_plano)
	add_child(_pivote)

	_linea = MeshInstance3D.new()
	_linea.mesh = ImmediateMesh.new()
	var m := Util.mat(Color(1, 0.95, 0.3, 0.9))
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_linea.material_override = m
	_linea.top_level = true
	add_child(_linea)


## Al llegar a un hoyo se apunta a la bandera, que es lo que haria cualquiera.
func reset(tee: Vector3, bandera: Vector3) -> void:
	var d := bandera - tee
	mira = atan2(d.x, d.z)
	loft = 22.0
	fuerza = 0.0
	_cargando = false
	_swing = 0.0


func velocidad() -> float:
	return lerpf(VEL_MIN, VEL_MAX, pow(fuerza, CURVA))


func cargar() -> void:
	if activo and not _cargando:
		_cargando = true
		fuerza = 0.0


func soltar() -> void:
	if not _cargando:
		return
	_cargando = false
	var v := velocidad()
	_pos_golpe = _bola.global_position
	_animar_golpe()
	golpeado.emit(direccion() * v)
	fuerza = 0.0


func _unhandled_input(e: InputEvent) -> void:
	# apuntar arrastrando: en movil funciona igual, con el raton emulado
	if e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and activo:
		mira -= e.relative.x * 0.004
		loft = clampf(loft + e.relative.y * 0.06, LOFT_MIN, LOFT_MAX)


func _process(dt: float) -> void:
	if _bola == null:
		return

	if activo and Input.is_action_just_pressed("ui_accept"):
		cargar()
	if _cargando:
		fuerza = minf(1.0, fuerza + dt * CARGA_POR_SEG)
		_swing = fuerza * BACKSWING  # cuanto mas cargas, mas atras sube el palo
		if Input.is_action_just_released("ui_accept"):
			soltar()
	elif activo:
		if Input.is_action_pressed("ui_left"): mira += dt * 1.0
		if Input.is_action_pressed("ui_right"): mira -= dt * 1.0
		if Input.is_action_pressed("ui_up"): loft = minf(LOFT_MAX, loft + dt * 25.0)
		if Input.is_action_pressed("ui_down"): loft = maxf(LOFT_MIN, loft - dt * 25.0)

	_colocar_palo()
	_dibujar_mira()
	_mover_camara(dt)


func direccion() -> Vector3:
	var a := deg_to_rad(loft)
	return Vector3(sin(mira) * cos(a), sin(a), cos(mira) * cos(a)).normalized()


## Solo se marca HACIA DONDE se apunta, no donde va a caer: adivinar la caida
## le quita al juego la parte de calcular la fuerza.
func _dibujar_mira() -> void:
	var im: ImmediateMesh = _linea.mesh
	im.clear_surfaces()
	_linea.visible = activo
	if not activo or not suelo.is_valid():
		return
	var dir := Vector3(sin(mira), 0, cos(mira))
	var p := _bola.global_position
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in PASOS_MIRA + 1:
		var q := p + dir * (LARGO_MIRA * i / PASOS_MIRA)
		q.y = suelo.call(q.x, q.z) + 0.08
		im.surface_add_vertex(q)
	im.surface_end()


func _colocar_palo() -> void:
	# Mientras dura la animacion el palo se queda donde se pego. Antes se
	# ocultaba en el mismo frame del golpe (activo pasa a false), asi que del
	# swing no se veia nada: solo el palo desapareciendo de golpe.
	_pivote.visible = activo or _animando
	if not _pivote.visible:
		return
	_pivote.global_position = _bola.global_position if activo else _pos_golpe
	_pivote.global_rotation = Vector3(0, mira, 0)
	_plano.rotation.x = _swing


## Bajada acelerando hasta el impacto (_swing = 0, la cabeza sobre la bola),
## acompanamiento frenando y vuelta a la posicion de espera.
func _animar_golpe() -> void:
	_animando = true
	var t := create_tween()
	t.tween_property(self, "_swing", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(self, "_swing", ACOMPANA, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "_swing", 0.0, 0.50).set_trans(Tween.TRANS_SINE).set_delay(0.35)
	t.finished.connect(func(): _animando = false)


func objetivo_camara() -> Vector3:
	if activo:
		return _bola.global_position - Vector3(sin(mira), 0, cos(mira)) * CAM_ATRAS_TIRO \
			+ Vector3.UP * CAM_ALTO_TIRO
	# Detras de la bola, en su direccion de avance. La direccion se recuerda: al
	# final del rodado la velocidad tiembla y la camara daria bandazos.
	var plana := Vector3(_bola.linear_velocity.x, 0, _bola.linear_velocity.z)
	if plana.length() > 1.0:
		_dir_camara = plana.normalized()
	var t := _factor_velocidad()
	return _bola.global_position - _dir_camara * lerpf(CAM_ATRAS_MIN, CAM_ATRAS_MAX, t) \
		+ Vector3.UP * lerpf(CAM_ALTO_MIN, CAM_ALTO_MAX, t)


## 0 con la bola parada, 1 a CAM_VEL_REF. Manda el encuadre y el fov.
func _factor_velocidad() -> float:
	return clampf(_bola.linear_velocity.length() / CAM_VEL_REF, 0.0, 1.0)


func encuadrar() -> void:
	_dir_camara = Vector3(sin(mira), 0, cos(mira))
	_camara.fov = CAM_FOV
	_camara.global_position = objetivo_camara()


func _mover_camara(dt: float) -> void:
	var suave := CAM_SUAVIZADO if not activo else 5.0
	_camara.global_position = _camara.global_position.lerp(objetivo_camara(),
		clampf(dt * suave, 0, 1))
	var fov := CAM_FOV if activo else lerpf(CAM_FOV, CAM_FOV_MAX, _factor_velocidad())
	_camara.fov = lerpf(_camara.fov, fov, clampf(dt * CAM_FOV_SUAVIZADO, 0, 1))
	if activo:
		# mirar por la linea de tiro, no a la bola: se ve a donde va el golpe
		var dir := Vector3(sin(mira), 0, cos(mira))
		_camara.look_at(_bola.global_position + dir * 40.0 + Vector3.UP * 3.0)
	else:
		_camara.look_at(_bola.global_position)
