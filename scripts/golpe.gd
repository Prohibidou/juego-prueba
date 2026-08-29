extends Node3D
## Apuntado, potencia, mando y camara. No conoce las reglas: cuando el jugador
## suelta, emite la velocidad de salida; el stick izquierdo lo lee juego.gd.

signal golpeado(velocidad: Vector3)

# --- calibracion de la fuerza ---
const VEL_MIN := 4.0        # un putt corto
const VEL_MAX := 68.0       # un drive completo
const CARGA_POR_SEG := 0.5  # 2 s de barra entera: antes era 0.9 s y todo salia a tope
# La distancia va con el CUADRADO de la velocidad, asi que una barra lineal se
# siente "todo o nada". Con CURVA<1 la barra se lee casi como distancia.
const CURVA := 0.75
# Angulo de salida fijo: era un control (flechas, stick derecho y deslizador)
# que se comia el arriba/abajo, y lo que se quiere ahi es mover al bicho.
const LOFT := 22.0
# Cuanto mas cargas, mas lejos llega y menos control tienes. Sin esto la barra
# no era una decision: siempre convenia el maximo. Va con el CUADRADO de la
# fuerza, asi que medio golpe es casi exacto y el drive completo es una apuesta.
const DISPERSA := 0.055     # rad de error a barra llena y desde la calle
# --------------------------------

# --- direccion en el aire ---
# Un presupuesto corto por golpe: corrige una salida torcida, no dibuja la
# trayectoria entera. Lo gasta juego.gd, que es quien ve si la bola vuela.
const TIMON_TACTIL := 0.03  # cuanto desvia un pixel de arrastre
const TIMON_VUELVE := 2.0   # el arrastre se suelta solo al soltar el dedo
# ----------------------------

# --- camara ---
const CAM_ALTO_TIRO := 0.85
const CAM_ATRAS_TIRO := 1.8
# La camara se aleja y abre el angulo con la velocidad: encuadra igual un putt
# que un drive, y el ensanchado del fov da la sensacion de velocidad.
const CAM_ATRAS_MIN := 2.0
const CAM_ATRAS_MAX := 5.5
const CAM_ALTO_MIN := 0.7
const CAM_ALTO_MAX := 2.0
const CAM_FOV := 62.0
const CAM_FOV_MAX := 74.0
const CAM_VEL_REF := 55.0      # m/s a los que la camara esta del todo abierta
const CAM_SUAVIZADO := 14.0
const CAM_FOV_SUAVIZADO := 4.0 # el fov va mas lento que la posicion: asi se nota
# --------------

# --- mando ---
# Stick izquierdo: rueda el piche. Stick derecho: apunta. El boton de golpe ya
# funciona solo, porque "ui_accept" incluye la A del mando por defecto.
const ZONA_MUERTA := 0.2
const APUNTA_GIRO := 1.6       # rad/s de mira con el stick derecho al tope
# -------------

const LARGO_MIRA := 60.0    # metros de linea de apuntado
const PASOS_MIRA := 30

var mira := 0.0
var fuerza := 0.0
var activo := false
var viento := Vector3.ZERO
var estabilidad := 1.0       # 1 en calle, menos en rough: alli se controla peor
var timon := 0.0             # -1..1 para dirigir en el aire; lo lee juego.gd
var suelo: Callable          # (x, z) -> altura del terreno

var _bola: RigidBody3D
var _camara: Camera3D
var _linea: MeshInstance3D
var _cargando := false
var _dir_camara := Vector3.FORWARD
var _timon_tactil := 0.0


func preparar(bola: RigidBody3D, camara: Camera3D) -> void:
	_bola = bola
	_camara = camara

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
	fuerza = 0.0
	_cargando = false


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
	# el error se sortea AQUI, no al apuntar: el jugador ve a donde apunto y
	# entiende que se le fue por cargar de mas, no que la mira mienta
	var e := dispersion()
	golpeado.emit(_dir(mira + randf_range(-e, e),
		LOFT + rad_to_deg(randf_range(-e, e))) * v)
	fuerza = 0.0


