extends Node3D
class_name Juego
## Reglas y estado de la partida. No sabe como esta hecho el mapa:
## solo le pide el viento, la salida, la meta y si algo se ha chocado.

# --- calibracion de juego ---
const QUIETA := 0.3
# un piche rodando a QUIETA gira a QUIETA/RADIO rad/s: a la escala de la
# esfera de colision son 14 rad/s, no los 2 que valian con un modelo de 40 cm
const QUIETA_GIRO := QUIETA / Util.RADIO * 2.0
const ESPERA_QUIETA := 0.2
# Un piche cae y frena de golpe, no rueda como una bola:
# con el damp del suelo solo (0.3) tardaba mas de 10 s en asentarse
# despues de caer, y hasta que no estaba "quieto" no se recuperaba el control.
const FRENO_ATERRIZAJE := 0.32   # fraccion de velocidad que le queda al tocar
# Tope duro ademas del freno: con poco damp el resto de velocidad que
# sobrevive al freno igual podia reptar mas de la cuenta. A partir de este
# tiempo EN EL SUELO (no cuenta el vuelo) se corta y se da por quieta.
const CAIDA_MAX := 0.5
const VEL_MARCA := 15.0
const MAX_MARCAS := 30
# --- direccion en el aire ---
const AIRE_ACEL := 11.0     # m/s2 laterales mientras se dirige
const AIRE_TIEMPO := 1.1    # segundos de timon por impulso
# --- rodar el piche con el mando ---
const CONDUCE_ACEL := 7.0   # m/s2 que mete el stick izquierdo
const CONDUCE_MAX := 4.5    # m/s: es andar, no un impulso
const GIRO_MAX := 9.0       # rad/s: por encima de esto la vuelta es un borron
# --- stamina ---
# Se anda libre, sin radio: lo unico que cuesta stamina es el impulso (G). La
# basura del mapa la repone: es lo que obliga a desviarse de la linea recta
# al nivel.
const STAMINA_MAX := 100.0
const STAMINA_BASURA := 20.0
const STAMINA_IMPULSO := 60.0 # lo que cuesta el impulso (G) a barra llena
const IMPULSO_SALTO := 5.5    # m/s hacia arriba, sin tocar lo que ya lleve
# Por debajo de esto no hay impulso: ni barra, ni impulso minimo. Es el mismo
# numero que pinta de rojo la barra, para que lo que se ve y lo que se puede
# hacer sean la misma regla.
const STAMINA_MIN := STAMINA_IMPULSO * 0.2
const R_RECOGE := 1.2
# La esfera de colision son 4 cm: a 20 m el piche ya no se ve. Se dibuja de
# modo que ocupe SIEMPRE la misma fraccion de la pantalla, calculada con el fov
# y la distancia reales de la camara. La colision sigue siendo la esfera de 4 cm.
# La jaula arranca cerrada en el salida y la puerta se cae al primer impulso. En
# el modelo la puerta esta en la cara +X del nodo raiz, asi que la jaula se
# gira para que esa cara mire a la meta y el piche salga hacia el nivel.
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
# hueco. No es una escena aparte -habria que duplicar jaula, piche y mapa-,
# es este mismo juego a un cuarto de velocidad y con la camara cortada.
const CINE_LENTO := 0.18      # a cuanto baja el tiempo
# los dos tiempos del portazo son 0.48 s de juego: al 18% son 2.7 reales, asi
# que la camara lenta se corta justo cuando el piche recupera y sale disparado
const CINE_DURA := 2.4        # segundos REALES, no de juego
const CINE_LADO := 3.6        # cuanto se aparta la camara del eje de salida
const CINE_FRENTE := 2.2      # y cuanto se queda por detras, para ver la jaula
const CINE_ALTO := 1.4
# Al reventar la puerta el piche pierde algo, pero SIGUE hacia fuera: cuando
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

## Con que mapa arrancar. Lo pone el menu (su boton de debug) antes de cambiar
## de escena; un cambio de escena no admite argumentos y esto son dos lineas,
## que es menos que un autoload.
static var mapa_inicial := 0

## Los mapas, EN ORDEN. Se arrastran las escenas en el Inspector: agregar un
## mapa no toca codigo. Cada una es un Node3D con mapa.gd, su glb como
## `Escenario` y un `Marker3D` `Salida`.
@export var mapas: Array[PackedScene] = []

var indice := 0
var llegado := false
var _muriendo := false
var quieto := true
var listo := false
var _t_lento := 0.0
var _t_caida := 0.0       # cuanto lleva EN EL SUELO desde que aterrizo, para CAIDA_MAX
var _impulso_volo := false  # si este impulso llego a volar (pos.y > umbral); ver CAIDA_MAX
var _v_pendiente := Vector3.ZERO
var _giro := 0.0
var _en_aire := false
var _desde := Vector3.ZERO
var _ultimo := 0.0        # distancia del ultimo impulso, para el aviso
var _diam_piche := 1.0     # tamano del modelo tal cual viene, en sus unidades
var _caja_piche := AABB()
var stamina := STAMINA_MAX
var _jaula: Node3D            # escenas/Jaula.tscn
@onready var _portada: CanvasLayer = $Portada
var _t_arranque := 0
var _empujando := false       # el piche esta abriendo la puerta a empujones
var _portazo := 1.0           # que fraccion de su velocidad lleva mientras
var _vel_portazo := Vector3.ZERO   # el disparo entero, congelado en el impacto
var _pulso_salto := false     # para detectar el flanco del espacio
var _saltando := false        # brinco en escenario: sin soltar el mando
var _vel_andar := 0.0         # velocidad de _conducir(): solo sube con mando, nunca con el terreno
var _angulo_rueda := 0.0                 # cuanto lleva rodado
var _eje_rueda := Vector3.RIGHT          # el eje del disco: su cara plana
var _dir_rueda := Vector3.FORWARD
var _mira_rueda := 0.0                   # ultima mira vista, para girar en el sitio con A/D
var _aire := 0.0          # timon que le queda a este impulso
var _marcas: Array = []

