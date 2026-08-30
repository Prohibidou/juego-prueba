extends Node3D
## Apuntado, potencia, mando y camara. No conoce las reglas: cuando el jugador
## suelta, emite la velocidad de salida; el stick izquierdo lo lee juego.gd.
##
## El mando es de tanque, no de camara libre: A/D (o el eje X del stick
## izquierdo) SOLO giran la mira, W/S (o el eje Y) SOLO empujan adelante o
## atras en esa direccion. Como la mira es tambien el rumbo que sigue la
## camara, moverse en linea recta nunca cambia el angulo de camara -solo
## girar lo hace- y la direccion de avance no la puede desviar una pendiente.

signal impulsado(velocidad: Vector3)

# --- calibracion de la fuerza ---
@export_group("Fuerza")
@export_range(0.5, 15.0, 0.1) var VEL_MIN := 3.0        # un saltito
# El techo del impulso. Esto es un juego de PLATAFORMAS: el salto largo tiene
# que cruzar un hueco entre plataformas, no el mapa entero. A 26 m/s el
# alcance eran ~45 m y con un solo impulso a tope se pasaban todas de largo;
# el alcance va con el CUADRADO de la velocidad, asi que bajar a 14 lo deja
# en ~14 m. Son saltos, no atajos.
@export_range(5.0, 60.0, 0.5) var VEL_MAX := 14.0
@export_range(0.1, 3.0, 0.05) var CARGA_POR_SEG := 0.5  # 2 s de barra entera: antes era 0.9 s y todo salia a tope
# La distancia va con el CUADRADO de la velocidad, asi que una barra lineal se
# siente "todo o nada". Con CURVA<1 la barra se lee casi como distancia: con
# VEL_MIN 3 y VEL_MAX 14 la barra a 1/4, 1/2, 3/4 y llena cae a 3, 6, 10 y 14
# metros, que es el escalonado que hace falta para elegir plataforma.
@export_range(0.3, 2.0, 0.05) var CURVA := 0.75
# Angulo de salida fijo: era un control (flechas, stick derecho y deslizador)
# que se comia el arriba/abajo, y lo que se quiere ahi es mover al bicho.
@export_range(0.0, 70.0, 1.0) var LOFT := 22.0
# Cuanto mas cargas, mas lejos llega y menos control tienes. Sin esto la barra
# no era una decision: siempre convenia el maximo. Va con el CUADRADO de la
# fuerza, asi que medio impulso es casi exacto y el impulso entero es una apuesta.
@export_range(0.0, 0.3, 0.005) var DISPERSA := 0.055     # rad de error a barra llena
# --------------------------------

# --- direccion en el aire ---
# Un presupuesto corto por impulso: corrige una salida torcida, no dibuja la
# trayectoria entera. Lo gasta juego.gd, que es quien ve si el piche vuela.
@export_group("Timon")
@export_range(0.0, 0.2, 0.005) var TIMON_TACTIL := 0.03  # cuanto desvia un pixel de arrastre
@export_range(0.0, 10.0, 0.1) var TIMON_VUELVE := 2.0   # el arrastre se suelta solo al soltar el dedo
# ----------------------------

