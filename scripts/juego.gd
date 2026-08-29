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
# --- stamina ---
# Se anda libre, sin radio: lo unico que cuesta stamina es el impulso (G). La
# basura del campo la repone: es lo que obliga a desviarse de la linea recta
# al hoyo.
const STAMINA_MAX := 100.0
const STAMINA_BASURA := 20.0
const STAMINA_IMPULSO := 60.0 # lo que cuesta el impulso (G) a barra llena
const IMPULSO_SALTO := 5.5    # m/s hacia arriba, sin tocar lo que ya lleve
# Por debajo de esto no hay impulso: ni barra, ni golpe minimo. Es el mismo
# numero que pinta de rojo la barra, para que lo que se ve y lo que se puede
# hacer sean la misma regla.
const STAMINA_MIN := STAMINA_IMPULSO * 0.2
const R_RECOGE := 1.2
# --- puntos (SBG puntua, no cuenta golpes) ---
const PUNTOS_HOYO := 100
const PUNTOS_GOLPE := 25    # lo que vale cada golpe ahorrado sobre el par
# A escala real la bola son 4 cm: a 20 m ya no se ve. Se dibuja agrandada de
# modo que ocupe SIEMPRE la misma fraccion de la pantalla, calculada con el fov
# y la distancia reales de la camara. La colision sigue siendo la esfera de 4 cm.
# La jaula arranca cerrada en el tee y la puerta se cae al primer impulso. En
# el modelo la puerta esta en la cara +X del nodo raiz, asi que la jaula se
# gira para que esa cara mire a la bandera y el piche salga hacia el hoyo.
# Cuerpo y puerta vienen en dos glb, en las MISMAS coordenadas: la puerta cae
# en x 0.83..0.95 y el cuerpo va de -1 a 1, asi que encajan colgando los dos
# del mismo nodo sin tocar nada. Eso deja trabajar en ejes locales de la jaula
# y ahorra ir y volver de mundo para cada caja.
const JAULA := "res://escenas/Jaula.tscn"
# La portada tapa la pantalla desde el primer fotograma: montar el mapa y su
# colision lleva segundos y hasta ahora se veia el vacio mientras carga.
const PORTADA := "res://ui/portada.png"
const CARGA_MIN := 5.0        # segundos minimos, aunque cargue antes
# El portazo tiene dos tiempos: el piche la EMPUJA y ella cede, y despues se
# suelta y termina de caer sola. Para que se vea empujada hay que frenar
# tambien al piche: a 22 m/s la puerta tendria que girar a 129 rad/s para
# seguirle el ritmo, y eso no es empujar, es desaparecer. Asi que en el
# impacto el piche baja a una fracción de su velocidad, avanza pegado a la
# puerta mientras ella gira, y al soltarse recupera todo de golpe.
const PORTAZO_EMPUJE := 0.30  # segundos DE JUEGO empujando
const PORTAZO_SUELTA := 0.18  # y cayendo sola
const PORTAZO_LENTO := 0.12   # a cuanto baja la velocidad del piche al pegar
# El portazo es el momento de la partida: se ve en camara lenta, desde fuera y
# de costado, con la puerta volando hacia el objetivo y el piche cruzando el
# hueco. No es una escena aparte -habria que duplicar jaula, piche y campo-,
# es este mismo juego a un cuarto de velocidad y con la camara cortada.
const CINE_LENTO := 0.18      # a cuanto baja el tiempo
# los dos tiempos del portazo son 0.48 s de juego: al 18% son 2.7 reales, asi
# que la camara lenta se corta justo cuando el piche recupera y sale disparado
const CINE_DURA := 2.4        # segundos REALES, no de juego
const CINE_LADO := 3.6        # cuanto se aparta la camara del eje de salida
const CINE_FRENTE := 2.2      # y cuanto se queda por detras, para ver la jaula
const CINE_ALTO := 1.4
# Al reventar la puerta la bola pierde algo, pero SIGUE hacia fuera: cuando
# llega el aviso de contacto el rebote ya esta calculado, asi que hay que
# devolverle el rumbo o se queda dentro por mucho que se abra el hueco.
const PORTAZO_FRENA := 0.85
const VISTA_PANTALLA := 0.14    # subelo y el piche se ve mas grande
# ...pero con un tope en metros. El tamano constante en pantalla se invento
# cuando la camara se iba a 14 m; ahora que no pasa de 5.5, y que hay una jaula
# de 2 m al lado para comparar, sin tope el piche salia hecho un monstruo al
# arrancar y encogia en cuanto la camara se acercaba.
const VISTA_MAX := 0.34         # metros de ancho como mucho
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
var _jaula: Node3D            # escenas/Jaula.tscn
@onready var _portada: CanvasLayer = $Portada
var _t_arranque := 0
var _empujando := false       # el piche esta abriendo la puerta a empujones
var _portazo := 1.0           # que fraccion de su velocidad lleva mientras
var _vel_portazo := Vector3.ZERO   # el disparo entero, congelado en el impacto
var _pulso_salto := false     # para detectar el flanco del espacio
var _saltando := false        # brinco en curso: sin soltar el mando
var _vel_andar := 0.0         # velocidad de _conducir(): solo sube con mando, nunca con el terreno
var _angulo_rueda := 0.0                 # cuanto lleva rodado
var _eje_rueda := Vector3.RIGHT          # el eje del disco: su cara plana
var _dir_rueda := Vector3.FORWARD
var _mira_rueda := 0.0                   # ultima mira vista, para girar en el sitio con A/D
var _aire := 0.0          # timon que le queda a este golpe
var _marcas: Array = []