var mapa: Mapa                # lo instancia _cargar_mapa(), no esta en Juego.tscn
@onready var piche: RigidBody3D = $Piche
@onready var vista: Node3D = $Piche/Vista
@onready var estela: CPUParticles3D = $Piche/Estela
@onready var camara: Camera3D = $Camara
@onready var impulso: Node3D = $Impulso
@onready var entorno: WorldEnvironment = $Entorno
@onready var hud: Label = $UI/Hud
@onready var msg: Label = $UI/Msg
@onready var barra: ProgressBar = $UI/Barra
@onready var barra_stam: ProgressBar = $UI/BarraStam


func _ready() -> void:
	randomize()
	_t_arranque = Time.get_ticks_msec()
	_preparar_piche()
	_conectar_tactil()
	barra_stam.max_value = STAMINA_MAX   # el .tscn no puede leer la constante

	impulso.preparar(piche, camara)
	impulso.impulsado.connect(_on_impulsado)

	# ponytail: con que mapa arrancar. Lo decide el menu, y por linea de
	# comandos se pisa:  godot --path . escenas/Juego.tscn -- --mapa 1
	var pedido := mapa_inicial
	var args := OS.get_cmdline_user_args()
	var i := args.find("--mapa")
	if i >= 0 and i + 1 < args.size():
		pedido = clampi(int(args[i + 1]), 0, mapas.size() - 1)
	await _cargar_mapa(pedido)
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
	# ponytail: se esconde, no se libera. Hace falta entera para tapar el
	# cambio de mapa, que tambien tarda. La transicion todavia no esta hecha.
	t.tween_callback(func(): _portada.visible = false)


## El piche esta en Piche.tscn. Aca queda solo lo que un .tscn no guarda: el
## .fbx trae animaciones sueltas de Blender (una camara y unas cajas) que, si
## alguna arrancara, moverian el modelo -y no se pueden borrar de una instancia
## desde el editor-; y la escala de la vista, que se mide sobre el modelo ya
## montado.
func _preparar_piche() -> void:
	var reproductor := vista.get_node_or_null("AnimationPlayer")
	if reproductor:
		reproductor.free()
	_caja_piche = _preparar_modelo(vista)
	_diam_piche = maxf(_caja_piche.size[_caja_piche.size.max_axis_index()], 0.0001)
	_escalar_vista(1.0)


## El piche no es una esfera, es un disco: su lado corto es la X del modelo
## (1.43 contra 2.05 y 2.17), asi que esa es la cara plana. Rueda como una
## RUEDA, con la cara plana de eje; acumulando la vuelta sin mas caia de canto
## y avanzaba de costado.
##
## Tampoco vale la vuelta del cuerpo rigido: la esfera de colision son 2 cm y a
## 4 m/s giraria a 200 rad/s, un borron. Se rueda como rodaria un disco del
## tamano DIBUJADO, con tope para que a toda velocidad siga leyendose.
func _rodar(e: float, dt: float) -> Basis:
	var plana := Vector3(piche.linear_velocity.x, 0.0, piche.linear_velocity.z)
	if plana.length() > 0.05:
		# el eje se recoloca con el rumbo: la rueda gira para seguir la linea
		_dir_rueda = plana.normalized()
		_eje_rueda = Vector3.UP.cross(_dir_rueda)
		var radio := _diam_piche * e * 0.5
		if dt > 0.0 and radio > 0.0:
			_angulo_rueda += minf(plana.length() / radio, GIRO_MAX) * dt
	elif dt > 0.0 and impulso.activo:
		# quieto o girando en el sitio: A/D solo cambia la mira (impulso.gd), no
		# empuja, asi que aqui no hay avance del que sacar rumbo. Sin esto el
		# piche se quedaba mirando para el ultimo lado que rodo, y A/D no se
		# notaba en el modelo, solo en la camara. Se sigue la mira y se gira
		# sobre el propio eje lo mismo que giro ella, como si pivotara.
		# Solo con activo=true (el jugador manda): si no, un impulso real que
		# frena por debajo de 0.05 antes de quedar "quieto" haria que el
		# piche pegara un giro brusco hacia la mira vieja del ultimo apunte.
		var d_mira := wrapf(impulso.mira - _mira_rueda, -PI, PI)
		_mira_rueda = impulso.mira
		_dir_rueda = Vector3(sin(impulso.mira), 0, cos(impulso.mira))
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
	assert(not primera, "el modelo de el piche no trae ninguna malla")
	return caja


## Escala el modelo para que ocupe VISTA_PANTALLA del alto del encuadre, este
## donde este la camara y con el fov que tenga. Nunca por debajo del tamano real.
##
## El apoyo es lo delicado: el modelo gira con el cuerpo, asi que su punto mas bajo
## cambia con la vuelta que lleve. Se calcula la caja YA GIRADA y se apoya justo
## en el punto de contacto de el piche. Antes el levante iba en ejes de el piche y
## al rodar apuntaba hacia abajo: por eso se hundia en el mapa.
func _escalar_vista(dist: float, dt := 0.0) -> void:
	var alto := 2.0 * dist * tan(deg_to_rad(camara.fov) * 0.5)
	var e := clampf(VISTA_PANTALLA * alto, Util.RADIO * 2.0, VISTA_MAX) / _diam_piche
	var base := _rodar(e, dt).scaled(Vector3.ONE * e)
	var caja := Transform3D(base, Vector3.ZERO) * _caja_piche
	vista.global_transform = Transform3D(base, piche.global_position - Vector3(
		caja.get_center().x, caja.position.y + Util.RADIO, caja.get_center().z))