# --- camara ---
# Pegada al piche: es un bicho pequeno y de lejos se
# perdia de vista aunque _escalar_vista lo agrande en pantalla.
@export_group("Camara")
@export_range(0.0, 5.0, 0.05) var CAM_ALTO := 0.55         # fija: la misma altura siempre, quieta o en marcha
@export_range(0.2, 10.0, 0.1) var CAM_ATRAS_TIRO := 1.1
# Dentro de la jaula esa camara cae entre los barrotes y no se ve nada: se sale
# fuera para que se vea la jaula entera y por donde esta la puerta.
@export_range(0.0, 10.0, 0.1) var CAM_ALTO_JAULA := 2.4
@export_range(0.5, 20.0, 0.1) var CAM_ATRAS_JAULA := 4.6
# La camara se aleja con la velocidad: encuadra igual un saltito que un
# impulso fuerte, y el ensanchado del fov da la sensacion de velocidad.
@export_range(0.2, 10.0, 0.1) var CAM_ATRAS_MIN := 1.2
@export_range(0.2, 20.0, 0.1) var CAM_ATRAS_MAX := 3.2
@export_range(30.0, 110.0, 1.0) var CAM_FOV := 62.0
@export_range(30.0, 120.0, 1.0) var CAM_FOV_MAX := 74.0
@export_range(1.0, 60.0, 0.5) var CAM_VEL_REF := 13.0      # m/s a los que la camara esta del todo abierta: va con VEL_MAX
@export_range(0.0, 3.0, 0.05) var CAM_UMBRAL_QUIETO := 0.3 # m/s: por debajo, "quieto" para la camara (igual que QUIETA en juego.gd)
# Rumbo con tope de giro: un tiron del stick puede cambiar la velocidad del
# piche de golpe (90 grados o mas), pero la camara y la mira no saltan con
# el, viran a este ritmo maximo. Sin esto, un cambio brusco de direccion
# se notaba como un salto de camara en vez de un giro.
@export_range(0.5, 12.0, 0.1) var CAM_GIRO_MAX := 3.5      # rad/s
@export_range(1.0, 40.0, 0.5) var CAM_SUAVIZADO := 14.0
@export_range(0.5, 20.0, 0.5) var CAM_FOV_SUAVIZADO := 4.0 # el fov va mas lento que la posicion: asi se nota
# Con el muelle de por medio (galpones, el barco, la jaula) la camara detras
# del piche se metia dentro de la primera pared que encontraba. Un rayo desde
# el piche hasta el punto ideal la trae para adelante hasta justo antes de esa
# pared, en vez de dejarla atravesarla.
@export_range(0.0, 2.0, 0.05) var CAM_COLISION_MARGEN := 0.25  # cuanto se aparta de la pared, para no clavar el lente
# --------------

# --- mando ---
# De tanque: A/D (izquierdo, eje X) giran; W/S (izquierdo, eje Y) avanzan. El
# stick derecho tambien gira la mira, para apuntar sin moverse. El impulso es
# G (o la A del mando); el salto va aparte, en juego.gd, con el espacio. No se
# usa "ui_accept" porque lleva dentro el espacio, que ahora es saltar.
@export_group("Mando")
@export_range(0.0, 0.9, 0.01) var ZONA_MUERTA := 0.2
@export_range(0.2, 8.0, 0.1) var APUNTA_GIRO := 1.6       # rad/s de mira con el stick derecho al tope
@export_range(0.2, 8.0, 0.1) var GIRO_ANDAR := 2.2        # rad/s de mira con A/D o el stick izquierdo
# -------------

@export_group("Mira")
@export_range(5.0, 200.0, 1.0) var LARGO_MIRA := 60.0    # metros de linea de apuntado
@export_range(4, 120, 1) var PASOS_MIRA := 30

var mira := 0.0
var fuerza := 0.0
var activo := false
var viento := Vector3.ZERO
var tope := 1.0              # cuanta barra deja cargar la stamina; lo pone juego.gd
var enjaulado := false       # la camara se aparta para que se vea la jaula
var cine := false            # plano de cine: manda sobre todo lo demas
var cine_offset := Vector3.ZERO   # desde donde se mira, RELATIVO a el piche
var puede_saltar := true     # sin stamina no hay impulso; lo pone juego.gd
var timon := 0.0             # -1..1 para dirigir en el aire; lo lee juego.gd
var suelo: Callable          # (x, z) -> altura del terreno

var mapa: Mapa   # la lista "excluir" del rayo de camara y el impulso_alcance del mapa; lo pone juego.gd

var _piche: RigidBody3D
var _camara: Camera3D
var _linea: MeshInstance3D
var _cargando := false
var _dir_camara := Vector3.FORWARD
var _mirada := Vector3.ZERO   # punto al que mira la camara, suavizado igual que la posicion
var _timon_tactil := 0.0


func preparar(piche: RigidBody3D, camara: Camera3D) -> void:
	_piche = piche
	_camara = camara

	_linea = MeshInstance3D.new()
	_linea.mesh = ImmediateMesh.new()
	var m := Util.mat(Color(1, 0.95, 0.3, 0.9))
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_linea.material_override = m
	_linea.top_level = true
	add_child(_linea)


## Al llegar a un nivel se apunta a la meta, que es lo que haria cualquiera.
func reset(salida: Vector3, meta: Vector3) -> void:
	var d := meta - salida
	mira = atan2(d.x, d.z)
	fuerza = 0.0
	_cargando = false