@onready var campo: Campo = $Campo
@onready var bola: RigidBody3D = $Piche
@onready var vista: Node3D = $Piche/Vista
@onready var estela: CPUParticles3D = $Piche/Estela
@onready var camara: Camera3D = $Camara
@onready var golpe: Node3D = $Golpe
@onready var entorno: WorldEnvironment = $Entorno
@onready var hud: Label = $UI/Hud
@onready var msg: Label = $UI/Msg
@onready var barra: ProgressBar = $UI/Barra
@onready var barra_stam: ProgressBar = $UI/BarraStam


func _ready() -> void:
	randomize()
	_t_arranque = Time.get_ticks_msec()
	_preparar_bola()
	_conectar_tactil()
	barra_stam.max_value = STAMINA_MAX   # el .tscn no puede leer la constante

	golpe.preparar(bola, camara)
	golpe.golpeado.connect(_on_golpeado)

	campo.excluir = [bola.get_rid()]
	golpe.campo = campo   # para que el rayo de colision de la camara no pise la jaula
	msg.text = "Cargando el campo..."
	await campo.preparar()
	msg.text = ""

	golpe.suelo = Callable(campo, "altura_terreno")
	_ir_a_hoyo(0)
	listo = true
	await _self_check()
	await _quitar_portada()


## Se va cuando el mapa esta listo Y han pasado CARGA_MIN segundos: si la
## maquina carga rapido, la portada igual se ve el rato que tiene que verse.
func _quitar_portada() -> void:
	var lleva := (Time.get_ticks_msec() - _t_arranque) / 1000.0
	if lleva < CARGA_MIN:
		await get_tree().create_timer(CARGA_MIN - lleva).timeout
	var t := create_tween()
	t.tween_property($Portada/Imagen, "modulate:a", 0.0, 0.5)
	t.tween_callback(_portada.queue_free)