## Planta la jaula de verdad EXACTAMENTE donde el glb traia la suya -misma
## posicion y mismo giro, que ya deja la puerta mirando a la camioneta- con la
## piche ya dentro. Los cuerpos de la jaula se sacan de los rayos de altura: si
## no, el rayo del salida daria en su techo y todo se colocaria mas arriba.
func _montar_jaula() -> void:
	if is_instance_valid(_jaula):
		_jaula.queue_free()   # la bisagra y la puerta cuelgan de ella
		_jaula = null
	Engine.time_scale = 1.0     # por si se cambia de mapa en pleno portazo
	impulso.fin_cine()
	# Un mapa sin jaula en el glb arranca al piche de pie, sin encierro y sin
	# cinematica: ya se escapo una vez, no tiene por que estar preso otra.
	if not mapa.tiene_jaula():
		return
	_jaula = (load(JAULA) as PackedScene).instantiate()
	add_child(_jaula)
	# tal cual la dejo el artista: ni se recalcula la altura ni se rota
	_jaula.global_transform = mapa.trafo_jaula_mapa()

	_jaula.vigilar(piche)
	_jaula.reventada.connect(_reventar_puerta)
	# sus cuerpos fuera de los rayos de altura: si no, el rayo del salida da en el
	# techo de la jaula y el piche se coloca dos metros mas arriba
	mapa.excluir = [piche.get_rid()]
	mapa.excluir.append_array(_jaula.cuerpos())


## Los nodos estan en Juego.tscn; aca solo queda lo que un .tscn no guarda:
## a quien avisan los botones y si se ven (solo en pantalla tactil).
func _conectar_tactil() -> void:
	var tactil := DisplayServer.is_touchscreen_available()
	$UI/Pegar.visible = tactil
	$UI/Drop.visible = tactil
	if not tactil:
		return
	$UI/Pegar.button_down.connect(func(): impulso.cargar())
	$UI/Pegar.button_up.connect(func(): impulso.soltar())
	$UI/Drop.pressed.connect(_destrabar)


## Cambia de mapa ENTERO: libera el anterior y monta el siguiente. Es lo unico
## que se instancia por codigo, y a proposito: cual mapa toca depende de por
## donde va la partida, que es justo lo que un .tscn no puede saber.
##
## El viejo se saca del arbol ANTES de montar el nuevo: si los dos conviven, sus
## colisiones se solapan y los rayos de altura del nuevo dan en el viejo.
func _cargar_mapa(i: int) -> void:
	assert(i >= 0 and i < mapas.size(), "no hay mapa %d: la lista tiene %d" % [i, mapas.size()])
	listo = false
	indice = i
	msg.text = "Cargando el mapa..."
	_marcas.clear()          # los crateres cuelgan del mapa: se van con el
	if is_instance_valid(_jaula):
		_jaula.queue_free()
	if is_instance_valid(mapa):
		remove_child(mapa)   # fuera del arbol YA, no al final del frame
		mapa.queue_free()
		await get_tree().physics_frame

	mapa = mapas[i].instantiate() as Mapa
	assert(mapa != null, "la escena del mapa %d no tiene mapa.gd" % i)
	add_child(mapa)
	mapa.excluir = [piche.get_rid()]
	impulso.mapa = mapa   # para que el rayo de colision de la camara no pise la jaula
	await mapa.preparar()
	impulso.suelo = Callable(mapa, "altura_terreno")

	_ir_a_nivel()
	_check_mapa()
	msg.text = ""


## Deja el mapa ya montado listo para jugar: piche en la salida, jaula puesta,
## stamina llena, camara encuadrada.
func _ir_a_nivel() -> void:
	mapa.ir_a()
	impulso.reset(mapa.pos_salida(), mapa.pos_meta())
	impulso.viento = mapa.viento
	stamina = STAMINA_MAX
	_aire = 0.0
	_giro = 0.0
	# Con jaula, la altura de la salida es la que le dio el artista y un rayo
	# mentiria (ver mapa.ir_a); sin jaula, el marcador solo marca el plano y la
	# altura la pone el rayo al suelo.
	_poner_piche(mapa.pos_salida(), not mapa.tiene_jaula())
	_montar_jaula()    # despues de colocar el piche: la deja dentro
	impulso.encuadrar()


## `apoyar` tira un rayo y deja el piche sobre lo que encuentre, que es lo que
## quiere un drop. En el salida NO: ahi la altura es la de la jaula del modelo, y
## un rayo la dejaria tres metros mas abajo, fuera de la jaula.
func _poner_piche(donde: Vector3, apoyar := true) -> void:
	piche.freeze = true
	piche.linear_velocity = Vector3.ZERO
	piche.angular_velocity = Vector3.ZERO
	var y: float = mapa.altura_terreno(donde.x, donde.z) if apoyar else donde.y
	piche.global_position = Vector3(donde.x, y + Util.RADIO, donde.z)
	piche.angular_damp = 0.6
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
	_mira_rueda = impulso.mira  # que no arranque girando por la diferencia con la mira anterior
	_aplicar_damp()


func _aplicar_damp() -> void:
	var p := piche.global_position
	piche.linear_damp = mapa.damp_suelo()


## Saca al piche de donde se haya quedado trabado. Antes era el "drop" del
## golf y costaba un impulso de penalizacion; ahora no cuesta nada, porque no
## hay contador que cobrar. Si algun dia hace falta que trabarse duela, el
## coste va aca.
func _destrabar() -> void:
	if not (quieto and not llegado and listo):
		return
	# Recoloca el piche hasta 2.8 m a dedo, sin mirar paredes: dentro de
	# la jaula eso la teletransporta al otro lado de los muros y se salta el
	# portazo entero por un impulso de pena. Y en pleno cine, ademas, resetearia
	# _empujando/_portazo a mitad del guion.
	if _enjaulado() or impulso.cine:
		return
	_poner_piche(piche.global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))
	_aviso("Destrabado", 1.0)


func _on_impulsado(velocidad: Vector3) -> void:
	# fuerza sigue puesta: impulso.gd la borra despues de emitir
	stamina = maxf(0.0, stamina - STAMINA_IMPULSO * impulso.fuerza)
	_desde = piche.global_position
	_aire = AIRE_TIEMPO
	_v_pendiente = velocidad
	_impulso_volo = false
	# el angulo de salida ya es fijo, asi que el efecto sale casi constante; lo
	_giro = clampf(velocidad.normalized().y * 2.2, 0.25, 1.0)