## Toda la escala (de VEL_MIN a VEL_MAX) se escala por mapa.impulso_alcance:
## un impulso minimo tambien llega mas lejos en el cerro, no solo el de barra
## llena. Sin mapa (self-check temprano) queda en 1.0, sin cambios.
func velocidad() -> float:
	var base := lerpf(VEL_MIN, VEL_MAX, pow(fuerza, CURVA))
	return base * (mapa.impulso_alcance if mapa else 1.0)


func cargar() -> void:
	if activo and not _cargando and puede_saltar:
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
	impulsado.emit(_dir(mira + randf_range(-e, e),
		LOFT + rad_to_deg(randf_range(-e, e))) * v)
	fuerza = 0.0


## La carga se lee sondeando la tecla G, no por eventos: si se va el foco con
## la barra a medias, el soltar pasa fuera de la ventana y nunca se ve, asi que
## la carga se quedaba colgada subiendo. Se CANCELA, no se suelta: disparar un
## impulso porque el jugador se cambio de ventana es peor que perder la barra.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _cargando:
		_cargando = false
		fuerza = 0.0


func _unhandled_input(e: InputEvent) -> void:
	# apuntar arrastrando: en movil funciona igual, con el raton emulado
	if not (e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		return
	if activo:
		mira -= e.relative.x * 0.004
	else:
		# el mismo gesto: con el piche en el aire el arrastre es el timon
		_timon_tactil = clampf(_timon_tactil + e.relative.x * TIMON_TACTIL, -1.0, 1.0)


func _process(dt: float) -> void:
	if _piche == null:
		return

	var pulsa := Input.is_key_pressed(KEY_G) or Input.is_joy_button_pressed(0, JOY_BUTTON_A)
	if activo and pulsa and not _cargando:
		cargar()
	if _cargando:
		fuerza = minf(tope, fuerza + dt * CARGA_POR_SEG)
		if not pulsa:
			soltar()
	elif activo:
		# de tanque: A/D (o el stick izquierdo, eje X) SOLO giran la mira,
		# nunca desplazan -eso es cosa de W/S en mando()-. El stick derecho
		# y las flechas tambien giran, para poder apuntar sin caminar.
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A): mira += dt * GIRO_ANDAR
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D): mira -= dt * GIRO_ANDAR
		mira -= _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y).x * dt * GIRO_ANDAR
		mira -= _stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y).x * dt * APUNTA_GIRO

	_timon_tactil = move_toward(_timon_tactil, 0.0, dt * TIMON_VUELVE)
	timon = 0.0 if activo else clampf(
		Input.get_axis("ui_left", "ui_right") + _timon_tactil, -1.0, 1.0)

	_mover_camara(dt)
	_dibujar_mira()


## Stick con zona muerta. ponytail: mando 0, el primero que haya conectado;
## si hiciera falta multijugador local, aqui entraria el id del dispositivo.
func _stick(eje_x: int, eje_y: int) -> Vector2:
	var v := Vector2(Input.get_joy_axis(0, eje_x), Input.get_joy_axis(0, eje_y))
	return Vector2.ZERO if v.length() < ZONA_MUERTA else v.limit_length(1.0)


## Cuanto empuja adelante (o atras) el bicho: SOLO W/S, o el eje Y del stick
## izquierdo. Girar es cosa de A/D en _process(), no de aca: mando() nunca
## desplaza de costado, para que la mira sea el UNICO rumbo -si una pendiente
## empuja de lado, juego.gd lo corrige, no hace falta que este vector lo haga.
func mando() -> Vector3:
	var v := _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	var empuje := -v.y
	if v == Vector2.ZERO:
		empuje = float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	empuje = clampf(empuje, -1.0, 1.0)
	if is_zero_approx(empuje):
		return Vector3.ZERO
	return Vector3(sin(mira), 0, cos(mira)) * empuje


func direccion() -> Vector3:
	return _dir(mira, LOFT)


func _dir(m: float, l: float) -> Vector3:
	var a := deg_to_rad(l)
	return Vector3(sin(m) * cos(a), sin(a), cos(m) * cos(a)).normalized()


## Radianes de error que puede salir este impulso, para el HUD y para soltar().
func dispersion() -> float:
	return DISPERSA * fuerza * fuerza