## El piche esta en Piche.tscn. Aca queda solo lo que un .tscn no guarda: el
## .fbx trae animaciones sueltas de Blender (una camara y unas cajas) que, si
## alguna arrancara, moverian el modelo -y no se pueden borrar de una instancia
## desde el editor-; y la escala de la vista, que se mide sobre el modelo ya
## montado.
func _preparar_bola() -> void:
	var reproductor := vista.get_node_or_null("AnimationPlayer")
	if reproductor:
		reproductor.free()
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
	elif dt > 0.0 and golpe.activo:
		# quieto o girando en el sitio: A/D solo cambia la mira (golpe.gd), no
		# empuja, asi que aqui no hay avance del que sacar rumbo. Sin esto el
		# piche se quedaba mirando para el ultimo lado que rodo, y A/D no se
		# notaba en el modelo, solo en la camara. Se sigue la mira y se gira
		# sobre el propio eje lo mismo que giro ella, como si pivotara.
		# Solo con activo=true (el jugador manda): si no, un golpe real que
		# frena por debajo de 0.05 antes de quedar "quieto" haria que el
		# piche pegara un giro brusco hacia la mira vieja del ultimo apunte.
		var d_mira := wrapf(golpe.mira - _mira_rueda, -PI, PI)
		_mira_rueda = golpe.mira
		_dir_rueda = Vector3(sin(golpe.mira), 0, cos(golpe.mira))
		_eje_rueda = Vector3.UP.cross(_dir_rueda)
		_angulo_rueda += absf(d_mira)
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
	var e := clampf(VISTA_PANTALLA * alto, Util.RADIO * 2.0, VISTA_MAX) / _diam_bola
	var base := _rodar(e, dt).scaled(Vector3.ONE * e)
	var caja := Transform3D(base, Vector3.ZERO) * _caja_bola
	vista.global_transform = Transform3D(base, bola.global_position - Vector3(
		caja.get_center().x, caja.position.y + Util.RADIO, caja.get_center().z))


## Planta la jaula en el tee, con la puerta mirando a la bandera y la bola ya
## dentro. Los cuerpos de la jaula se sacan de los rayos de altura: si no, el
## rayo del tee daria en su techo y todo se colocaria dos metros mas arriba.
func _montar_jaula() -> void:
	if is_instance_valid(_jaula):
		_jaula.queue_free()   # la bisagra y la puerta cuelgan de ella
	Engine.time_scale = 1.0     # por si se cambia de hoyo en pleno portazo
	golpe.fin_cine()
	_jaula = (load(JAULA) as PackedScene).instantiate()
	add_child(_jaula)
	var t := campo.pos_tee()
	var b := campo.pos_bandera()
	_jaula.global_position = Vector3(t.x, campo.altura_terreno(t.x, t.z), t.z)
	# la cara de la puerta es el +X del modelo: se gira para que apunte al hoyo
	_jaula.rotation.y = atan2(-(b.z - t.z), b.x - t.x)

	_jaula.vigilar(bola)
	_jaula.reventada.connect(_reventar_puerta)
	# sus cuerpos fuera de los rayos de altura: si no, el rayo del tee da en el
	# techo de la jaula y la bola se coloca dos metros mas arriba
	campo.excluir = [bola.get_rid()]
	campo.excluir.append_array(_jaula.cuerpos())


## Los nodos estan en Juego.tscn; aca solo queda lo que un .tscn no guarda:
## a quien avisan los botones y si se ven (solo en pantalla tactil).
func _conectar_tactil() -> void:
	var tactil := DisplayServer.is_touchscreen_available()
	$UI/Pegar.visible = tactil
	$UI/Drop.visible = tactil
	if not tactil:
		return
	$UI/Pegar.button_down.connect(func(): golpe.cargar())
	$UI/Pegar.button_up.connect(func(): golpe.soltar())
	$UI/Drop.pressed.connect(_drop)


func _ir_a_hoyo(i: int) -> void:
	_marcas.clear()
	campo.ir_a(i)
	golpe.reset(campo.pos_tee(), campo.pos_bandera())
	golpe.viento = campo.viento()
	stamina = STAMINA_MAX
	_poner_bola(campo.pos_tee())
	_montar_jaula()    # despues de colocar la bola: la deja dentro
	golpe.encuadrar()


func _poner_bola(donde: Vector3) -> void:
	bola.freeze = true
	bola.linear_velocity = Vector3.ZERO
	bola.angular_velocity = Vector3.ZERO
	bola.global_position = Vector3(donde.x,
		campo.altura_terreno(donde.x, donde.z) + Util.RADIO, donde.z)
	bola.angular_damp = 0.6
	quieto = true
	_saltando = false
	_vel_andar = 0.0
	_en_aire = false
	_giro = 0.0
	estela.emitting = false
	_t_lento = 0.0
	_t_caida = 0.0
	_empujando = false
	_portazo = 1.0
	_mira_rueda = golpe.mira  # que no arranque girando por la diferencia con la mira anterior
	_aplicar_damp()