func _process(dt: float) -> void:
	if not listo:
		return
	impulso.activo = quieto and not llegado
	# sin stamina no hay impulso: la barra no sube y cargar() ni empieza
	impulso.tope = clampf(stamina / STAMINA_IMPULSO, 0.0, 1.0)
	impulso.puede_saltar = stamina >= STAMINA_MIN
	impulso.enjaulado = _en_la_jaula()

	var cogidas := mapa.recoger(piche.global_position, R_RECOGE)
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

	if impulso.activo and Input.is_key_pressed(KEY_R):
		_destrabar()

	mapa.mover_animales(dt, piche.global_position,
		not quieto and piche.linear_velocity.length() > 10.0)
	mapa.rodar_rocas(dt, piche.global_position)
	# geometria, no contactos: una roca grande baja a mas de 20 m/s y a esa
	# velocidad la colision la resuelve el CCD, que no reporta contacto
	var roca := mapa.roca_encima(piche.global_position, Util.RADIO)
	if roca:
		_morir("Te aplasto una roca")

	# Que el piche no se pierda de vista. Parada se dibuja a tamano real, que es
	# cuando la camara esta encima y se vería un melon al lado del palo; en
	# juego se agranda con la distancia, de modo que ocupa siempre lo mismo.
	_escalar_vista(camara.global_position.distance_to(piche.global_position), dt)

	barra.value = impulso.fuerza * 100.0
	var p := piche.global_position
	var b := mapa.pos_meta()
	var dist := Vector2(p.x - b.x, p.z - b.z).length()
	var v := mapa.viento
	# ponytail: sigue siendo texto de debug, no una interfaz. Lo que tiene que
	# ver el jugador -a donde ir, con que tecla- esta en AUDITORIA.md.
	hud.text = ("Mapa %d/%d | %d m a la camioneta%s
"
		+ "Stamina %d | basura %d | Fuerza %d%% (%.0f m/s) | viento %.0f m/s
"
		+ "Timon %s") % [
		indice + 1, mapas.size(), roundi(dist),
		"  (se va!)" if mapa.meta_se_mueve() else "",
		roundi(stamina), mapa.basura.size(),
		roundi(impulso.fuerza * 100), impulso.velocidad(),
		Vector2(v.x, v.z).length(),
		"#".repeat(ceili(_aire / AIRE_TIEMPO * 10.0)) if _aire > 0.0 else "-"]


func _physics_process(dt: float) -> void:
	if not listo or llegado:
		return

	# el impulso se aplica aqui: descongelar y empujar en el mismo tick de fisica
	if _v_pendiente != Vector3.ZERO:
		piche.freeze = false
		quieto = false
		_t_lento = 0.0
		_saltando = false
		piche.apply_central_impulse(_v_pendiente * Util.MASA)
		_v_pendiente = Vector3.ZERO
		return

	if quieto:
		_conducir(dt)
		if _saltando:
			_aterrizar()
		# tambien vale llegar andando: subirse a la caja es subirse igual
		if mapa.llego(piche.global_position, piche.linear_velocity):
			_llegar()
		return

	var pos := piche.global_position
	var vel := piche.linear_velocity
	if pos.y < -60.0:
		_poner_piche(_desde)
		return

	if mapa.llego(pos, vel):
		_llegar()
		return

	var suelo := mapa.altura_terreno(pos.x, pos.z)
	var volando := pos.y > suelo + Util.RADIO + 0.4
	_impulso_volo = _impulso_volo or volando
	piche.linear_damp = 0.0 if volando else mapa.damp_suelo()
	estela.emitting = volando and vel.length() > 20.0
	if _en_aire and not volando:
		if vel.length() > VEL_MARCA:
			_marca(pos, vel.length())
		# el toque de aterrizaje: el piche cae y se planta, aqui pierde
		# de golpe casi toda la velocidad en vez de seguir rodando largo. El
		# giro tambien se corta, si no la friccion lo va reacelerando y el
		# check de "quieto" (que mira angular_velocity) no llega a cumplirse.
		piche.linear_velocity *= FRENO_ATERRIZAJE
		piche.angular_velocity *= FRENO_ATERRIZAJE
		vel = piche.linear_velocity
	_en_aire = volando

	# mientras abre la puerta la velocidad la pone el guion, no la fisica: es el
	# mismo disparo a camara lenta, asi que al soltarse sigue como si nada
	if _empujando:
		piche.linear_velocity = _vel_portazo * _portazo

	_giro = maxf(0.0, _giro - dt / Util.VIDA_GIRO)
	piche.apply_central_force(Util.fuerza_aire(vel, mapa.viento, _giro))

	# timon: solo en el aire y solo mientras quede presupuesto. Empuja de lado,
	# perpendicular al avance, asi que corrige la linea sin regalar distancia.
	var plana := Vector3(vel.x, 0, vel.z)
	if volando and _aire > 0.0 and absf(impulso.timon) > 0.05 and plana.length() > 1.0:
		var lado := Vector3.UP.cross(plana.normalized())
		piche.apply_central_force(lado * impulso.timon * AIRE_ACEL * Util.MASA)
		_aire = maxf(0.0, _aire - dt)

	if mapa.choque(pos, vel) == "animal":
		_aviso("Lo atropellaste", 1.2)

	# ponytail: el frenado es exponencial, asi que la cola es larga y el piche
	# repta un rato. Si se nota flotante, cambiarlo por resistencia a la
	# rodadura: fuerza constante en contra, no proporcional a la velocidad.
	# Mientras dura el empujon no se mira si esta quieta: la velocidad la pone el
	# guion y con carga minima el empuje lento (PORTAZO_LENTO) queda justo en
	# QUIETA, asi que el piche se declaraba quieta y se congelaba en pleno cine.
	# Peor todavia: _empujando se quedaba puesto y el siguiente impulso del jugador
	# lo pisaba _vel_portazo viejo. Ya se decidira cuando suelte.
	if not volando and not _empujando:
		var casi_quieta := vel.length() < QUIETA and piche.angular_velocity.length() < QUIETA_GIRO
		_t_lento = _t_lento + dt if casi_quieta else 0.0
		# CAIDA_MAX solo corta el REBOTE despues de un impulso que voló: para un
		# impulso corto que nunca despega no hay caida que cortar, y
		# aplicarlo igual lo paraba en seco a mitad de rodada. Sin volar de
		# por medio, se frena solo como siempre: gradual, con el damp del suelo.
		var corte_por_tiempo := false
		if _impulso_volo:
			_t_caida += dt
			corte_por_tiempo = _t_caida >= CAIDA_MAX
		if _t_lento >= ESPERA_QUIETA or corte_por_tiempo:
			piche.linear_velocity = Vector3.ZERO
			piche.angular_velocity = Vector3.ZERO
			piche.freeze = true
			quieto = true
			_vel_andar = 0.0
			_ultimo = Vector2(pos.x - _desde.x, pos.z - _desde.z).length()
			if _enjaulado():
				# por si el impulso no llego a tocarla: siempre la tira, o el
				# jugador se quedaria encerrado
				_jaula.tirar_puerta(PORTAZO_EMPUJE, PORTAZO_SUELTA)
				_jaula.abrir()
			_aviso("%d m" % roundi(_ultimo), 1.6)
	else:
		_t_lento = 0.0
		_t_caida = 0.0