## Solo se marca HACIA DONDE se apunta, no donde va a caer: adivinar la caida
## le quita al juego la parte de calcular la fuerza.
func _dibujar_mira() -> void:
	var im: ImmediateMesh = _linea.mesh
	im.clear_surfaces()
	_linea.visible = activo
	if not activo or not suelo.is_valid():
		return
	var dir := Vector3(sin(mira), 0, cos(mira))
	var p := _piche.global_position
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in PASOS_MIRA + 1:
		var q := p + dir * (LARGO_MIRA * i / PASOS_MIRA)
		q.y = suelo.call(q.x, q.z) + 0.08
		im.surface_add_vertex(q)
	im.surface_end()


## Gira `actual` hacia `objetivo` (vectores planos, XZ) como mucho `max_rad`
## radianes por este paso. Es lo que evita que un cambio de rumbo brusco -al
## aterrizar de un impulso fuerte- salte de un frame a otro.
func _girar_hacia(actual: Vector3, objetivo: Vector3, max_rad: float) -> Vector3:
	if max_rad <= 0.0:
		return actual
	var a0 := atan2(actual.x, actual.z)
	var a1 := atan2(objetivo.x, objetivo.z)
	var a := a0 + clampf(wrapf(a1 - a0, -PI, PI), -max_rad, max_rad)
	return Vector3(sin(a), 0, cos(a))


## El punto pegado al piche desde el que se tiran los rayos anti-pared: el
## "ojo". Es UNO solo para el objetivo y para la posicion real de la camara;
## si cada uno midiera desde un origen distinto, sus clamps no verian la misma
## pared. Publica: el self-check de juego.gd mide desde aqui si la camara
## quedo tapada.
func origen_camara() -> Vector3:
	if cine:
		return _piche.global_position
	var alto := CAM_ALTO_JAULA if (activo and enjaulado) else CAM_ALTO
	return _piche.global_position + Vector3.UP * alto


## "activo" (juego.gd) esta puesto tanto apuntando quieto como llevando el
## piche a mano con A/D/W/S: en los dos casos el rumbo lo decide el jugador
## via mira, asi que la camara sigue la mira siempre igual, sin mirar la
## velocidad -moverse en linea recta nunca le cambia el angulo-. Solo cuando
## el piche vuela o rueda solo tras un impulso (activo=false, el jugador no
## esta manejando la caida) la camara persigue el rumbo real de el piche.
func objetivo_camara(dt := 0.0) -> Vector3:
	if cine:
		# de costado y pegado a el piche. Fijo en el suelo no vale: a 26 m/s el
		# piche se iba de cuadro en un pestaneo aunque el tiempo vaya al 25%.
		# Y como el suavizado va con delta, en camara lenta la camara se queda
		# atras a proposito: la jaula y la puerta se alejan en el encuadre.
		# El desvio es fijo, asi que en el muelle caia dentro del casco o de un
		# galpon y el plano entero (2.4 s) se veia desde dentro de una pared:
		# pasa por el mismo rayo que las demas ramas.
		return _sin_pared(origen_camara(), _piche.global_position + cine_offset)
	if activo:
		var atras := CAM_ATRAS_JAULA if enjaulado else CAM_ATRAS_TIRO
		var desde := origen_camara()
		return _sin_pared(desde, desde - Vector3(sin(mira), 0, cos(mira)) * atras)
	var plana := Vector3(_piche.linear_velocity.x, 0, _piche.linear_velocity.z)
	if plana.length() > CAM_UMBRAL_QUIETO:
		_dir_camara = _girar_hacia(_dir_camara, plana.normalized(), CAM_GIRO_MAX * dt)
	var t := _factor_velocidad()
	var desde := origen_camara()
	return _sin_pared(desde, desde - _dir_camara * lerpf(CAM_ATRAS_MIN, CAM_ATRAS_MAX, t))


## Trae la camara para adelante si entre "desde" (pegado al piche) y el punto
## ideal hay una pared de por medio: sin esto, en el muelle la camara se metia
## dentro de galpones y del casco del barco en vez de rebotar antes de tocarlos.
func _sin_pared(desde: Vector3, objetivo: Vector3) -> Vector3:
	var esp := get_world_3d().direct_space_state
	if esp == null or desde == objetivo:
		return objetivo
	var q := PhysicsRayQueryParameters3D.create(desde, objetivo)
	# la misma lista que usa mapa.altura_terreno() para no pisar el piche ni
	# las paredes de la jaula: sin esto, encuadrar desde fuera de la jaula
	# chocaba con sus propios barrotes y la camara se quedaba pegada a ellos.
	q.exclude = mapa.excluir if mapa else [_piche.get_rid()]
	var choque := esp.intersect_ray(q)
	if not choque:
		return objetivo
	return choque["position"] + choque["normal"] * CAM_COLISION_MARGEN