func _aplicar_damp() -> void:
	var p := bola.global_position
	bola.linear_damp = campo.damp_suelo() * campo.factor_damp(campo.zona(p.x, p.z))


func _drop() -> void:
	if not (quieto and not embocada and listo):
		return
	# El drop recoloca la bola hasta 2.8 m a dedo, sin mirar paredes: dentro de
	# la jaula eso la teletransporta al otro lado de los muros y se salta el
	# portazo entero por un golpe de pena. Y en pleno cine, ademas, resetearia
	# _empujando/_portazo a mitad del guion.
	if _enjaulado() or golpe.cine:
		return
	golpes += PENA_DROP
	_poner_bola(bola.global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))
	_aviso("Drop  +%d" % PENA_DROP, 1.0)


func _on_golpeado(velocidad: Vector3) -> void:
	golpes += 1
	# fuerza sigue puesta: golpe.gd la borra despues de emitir
	stamina = maxf(0.0, stamina - STAMINA_IMPULSO * golpe.fuerza)
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
	golpe.tope = clampf(stamina / STAMINA_IMPULSO, 0.0, 1.0)
	golpe.puede_saltar = stamina >= STAMINA_MIN
	golpe.enjaulado = _en_la_jaula()

	var cogidas := campo.recoger(bola.global_position, R_RECOGE)
	if cogidas > 0:
		stamina = minf(STAMINA_MAX, stamina + cogidas * STAMINA_BASURA)
		_aviso("+%d stamina" % roundi(cogidas * STAMINA_BASURA), 0.8)

	# espacio (o X del mando) salta. Flanco a mano: no hay accion en el mapa.
	var salta := Input.is_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0, JOY_BUTTON_X)
	if salta and not _pulso_salto:
		_saltar()
	_pulso_salto = salta

	var hay := stamina >= STAMINA_MIN
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
		_saltando = false
		bola.apply_central_impulse(_v_pendiente * Util.MASA)
		_v_pendiente = Vector3.ZERO
		return

	if quieto:
		_conducir(dt)
		if _saltando:
			_aterrizar()
		# tambien vale meterlo rodando: es la parte de "llevalo tu" de SBG
		if campo.embocada(bola.global_position, bola.linear_velocity):
			_embocar()
		return

	var pos := bola.global_position
	var vel := bola.linear_velocity
	if pos.y < -60.0:
		_poner_bola(_desde)
		return

	if campo.embocada(pos, vel):
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

	# mientras abre la puerta la velocidad la pone el guion, no la fisica: es el
	# mismo disparo a camara lenta, asi que al soltarse sigue como si nada
	if _empujando:
		bola.linear_velocity = _vel_portazo * _portazo

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
	# Mientras dura el empujon no se mira si esta quieta: la velocidad la pone el
	# guion y con carga minima el empuje lento (PORTAZO_LENTO) queda justo en
	# QUIETA, asi que la bola se declaraba quieta y se congelaba en pleno cine.
	# Peor todavia: _empujando se quedaba puesto y el siguiente golpe del jugador
	# lo pisaba _vel_portazo viejo. Ya se decidira cuando suelte.
	if not volando and not _empujando:
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
			_vel_andar = 0.0
			_ultimo = Vector2(pos.x - _desde.x, pos.z - _desde.z).length()
			if _enjaulado():
				# por si el impulso no llego a tocarla: siempre la tira, o el
				# jugador se quedaria encerrado gastando golpes
				_jaula.tirar_puerta(PORTAZO_EMPUJE, PORTAZO_SUELTA)
				_jaula.abrir()
			_aviso("%d m" % roundi(_ultimo), 1.6)
	else:
		_t_lento = 0.0
		_t_caida = 0.0