## El stick izquierdo rueda el piche mientras esta parado. En el aire ese mismo
## stick es el timon, asi que no se pisan. CONDUCE_MAX topa la velocidad de
## andar; para cruzar el mapa de verdad hay que impulsar.
func _conducir(dt: float) -> void:
	var dir: Vector3 = impulso.mando()
	if dir == Vector3.ZERO:
		# sin mando no se mueve nada. Si quedo descongelada de un empujon
		# anterior, aqui mismo se frena y se congela: si no, quedaba como
		# cuerpo rigido libre y la gravedad/la pendiente la seguian moviendo
		# solas hasta el proximo empujon. Que la mueva solo el jugador.
		#
		# En pleno brinco no: el salto no saca de "quieto", asi que soltar el
		# stick en el aire dejaba al piche congelado a media altura.
		_vel_andar = 0.0
		if not piche.freeze and not _saltando:
			piche.linear_velocity = Vector3.ZERO
			piche.angular_velocity = Vector3.ZERO
			piche.freeze = true
		return
	piche.freeze = false      # congelada no admite fuerzas
	# la velocidad de andar la lleva ESTA variable, no lo que traiga ya
	# piche.linear_velocity: si se leyera de ahi, una pendiente le sumaria
	# tirón propio (gravedad ladera abajo) y el piche se moveria solo con
	# el mando quieto o incluso soltado a medias, que es justo lo que no
	# tiene que pasar. Aqui solo sube si hay mando, con la propia
	# aceleracion de andar, y nunca por fisica del terreno.
	_vel_andar = minf(CONDUCE_MAX, _vel_andar + CONDUCE_ACEL * dt)
	var recta := dir.normalized()
	piche.linear_velocity = recta * _vel_andar + Vector3.UP * piche.linear_velocity.y


## El salto (espacio) despega con lo que ya lleve encima. No toca `quieto`:
## sacar el piche de ese estado la metia por el camino del impulso -la camara se
## iba atras y al caer salia el aviso de distancia-, asi que un brinco se veia
## igual que un impulso y cortaba el juego. Aqui se sigue andando, solo que
## por el aire.
func _saltar() -> void:
	if _saltando or not (listo and quieto and not llegado):
		return
	_saltando = true
	piche.freeze = false      # congelada no admite ni fuerzas ni velocidad
	piche.linear_velocity += Vector3.UP * IMPULSO_SALTO


## El portazo: la puerta vuela, el hueco queda libre y el piche LO ATRAVIESA.
## El rebote contra la puerta ya venia calculado en la velocidad, asi que se le
## devuelve el rumbo hacia fuera; si no, se quedaba dentro dando tumbos.
func _reventar_puerta(fuera: Vector3) -> void:
	var v := piche.linear_velocity
	# se guarda el disparo ENTERO, vertical incluida y CON SU SIGNO: durante el
	# empujon la velocidad la manda el guion, y al soltarse se recupera tal cual.
	# Forzando solo la horizontal, la gravedad se comia el ascenso durante el
	# medio segundo del beat y el impulso llegaba a 6 m en vez de a 26. Con el
	# valor absoluto no se perdia el ascenso, pero un piche que YA venia bajando
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
	impulso.cortar_a(lado * CINE_LADO - fuera * CINE_FRENTE + Vector3.UP * CINE_ALTO)
	Engine.time_scale = CINE_LENTO
	await get_tree().create_timer(CINE_DURA, true, false, true).timeout
	Engine.time_scale = 1.0
	impulso.fin_cine()


## Cierra el brinco al tocar suelo bajando.
func _aterrizar() -> void:
	var p := piche.global_position
	if piche.linear_velocity.y > 0.0 or p.y > mapa.altura_terreno(p.x, p.z) + Util.RADIO + 0.06:
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
	return Vector2(piche.global_position.x - _jaula.global_position.x,
		piche.global_position.z - _jaula.global_position.z).length() < 1.8


func _marca(pos: Vector3, v: float) -> void:
	var r := clampf(v * 0.005, 0.06, 0.35)
	var m := Util.disco(r, 0.02, Color(0.30, 0.24, 0.14))
	m.position = Vector3(pos.x, mapa.altura_terreno(pos.x, pos.z) + 0.02, pos.z)
	mapa.add_child(m)
	_marcas.append(m)
	if _marcas.size() > MAX_MARCAS:
		var viejo: Node3D = _marcas.pop_front()
		if is_instance_valid(viejo):
			viejo.queue_free()
	Util.reventar(mapa, pos, Color(0.35, 0.30, 0.18), 10)


func _aviso(texto: String, seg: float) -> void:
	msg.text = texto
	# en tiempo REAL, como el temporizador del cine: con el time_scale del
	# portazo un aviso de 1.6 s se quedaba cinco segundos y pico en pantalla
	await get_tree().create_timer(seg, true, false, true).timeout
	if msg.text == texto:
		msg.text = ""