func _unhandled_input(e: InputEvent) -> void:
	# apuntar arrastrando: en movil funciona igual, con el raton emulado
	if not (e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		return
	if activo:
		mira -= e.relative.x * 0.004
	else:
		# el mismo gesto: con la bola en el aire el arrastre es el timon
		_timon_tactil = clampf(_timon_tactil + e.relative.x * TIMON_TACTIL, -1.0, 1.0)


func _process(dt: float) -> void:
	if _bola == null:
		return

	if activo and Input.is_action_just_pressed("ui_accept"):
		cargar()
	if _cargando:
		fuerza = minf(1.0, fuerza + dt * CARGA_POR_SEG)
		if Input.is_action_just_released("ui_accept"):
			soltar()
	elif activo:
		# teclas crudas y no ui_*: esas acciones llevan dentro el stick
		# izquierdo, que aqui rueda al piche. En mando se apunta con el derecho.
		if Input.is_key_pressed(KEY_LEFT): mira += dt * 1.0
		if Input.is_key_pressed(KEY_RIGHT): mira -= dt * 1.0
		mira -= _stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y).x * dt * APUNTA_GIRO

	_timon_tactil = move_toward(_timon_tactil, 0.0, dt * TIMON_VUELVE)
	timon = 0.0 if activo else clampf(
		Input.get_axis("ui_left", "ui_right") + _timon_tactil, -1.0, 1.0)

	_dibujar_mira()
	_mover_camara(dt)


## Stick con zona muerta. ponytail: mando 0, el primero que haya conectado;
## si hiciera falta multijugador local, aqui entraria el id del dispositivo.
func _stick(eje_x: int, eje_y: int) -> Vector2:
	var v := Vector2(Input.get_joy_axis(0, eje_x), Input.get_joy_axis(0, eje_y))
	return Vector2.ZERO if v.length() < ZONA_MUERTA else v.limit_length(1.0)


## Hacia donde se empuja al bicho: stick izquierdo o WASD, lo que se toque.
## Girado a la camara y aplanado. El largo del vector es cuanto se inclina.
func mando() -> Vector3:
	var v := _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	if v == Vector2.ZERO:
		v = Vector2(
			float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
			float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
		).limit_length(1.0)
	if v == Vector2.ZERO:
		return Vector3.ZERO
	var b := _camara.global_basis
	var frente := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	var lado := Vector3(b.x.x, 0.0, b.x.z).normalized()
	return (lado * v.x - frente * v.y).limit_length(1.0)


func direccion() -> Vector3:
	return _dir(mira, LOFT)


func _dir(m: float, l: float) -> Vector3:
	var a := deg_to_rad(l)
	return Vector3(sin(m) * cos(a), sin(a), cos(m) * cos(a)).normalized()


## Radianes de error que puede salir este golpe, para el HUD y para soltar().
func dispersion() -> float:
	return DISPERSA * fuerza * fuerza / maxf(estabilidad, 0.1)


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


## Paso de suavizado independiente de los fps: con dt * k la camara va mas
## brusca a 30 fps que a 144 y el seguimiento se siente a tirones.
func _paso(k: float, dt: float) -> float:
	return 1.0 - exp(-k * dt)


func encuadrar() -> void:
	_dir_camara = Vector3(sin(mira), 0, cos(mira))
	_camara.fov = CAM_FOV
	_camara.global_position = objetivo_camara()


func _mover_camara(dt: float) -> void:
	var suave := CAM_SUAVIZADO if not activo else 5.0
	_camara.global_position = _camara.global_position.lerp(objetivo_camara(), _paso(suave, dt))
	var fov := CAM_FOV if activo else lerpf(CAM_FOV, CAM_FOV_MAX, _factor_velocidad())
	_camara.fov = lerpf(_camara.fov, fov, _paso(CAM_FOV_SUAVIZADO, dt))
	if activo:
		# adelantar la mirada por la linea de tiro, pero poco: con la camara
		# pegada, mirar a 40 m dejaba al piche fuera de cuadro
		var dir := Vector3(sin(mira), 0, cos(mira))
		_camara.look_at(_bola.global_position + dir * 5.0 + Vector3.UP * 0.5)
	else:
		_camara.look_at(_bola.global_position)