## 0 con el piche parada, 1 a CAM_VEL_REF. Manda el encuadre y el fov.
func _factor_velocidad() -> float:
	return clampf(_piche.linear_velocity.length() / CAM_VEL_REF, 0.0, 1.0)


## Paso de suavizado independiente de los fps: con dt * k la camara va mas
## brusca a 30 fps que a 144 y el seguimiento se siente a tirones.
func _paso(k: float, dt: float) -> float:
	return 1.0 - exp(-k * dt)


## Adelanta la mirada por la linea de tiro mientras el rumbo lo decide el
## jugador (activo), pero poco: con la camara pegada, mirar a 40 m dejaba al
## piche fuera de cuadro. Volando o rodando sola tras un impulso, se mira a
## ella misma.
func _mirada_deseada() -> Vector3:
	if cine:
		return _piche.global_position
	if activo:
		var dir := Vector3(sin(mira), 0, cos(mira))
		# enjaulado se mira mas cerca: adelantar 5 m saca la jaula de cuadro
		var lejos := 1.5 if enjaulado else 5.0
		return _piche.global_position + dir * lejos + Vector3.UP * 0.5
	return _piche.global_position


## Corta a un plano que acompana a el piche. Corta, no viaja: el suavizado
## normal va con delta, y en camara lenta tardaria una eternidad en llegar.
func cortar_a(desvio: Vector3) -> void:
	cine = true
	cine_offset = desvio
	# el corte tambien se mira: si no, el plano ARRANCA ya metido en la pared y
	# el rayo de objetivo_camara() solo lo arreglaria a partir del frame siguiente
	_camara.global_position = _sin_pared(_piche.global_position, _piche.global_position + desvio)
	_mirada = _piche.global_position
	_camara.look_at(_mirada)


## Se acaba el plano: la camara vuelve sola a su sitio con el suavizado de
## siempre, que a velocidad normal es un tercio de segundo.
func fin_cine() -> void:
	cine = false


func encuadrar() -> void:
	_dir_camara = Vector3(sin(mira), 0, cos(mira))
	_camara.fov = CAM_FOV
	_camara.global_position = objetivo_camara()
	_mirada = _mirada_deseada()
	_camara.look_at(_mirada)


func _mover_camara(dt: float) -> void:
	# Posicion y mirada se suavizan con el MISMO paso, para que nunca se
	# desincronicen: antes la mirada se recalculaba al instante y la posicion
	# iba a la zaga (se notaba que no giraban igual), o la posicion saltaba
	# entera al pasar a "quieto" (se notaba como un reset de camara). Asi
	# ninguna de las dos pega saltos, sea cual sea el motivo del cambio.
	var paso := _paso(CAM_SUAVIZADO, dt)
	_camara.global_position = _camara.global_position.lerp(objetivo_camara(dt), paso)
	_mirada = _mirada.lerp(_mirada_deseada(), paso)
	# El rayo de objetivo_camara() solo protege el OBJETIVO: cuando una pared
	# se mete de golpe entre el piche y la camara (doblar una esquina, un drop,
	# un corte de cine), el objetivo salta al punto seguro pero la camara tarda
	# ~1/CAM_SUAVIZADO s en llegar, y ese camino lo hacia POR DENTRO de la
	# pared -medido: rachas de 8 a 16 frames, hasta 5.5 m de hondo-. Se vuelve
	# a clavar la posicion REAL: entrar al punto seguro es instantaneo, salir
	# sigue suave porque el lerp de arriba no se toca.
	_camara.global_position = _sin_pared(origen_camara(), _camara.global_position)
	_camara.look_at(_mirada)
	# en cine el fov se queda quieto: el plano es una composicion fija, y como
	# el guion sube el piche de 2.6 a 22 m/s, el ensanchado por velocidad metia
	# un zoom de 62 a 73 grados en mitad del portazo.
	var fov := CAM_FOV if (cine or activo) else lerpf(CAM_FOV, CAM_FOV_MAX, _factor_velocidad())
	_camara.fov = lerpf(_camara.fov, fov, _paso(CAM_FOV_SUAVIZADO, dt))