## Lo mato una roca: se vuelve a empezar EL MAPA, no la partida entera. Perder
## el cerro no tiene por que costar el muelle.
##
## ponytail: no hay vidas ni contador de intentos. Si hiciera falta que morir
## duela mas que perder el tiempo, el contador va aca.
func _morir(motivo: String) -> void:
	if _muriendo or not listo:
		return
	_muriendo = true
	listo = false
	piche.freeze = true
	estela.emitting = false
	Util.reventar(mapa, piche.global_position, Color(0.6, 0.5, 0.4), 24)
	msg.text = motivo
	# en tiempo real, como los demas avisos: si muere en camara lenta el cartel
	# se estiraria con el time_scale
	await get_tree().create_timer(1.6, true, false, true).timeout
	msg.text = ""
	await _cargar_mapa(indice)
	_muriendo = false


## El piche alcanzo la camioneta: se acabo el mapa.
##
## ponytail: al pasar del ultimo vuelve al primero. Falta la pantalla de
## llegada y el guardado del progreso (AUDITORIA.md).
func _llegar() -> void:
	llegado = true
	piche.freeze = true
	estela.emitting = false
	msg.text = "La alcanzaste!" if mapa.meta_se_mueve() else "Llegaste a la camioneta"
	# en tiempo real: si se llega con la camara lenta puesta, el cartel se
	# estiraba igual que los avisos
	await get_tree().create_timer(1.8, true, false, true).timeout
	msg.text = ""
	await _cargar_mapa((indice + 1) % mapas.size())
	llegado = false


## Los asserts de arriba miran datos: que la jaula este puesta y mire al nivel.
## Que RETENGA es otra cosa, y solo se sabe con la fisica corriendo. Aqui se
## empuja el piche contra la puerta y se comprueba que no sale; luego se tira la
## puerta y se comprueba que ahora si. Solo en headless: mueve el piche de
## verdad y en una partida se veria.
func _probar_jaula() -> void:
	var a_puerta := _jaula.global_basis.x       # la cara de la puerta es el +X
	var a_barrotes := _jaula.global_basis.z     # una cara ciega

	# 1. contra la puerta no se sale, y ANDANDO no se cae: solo la tira el impulso
	var p := await _empujar(a_puerta)
	var tope_puerta: float = _jaula.frente()
	print("jaula: contra la puerta, el piche queda en x=%.2f (puerta en %.2f)"
		% [p.x, tope_puerta])
	assert(p.x < tope_puerta, "la puerta no para a el piche andando")
	assert(_jaula.puerta_entera(), "andar contra la puerta la tira")

	# 2. y por los barrotes tampoco, que era el colador de la malla
	var b := await _empujar(a_barrotes)
	print("jaula: contra los barrotes, el piche queda en z=%.2f" % b.z)
	assert(absf(b.z) < 1.0, "el piche se cuela entre los barrotes")

	# 3. brincar ni tira la puerta ni despeja el techo
	_poner_piche(mapa.pos_salida(), false)
	_saltar()
	var cima := 0.0
	for i in 120:
		await get_tree().physics_frame
		var y: float = (_jaula.global_transform.affine_inverse() * piche.global_position).y
		cima = maxf(cima, y)
	print("jaula: brincando sube hasta y=%.2f" % cima)
	assert(cima > 0.5, "el brinco no despega dentro de la jaula")
	assert(cima < 1.65, "el brinco se sale por el techo")
	assert(_jaula.puerta_entera(), "brincar tira la puerta")

	# 4. con la puerta tirada se sale, pero SOLO por el hueco
	_jaula.tirar_puerta(PORTAZO_EMPUJE, PORTAZO_SUELTA)
	_jaula.abrir()                  # como al pararse tras el primer impulso
	_poner_piche(mapa.pos_salida(), false)
	var f := await _empujar(a_puerta)
	print("jaula: con la puerta tirada, sale a x=%.2f" % f.x)
	assert(f.x > 1.2, "con la puerta tirada el piche sigue encerrada")
	_poner_piche(mapa.pos_salida(), false)
	var g := await _empujar(a_barrotes)
	print("jaula: y por los barrotes sigue sin pasar, z=%.2f" % g.z)
	assert(absf(g.z) < 1.0, "rota la puerta, el piche se cuela por los barrotes")

	_poner_piche(mapa.pos_salida(), false)
	_montar_jaula()
	# _empujar deja la mira mirando a donde empujo por ultima vez: se vuelve a
	# apuntar a la meta, que es como arranca un mapa de verdad
	impulso.reset(mapa.pos_salida(), mapa.pos_meta())


## Empuja el piche en linea recta un rato y devuelve donde acabo, en coordenadas
## de la jaula. Le anula la velocidad lateral en cada tick: en cuesta se iba de
## lado y acababa contra otra pared, asi que la prueba no medía lo que creia.
func _empujar(dir: Vector3) -> Vector3:
	# Se conduce por el camino de verdad: la mira hacia donde queremos ir y W
	# apretada, que es lo que lee impulso.mando(). Empujar el piche a mano no
	# sirve: sin mando, _conducir() la congela en el mismo tick.
	impulso.mira = atan2(dir.x, dir.z)
	_tecla(KEY_W, true)
	for i in 150:
		await get_tree().physics_frame
	_tecla(KEY_W, false)
	return _jaula.global_transform.affine_inverse() * piche.global_position


