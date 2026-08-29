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
const CAM_ATRAS_VUELO := 10.0  # pegada a la bola para no perderla de vista
const CAM_ALTO_VUELO := 5.0   # lo justo para mirar por encima de los arboles
const CAM_SUAVIZADO := 14.0
# --------------

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
var _pivote: Node3D          # gira alrededor de la bola: es el swing
var _linea: MeshInstance3D
var _cargando := false
var _swing := 0.0            # angulo del palo respecto a la mira


func preparar(bola: RigidBody3D, camara: Camera3D) -> void:
	_bola = bola
	_camara = camara

	# el driver viene en centimetros y con el mastil sobre +Z: se pone en pie
	_pivote = Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = load("res://modelos/driver.obj")
	mi.scale = Vector3.ONE * 0.01
	mi.rotation.x = -PI / 2.0
	mi.position = Vector3(0.30, 0, 0)
	_pivote.add_child(mi)
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
		_swing = -fuerza * 2.6     # cuanto mas cargas, mas atras va el palo
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
	_pivote.visible = activo
	if not activo:
		return
	_pivote.global_position = _bola.global_position
	_pivote.global_rotation = Vector3(0, mira + _swing, 0)


## Bajada, impacto y acompanamiento. Al terminar vuelve a la posicion de espera.
func _animar_golpe() -> void:
	var t := create_tween()
	t.tween_property(self, "_swing", 1.9, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(self, "_swing", 2.6, 0.22).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "_swing", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_delay(0.3)


func objetivo_camara() -> Vector3:
	var v := _bola.linear_velocity
	if not activo and v.length() > 3.0:
		# pegada por detras de la bola para no perderla de vista
		var atras := Vector3(v.x, 0, v.z).normalized() * CAM_ATRAS_VUELO
		return _bola.global_position - atras + Vector3.UP * CAM_ALTO_VUELO
	return _bola.global_position - Vector3(sin(mira), 0, cos(mira)) * CAM_ATRAS_TIRO \
		+ Vector3.UP * CAM_ALTO_TIRO


func encuadrar() -> void:
	_camara.global_position = objetivo_camara()


func _mover_camara(dt: float) -> void:
	var suave := CAM_SUAVIZADO if not activo else 5.0
	_camara.global_position = _camara.global_position.lerp(objetivo_camara(),
		clampf(dt * suave, 0, 1))
	if activo:
		# mirar por la linea de tiro, no a la bola: se ve a donde va el golpe
		var dir := Vector3(sin(mira), 0, cos(mira))
		_camara.look_at(_bola.global_position + dir * 40.0 + Vector3.UP * 3.0)
	else:
		_camara.look_at(_bola.global_position)