## El stick izquierdo rueda el piche mientras esta parado. En el aire ese mismo
## stick es el timon, asi que no se pisan. CONDUCE_MAX topa la velocidad de
## andar; para cruzar el campo de verdad hay que golpear.
func _conducir(dt: float) -> void:
	var dir: Vector3 = golpe.mando()
	if dir == Vector3.ZERO:
		# sin mando no se mueve nada. Si quedo descongelada de un empujon
		# anterior, aqui mismo se frena y se congela: si no, quedaba como
		# cuerpo rigido libre y la gravedad/la pendiente la seguian moviendo
		# solas hasta el proximo empujon. Que la mueva solo el jugador.
		#
		# En pleno brinco no: el salto no saca de "quieto", asi que soltar el
		# stick en el aire dejaba al piche congelado a media altura.
		_vel_andar = 0.0
		if not bola.freeze and not _saltando:
			bola.linear_velocity = Vector3.ZERO
			bola.angular_velocity = Vector3.ZERO
			bola.freeze = true
		return
	bola.freeze = false      # congelada no admite fuerzas
	# la velocidad de andar la lleva ESTA variable, no lo que traiga ya
	# bola.linear_velocity: si se leyera de ahi, una pendiente le sumaria
	# tirón propio (gravedad ladera abajo) y el piche se moveria solo con
	# el mando quieto o incluso soltado a medias, que es justo lo que no
	# tiene que pasar. Aqui solo sube si hay mando, con la propia
	# aceleracion de andar, y nunca por fisica del terreno.
	_vel_andar = minf(CONDUCE_MAX, _vel_andar + CONDUCE_ACEL * dt)
	var recta := dir.normalized()
	bola.linear_velocity = recta * _vel_andar + Vector3.UP * bola.linear_velocity.y


## El salto (espacio) despega con lo que ya lleve encima. No toca `quieto`:
## sacar la bola de ese estado la metia por el camino del golpe -la camara se
## iba atras y al caer salia el aviso de distancia-, asi que un brinco se veia
## igual que un impulso y cortaba el juego. Aqui se sigue andando, solo que
## por el aire.
func _saltar() -> void:
	if _saltando or not (listo and quieto and not embocada):
		return
	_saltando = true
	bola.freeze = false      # congelada no admite ni fuerzas ni velocidad
	bola.linear_velocity += Vector3.UP * IMPULSO_SALTO


## El portazo: la puerta vuela, el hueco queda libre y la bola LO ATRAVIESA.
## El rebote contra la puerta ya venia calculado en la velocidad, asi que se le
## devuelve el rumbo hacia fuera; si no, se quedaba dentro dando tumbos.
func _reventar_puerta(fuera: Vector3) -> void:
	var v := bola.linear_velocity
	# se guarda el disparo ENTERO, vertical incluida y CON SU SIGNO: durante el
	# empujon la velocidad la manda el guion, y al soltarse se recupera tal cual.
	# Forzando solo la horizontal, la gravedad se comia el ascenso durante el
	# medio segundo del beat y el impulso llegaba a 6 m en vez de a 26. Con el
	# valor absoluto no se perdia el ascenso, pero una bola que YA venia bajando
	# salia disparada hacia arriba justo en el plano de cine.
	_vel_portazo = (fuera * Vector3(v.x, 0.0, v.z).length()
		+ Vector3.UP * v.y) * PORTAZO_FRENA
	_empujando = true
	_portazo = PORTAZO_LENTO
	var tw := create_tween()
	tw.tween_interval(PORTAZO_EMPUJE)
	tw.tween_property(self, "_portazo", 1.0, PORTAZO_SUELTA) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _empujando = false)
	_jaula.tirar_puerta(PORTAZO_EMPUJE, PORTAZO_SUELTA)
	_jaula.abrir()
	_cine_portazo()