func _tecla(codigo: Key, apretada: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = codigo
	e.pressed = apretada
	Input.parse_input_event(e)


## Lo que se comprueba en CADA mapa que se carga, sea cual sea: que la salida
## este puesta, que la meta se pueda alcanzar y -si el mapa trae jaula- que la
## jaula quede donde el artista la dejo. Los mapas nuevos entran por aca.
func _check_mapa() -> void:
	var t := mapa.pos_salida()
	var b := mapa.pos_meta()
	assert(t != Vector3.ZERO, "%s: la salida quedo en el origen" % mapa.name)
	assert(mapa.hay_suelo(t.x, t.z), "%s: la salida no cae sobre suelo firme" % mapa.name)
	if mapa.tiene_meta():
		# la siembra va por el camino salida-meta: sin meta no hay camino
		assert(mapa.basura.size() > 0, "%s: se quedo sin basura que recoger" % mapa.name)
		var caja: AABB = mapa.caja_meta()
		if mapa.meta_se_mueve():
			# se le corre: alcanza con arrimarse, y de lejos no vale
			assert(mapa.llego(caja.get_center()), "pegado a la camioneta no cuenta")
			assert(not mapa.llego(caja.get_center() + Vector3(50, 0, 0)),
				"a 50 m de la camioneta ya cuenta como alcanzada")
			# y no puede arrancar encima del piche, o el mapa se gana solo
			var d := caja.get_center().distance_to(piche.global_position)
			print("camioneta: arranca a %.0f m del piche" % d)
			assert(not mapa.llego(piche.global_position),
				"%s: la camioneta arranca encima del piche" % mapa.name)
			# y su recorrido tiene que ALEJARSE. Si le pasa por encima a la
			# salida, la camioneta va a buscar al piche y el mapa se gana
			# quedandose quieto: paso de verdad al trazar la primera espiral.
			var roce := mapa.camioneta().roza_en_la_salida(piche.global_position)
			print("camioneta: en sus primeros 90 m pasa a %.0f m de la salida" % roce)
			assert(roce > mapa.camioneta().alcance + 6.0,
				"%s: la ruta le pasa por encima a la salida" % mapa.name)
		else:
			# la meta es SUBIRSE a la camioneta: encima y posado cuenta; al
			# lado, debajo, o pasandole por arriba a toda velocidad, no
			# se prueba justo en el borde de la condicion de altura, no en el
			# techo: el sitio donde uno se sube de verdad es el piso de la
			# caja, y ahi es donde fallaba -el umbral estaba 18 cm arriba-
			var m := Vector3(caja.get_center().x,
				caja.position.y + caja.size.y * mapa.ALTURA_CAJA, caja.get_center().z)
			assert(mapa.llego(m + Vector3.UP * 0.05), "posado en la caja no cuenta como llegar")
			assert(not mapa.llego(m - Vector3.UP * 0.05), "por debajo del piso cuenta como llegar")
			assert(not mapa.llego(m + Vector3.UP * 0.3, Vector3(20, 0, 0)),
				"pasarle por arriba volando cuenta como llegar")
			assert(not mapa.llego(m + Vector3(8, 0.3, 0)), "al lado cuenta como llegar")
			assert(not mapa.llego(m - Vector3(0, 2.5, 0)), "por debajo cuenta como llegar")
	if mapa.tiene_jaula():
		_check_jaula()
	else:
		# Sin jaula al piche lo apoya el rayo al suelo. Si queda flotando o
		# enterrado, la salida esta sobre un tejado, un hueco o una cara que
		# el rayo no ve, y el mapa arranca roto.
		var suelo := mapa.altura_terreno(piche.global_position.x, piche.global_position.z)
		var sobre := piche.global_position.y - suelo
		print("salida: el piche queda %.2f m sobre el suelo (y=%.2f)"
			% [sobre, piche.global_position.y])
		assert(absf(sobre - Util.RADIO) < 0.5, "%s: el piche no arranca apoyado" % mapa.name)
	print("mapa %d/%d %s: salida %s | meta %s | %d m%s"
		% [indice + 1, mapas.size(), mapa.name, str(t.round()), str(b.round()),
		   roundi(Vector2(t.x - b.x, t.z - b.z).length()),
		   "" if mapa.tiene_meta() else "  [SIN META: no se puede terminar]"])


## El piche arranca dentro de la jaula, la jaula esta donde el glb la dejo y la
## puerta mira a la meta. Solo para mapas que traen jaula.
func _check_jaula() -> void:
	assert(is_instance_valid(_jaula) and _jaula.puerta_entera(), "no hay jaula")
	# ocupa el sitio EXACTO de la jaula que traia el mapa, giro incluido
	var sitio := mapa.trafo_jaula_mapa()
	var desvio := _jaula.global_position.distance_to(sitio.origin)
	var giro := rad_to_deg(_jaula.global_basis.x.angle_to(sitio.basis.x))
	print("jaula: en el sitio de la del mapa, a %.3f m y %.1f grados" % [desvio, giro])
	assert(desvio < 0.01 and giro < 1.0, "la jaula de verdad no ocupa el sitio de la del mapa")
	var dentro := piche.global_position - _jaula.global_position
	assert(absf(dentro.x) < 1.0 and absf(dentro.z) < 1.0, "el piche no arranca dentro")
	# la puerta apunta a la camioneta. No al grado: el giro ya no se calcula,
	# viene del modelo, y el artista la dejo a unos grados de la linea recta.
	var a_meta := mapa.pos_meta() - mapa.pos_salida()
	var cara := _jaula.global_basis.x
	var apunta := Vector2(cara.x, cara.z).normalized().dot(
		Vector2(a_meta.x, a_meta.z).normalized())
	print("jaula: la puerta mira a %.1f grados de la meta" % rad_to_deg(acos(apunta)))
	assert(apunta > 0.9, "la puerta no mira a la meta")
	# y los rayos de altura no la ven: si la vieran, el rayo daria en su techo,
	# por encima del piche, y todo se colocaria ahi arriba
	var bajo_piche := mapa.altura_terreno(piche.global_position.x, piche.global_position.z)
	print("jaula: bajo el piche el rayo da %.2f, y el piche esta en %.2f"
		% [bajo_piche, piche.global_position.y])
	assert(bajo_piche < piche.global_position.y, "la jaula tapa los rayos de altura")


# ponytail: lo que NO depende del mapa -el piche, la camara, la stamina-. Se
# corre una vez al arrancar; lo de cada mapa esta en _check_mapa().
func _self_check() -> void:
	# el piche ocupa lo mismo en pantalla mientras no llegue al tope de tamano:
	# eso es lo que lo salva cuando la camara se queda atras en un vuelo largo
	_escalar_vista(1.0)
	var cerca := _diam_piche * vista.scale.x / 1.0
	_escalar_vista(1.6)
	assert(is_equal_approx(cerca, _diam_piche * vista.scale.x / 1.6),
		"el piche no mantiene el tamano en pantalla")
	# y de ahi no crece, o al lado de la jaula parecia un monstruo
	_escalar_vista(60.0)
	assert(_diam_piche * vista.scale.x <= VISTA_MAX + 0.001,
		"el piche pasa del tope de tamano")
	# y apoyarse en el suelo con cualquier vuelta, que es lo que se hundia
	_angulo_rueda = 2.1
	_escalar_vista(6.0)
	var apoyo: AABB = vista.global_transform * _caja_piche
	assert(absf(apoyo.position.y - (piche.global_position.y - Util.RADIO)) < 0.001,
		"el piche no se apoya en el suelo al girar")
	# y rodar como una rueda: la cara plana del disco se queda en el eje de
	# giro, perpendicular a la marcha, en vez de irse de canto
	piche.linear_velocity = Vector3(3.0, 0, 0)
	var antes := _angulo_rueda
	_escalar_vista(6.0, 0.1)
	assert(_angulo_rueda > antes, "el piche no rueda")
	assert(is_zero_approx(_eje_rueda.dot(piche.linear_velocity.normalized())),
		"la cara plana del disco no queda perpendicular a la marcha")
	piche.linear_velocity = Vector3.ZERO
	_angulo_rueda = 0.0
	var vuelve := piche.global_position
	# sin stamina no hay impulso
	var stamina_previa := stamina
	stamina = 0.0
	impulso.puede_saltar = false
	impulso.activo = true
	impulso.cargar()
	impulso.soltar()
	assert(_v_pendiente == Vector3.ZERO, "salio impulso sin stamina")
	stamina = stamina_previa
	impulso.puede_saltar = true
	# el salto despega gratis (no gasta stamina) y no saca a el piche del
	# estado de andar: si lo hiciera, un brinco se veria como un impulso
	var stamina_salto := stamina
	_saltar()
	assert(piche.linear_velocity.y > 0.0, "el salto no despega")
	assert(stamina == stamina_salto, "el salto gasta stamina")
	assert(quieto and impulso.activo, "el salto corta el estado de andar")
	assert(_saltando, "el salto no queda marcado como brinco")
	piche.global_position = vuelve
	piche.linear_velocity = Vector3.ZERO
	piche.freeze = true
	_saltando = false
	stamina = stamina_salto
	print("modelo %s | caja %s | diametro %.2f u"
		% [vista.scene_file_path.get_file(), str(_caja_piche), _diam_piche])
	print("self-check OK")
	# Las pruebas de abajo mueven el piche de verdad y son del MUELLE: la jaula
	# fisica y el casco del barco. En otro mapa no hay ni una cosa ni la otra.
	if DisplayServer.get_name() == "headless" and mapa.tiene_jaula():
		await _probar_jaula()
		await get_tree().create_timer(0.5).timeout
		impulso.activo = true      # soltar() sale de vacio si no hubo cargar()
		impulso.cargar()
		impulso.fuerza = 1.0
		impulso.soltar()
		assert(_v_pendiente != Vector3.ZERO, "el impulso no salio")
		assert(stamina < STAMINA_MAX, "el salto no gasta stamina")
		# la puerta ya no se cae al apretar: se cae cuando el piche le pega. El
		# primer impulso choca, la tira y rebota dentro de la jaula.
		await get_tree().physics_frame
		await get_tree().physics_frame
		for i in 900:
			if quieto:
				break
			await get_tree().physics_frame
		var d := piche.global_position.distance_to(_jaula.global_position)
		print("primer impulso: puerta abajo y el piche sale a %.2f m de la jaula" % d)
		assert(not _jaula.puerta_entera(), "el primer impulso no tiro la puerta")
		assert(not _jaula.cerrada(), "el hueco no quedo abierto")
		# que SALIO de la jaula, no cuantos metros: la media diagonal de la jaula
		# es 1.41, asi que por encima de eso ya esta fuera. Cuanto recorra
		# despues depende del mapa -en el muelle hay un galpon a dos pasos- y
		# eso no es cosa de esta comprobacion.
		assert(d > 1.45, "el impulso revento la puerta pero no salio")
		# el barco es trimesh (ver mapa.preparar): del tunel por el casco fino
		# a alta velocidad se ocupa el CCD del piche. Se dispara el piche contra
		# el costado y se mira GEOMETRIA (cuanto pasa del plano del casco), no
		# contactos, que a esa velocidad el CCD no reporta.
		# un metro BAJO la cubierta donde esta la jaula: ahi fuera es aire
		# libre sobre el mar y de por medio queda el costado del casco. La
		# altura va relativa a la salida, que se mueve con la jaula del glb; con un
		# 172.0 clavado el disparo pasaba por encima de la borda.
		var sal := mapa.pos_salida()
		var bajo_cubierta := sal.y - 1.0
		var costado := Vector3(sal.x - 12.0, bajo_cubierta, sal.z + 12.0)  # sobre el mar
		var frente_casco := Vector3(sal.x, bajo_cubierta, sal.z)           # dentro del barco
		var esp := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(costado, frente_casco)
		q.exclude = mapa.excluir
		var casco := esp.intersect_ray(q)
		assert(not casco.is_empty(), "el rayo al costado no encuentra el casco")
		var plano: Vector3 = casco["position"]
		var dir := (frente_casco - costado).normalized()
		piche.freeze = false
		piche.global_position = costado
		piche.linear_velocity = dir * 26.0   # el vector ENTERO, ver CLAUDE.md
		quieto = false
		var tras := 0.0
		for i in 90:
			await get_tree().physics_frame
			tras = maxf(tras, (piche.global_position - plano).dot(dir))
		print("casco: disparada a 26 m/s, el piche pasa %.2f m del plano del casco" % tras)
		assert(tras < 1.0, "el piche atraviesa el casco del barco")
		_poner_piche(mapa.pos_salida(), false)