## Camara lenta y plano fijo desde fuera, al costado del hueco: se ve la puerta
## salir volando y al piche cruzar por delante. Se mide en tiempo REAL, que si
## no el propio time_scale estiraria la espera.
func _cine_portazo() -> void:
	var fuera := _jaula.global_basis.x
	fuera.y = 0.0
	fuera = fuera.normalized()
	var lado := Vector3.UP.cross(fuera)
	golpe.cortar_a(lado * CINE_LADO - fuera * CINE_FRENTE + Vector3.UP * CINE_ALTO)
	Engine.time_scale = CINE_LENTO
	await get_tree().create_timer(CINE_DURA, true, false, true).timeout
	Engine.time_scale = 1.0
	golpe.fin_cine()


## Cierra el brinco al tocar suelo bajando.
func _aterrizar() -> void:
	var p := bola.global_position
	if bola.linear_velocity.y > 0.0 or p.y > campo.altura_terreno(p.x, p.z) + Util.RADIO + 0.06:
		return
	_saltando = false


## La puerta sigue en pie: la salida esta tapada.
func _enjaulado() -> bool:
	return is_instance_valid(_jaula) and _jaula.cerrada()


## Otra pregunta distinta de _enjaulado(): esa mira si la puerta sigue puesta.
## Esta mira si el piche sigue entre los barrotes, que es lo que aparta la
## camara. Al caer la puerta la jaula sigue ahi, y sin esto la camara se metia
## dentro a mirar los barrotes.
func _en_la_jaula() -> bool:
	if not is_instance_valid(_jaula):
		return false
	return Vector2(bola.global_position.x - _jaula.global_position.x,
		bola.global_position.z - _jaula.global_position.z).length() < 1.8


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
	# en tiempo REAL, como el temporizador del cine: con el time_scale del
	# portazo un aviso de 1.6 s se quedaba cinco segundos y pico en pantalla
	await get_tree().create_timer(seg, true, false, true).timeout
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
	# tambien en tiempo real: si se emboca con la camara lenta puesta, el cartel
	# del resultado se estiraba igual que los avisos
	await get_tree().create_timer(1.8, true, false, true).timeout
	msg.text = ""
	golpes = 0
	indice += 1
	if indice >= Campo.HOYOS.size():
		indice = 0
		total = 0
		tarjeta.clear()
	_ir_a_hoyo(indice)
	embocada = false


## Los asserts de arriba miran datos: que la jaula este puesta y mire al hoyo.
## Que RETENGA es otra cosa, y solo se sabe con la fisica corriendo. Aqui se
## empuja la bola contra la puerta y se comprueba que no sale; luego se tira la
## puerta y se comprueba que ahora si. Solo en headless: mueve la bola de
## verdad y en una partida se veria.
func _probar_jaula() -> void:
	var a_puerta := _jaula.global_basis.x       # la cara de la puerta es el +X
	var a_barrotes := _jaula.global_basis.z     # una cara ciega

	# 1. contra la puerta no se sale, y ANDANDO no se cae: solo la tira el impulso
	var p := await _empujar(a_puerta)
	var tope_puerta: float = _jaula.frente()
	print("jaula: contra la puerta, la bola queda en x=%.2f (puerta en %.2f)"
		% [p.x, tope_puerta])
	assert(p.x < tope_puerta, "la puerta no para a la bola andando")
	assert(_jaula.puerta_entera(), "andar contra la puerta la tira")

	# 2. y por los barrotes tampoco, que era el colador de la malla
	var b := await _empujar(a_barrotes)
	print("jaula: contra los barrotes, la bola queda en z=%.2f" % b.z)
	assert(absf(b.z) < 1.0, "la bola se cuela entre los barrotes")

	# 3. brincar ni tira la puerta ni despeja el techo
	_poner_bola(campo.pos_tee())
	_saltar()
	var cima := 0.0
	for i in 120:
		await get_tree().physics_frame
		var y: float = (_jaula.global_transform.affine_inverse() * bola.global_position).y
		cima = maxf(cima, y)
	print("jaula: brincando sube hasta y=%.2f" % cima)
	assert(cima > 0.5, "el brinco no despega dentro de la jaula")
	assert(cima < 1.65, "el brinco se sale por el techo")
	assert(_jaula.puerta_entera(), "brincar tira la puerta")

	# 4. con la puerta tirada se sale, pero SOLO por el hueco
	_jaula.tirar_puerta(PORTAZO_EMPUJE, PORTAZO_SUELTA)
	_jaula.abrir()                  # como al pararse tras el primer impulso
	_poner_bola(campo.pos_tee())
	var f := await _empujar(a_puerta)
	print("jaula: con la puerta tirada, sale a x=%.2f" % f.x)
	assert(f.x > 1.2, "con la puerta tirada la bola sigue encerrada")
	_poner_bola(campo.pos_tee())
	var g := await _empujar(a_barrotes)
	print("jaula: y por los barrotes sigue sin pasar, z=%.2f" % g.z)
	assert(absf(g.z) < 1.0, "rota la puerta, la bola se cuela por los barrotes")

	_poner_bola(campo.pos_tee())
	_montar_jaula()
	# _empujar deja la mira mirando a donde empujo por ultima vez: se vuelve a
	# apuntar a la bandera, que es como arranca un hoyo de verdad
	golpe.reset(campo.pos_tee(), campo.pos_bandera())


## Empuja la bola en linea recta un rato y devuelve donde acabo, en coordenadas
## de la jaula. Le anula la velocidad lateral en cada tick: en cuesta se iba de
## lado y acababa contra otra pared, asi que la prueba no medía lo que creia.
func _empujar(dir: Vector3) -> Vector3:
	# Se conduce por el camino de verdad: la mira hacia donde queremos ir y W
	# apretada, que es lo que lee golpe.mando(). Empujar la bola a mano no
	# sirve: sin mando, _conducir() la congela en el mismo tick.
	golpe.mira = atan2(dir.x, dir.z)
	_tecla(KEY_W, true)
	for i in 150:
		await get_tree().physics_frame
	_tecla(KEY_W, false)
	return _jaula.global_transform.affine_inverse() * bola.global_position


func _tecla(codigo: Key, apretada: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = codigo
	e.pressed = apretada
	Input.parse_input_event(e)


# ponytail: un solo chequeo, salta si el campo o el hoyo se montan mal
func _self_check() -> void:
	var t := campo.pos_tee()
	var b := campo.pos_bandera()
	assert(t != Vector3.ZERO and b != Vector3.ZERO, "tee o bandera sin colocar")
	assert(absf(t.y) > 0.01, "el rayo de altura no encuentra el campo bajo el tee")
	assert(campo.R_COPA > Util.RADIO * 1.5, "la copa no admite la bola")
	# el piche ocupa lo mismo en pantalla mientras no llegue al tope de tamano:
	# eso es lo que lo salva cuando la camara se queda atras en un vuelo largo
	_escalar_vista(1.0)
	var cerca := _diam_bola * vista.scale.x / 1.0
	_escalar_vista(1.6)
	assert(is_equal_approx(cerca, _diam_bola * vista.scale.x / 1.6),
		"la bola no mantiene el tamano en pantalla")
	# y de ahi no crece, o al lado de la jaula parecia un monstruo
	_escalar_vista(60.0)
	assert(_diam_bola * vista.scale.x <= VISTA_MAX + 0.001,
		"la bola pasa del tope de tamano")
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
	# la meta es SUBIRSE a la camioneta: encima y posado cuenta; al lado,
	# debajo, o pasandole por arriba a toda velocidad, no
	# se prueba justo en el borde de la condicion de altura, no en el techo: el
	# sitio donde uno se sube de verdad es el piso de la caja, y ahi es donde
	# fallaba -el umbral estaba 18 cm por encima de ese piso-
	var caja: AABB = campo._meta
	var m := Vector3(caja.get_center().x,
		caja.position.y + caja.size.y * campo.ALTURA_CAJA, caja.get_center().z)
	assert(campo.embocada(m + Vector3.UP * 0.05), "posado en la caja no cuenta como llegar")
	assert(not campo.embocada(m - Vector3.UP * 0.05), "por debajo del piso cuenta como llegar")
	assert(not campo.embocada(m + Vector3.UP * 0.3, Vector3(20, 0, 0)),
		"pasarle por arriba volando cuenta como llegar")
	assert(not campo.embocada(m + Vector3(8, 0.3, 0)), "al lado cuenta como llegar")
	assert(not campo.embocada(m - Vector3(0, 2.5, 0)), "por debajo cuenta como llegar")
	# la jaula: la bola arranca dentro y la puerta mira a la bandera
	assert(is_instance_valid(_jaula) and _jaula.puerta_entera(), "no hay jaula")
	var dentro := bola.global_position - _jaula.global_position
	assert(absf(dentro.x) < 1.0 and absf(dentro.z) < 1.0, "la bola no arranca dentro")
	var al_hoyo := campo.pos_bandera() - campo.pos_tee()
	var cara := _jaula.global_basis.x
	assert(Vector2(cara.x, cara.z).normalized().dot(
		Vector2(al_hoyo.x, al_hoyo.z).normalized()) > 0.99,
		"la puerta no mira a la bandera")
	# y los rayos de altura no la ven: si no, la bola se colocaria en su techo
	assert(absf(campo.altura_terreno(bola.global_position.x, bola.global_position.z)
		- (bola.global_position.y - Util.RADIO)) < 0.2,
		"la jaula tapa los rayos de altura")
	var vuelve := bola.global_position
	# sin stamina no hay impulso
	var stamina_previa := stamina
	stamina = 0.0
	golpe.puede_saltar = false
	golpe.activo = true
	golpe.cargar()
	golpe.soltar()
	assert(_v_pendiente == Vector3.ZERO, "salio impulso sin stamina")
	stamina = stamina_previa
	golpe.puede_saltar = true
	# el salto despega gratis (no gasta stamina) y no saca a la bola del
	# estado de andar: si lo hiciera, un brinco se veria como un impulso
	var stamina_salto := stamina
	_saltar()
	assert(bola.linear_velocity.y > 0.0, "el salto no despega")
	assert(stamina == stamina_salto, "el salto gasta stamina")
	assert(quieto and golpe.activo, "el salto corta el estado de andar")
	assert(_saltando, "el salto no queda marcado como brinco")
	bola.global_position = vuelve
	bola.linear_velocity = Vector3.ZERO
	bola.freeze = true
	_saltando = false
	stamina = stamina_salto
	print("modelo %s | caja %s | diametro %.2f u"
		% [vista.scene_file_path.get_file(), str(_caja_bola), _diam_bola])
	print("self-check OK | tee %s | bandera %s | %d m | par %d"
		% [str(t.round()), str(b.round()),
		   roundi(Vector2(t.x - b.x, t.z - b.z).length()), campo.par()])
	if DisplayServer.get_name() == "headless":
		await _probar_jaula()
		await get_tree().create_timer(0.5).timeout
		golpe.activo = true      # soltar() sale de vacio si no hubo cargar()
		golpe.cargar()
		golpe.fuerza = 1.0
		golpe.soltar()
		assert(_v_pendiente != Vector3.ZERO, "el golpe no salio")
		assert(stamina < STAMINA_MAX, "el salto no gasta stamina")
		# la puerta ya no se cae al apretar: se cae cuando la bola le pega. El
		# primer impulso choca, la tira y rebota dentro de la jaula.
		await get_tree().physics_frame
		await get_tree().physics_frame
		for i in 900:
			if quieto:
				break
			await get_tree().physics_frame
		var d := bola.global_position.distance_to(_jaula.global_position)
		print("primer impulso: puerta abajo y la bola sale a %.2f m de la jaula" % d)
		assert(not _jaula.puerta_entera(), "el primer impulso no tiro la puerta")
		assert(not _jaula.cerrada(), "el hueco no quedo abierto")
		# que SALIO de la jaula, no cuantos metros: la media diagonal de la jaula
		# es 1.41, asi que por encima de eso ya esta fuera. Cuanto recorra
		# despues depende del mapa -en el muelle hay un galpon a dos pasos- y
		# eso no es cosa de esta comprobacion.
		assert(d > 1.45, "el impulso revento la puerta pero no salio")
