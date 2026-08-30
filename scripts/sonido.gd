extends Node
class_name Sonido
## Todo lo que suena, en una sola escena: musica, ambiente y efectos.
##
## No sabe nada del juego. Se le llama hacia abajo -`sonido.impulso(0.8)`- y el
## decide con que reproductor, a que volumen y con que tono. Quien la use no
## toca un AudioStreamPlayer nunca ni se entera de cuantos hay.
##
## Los reproductores viven en `Sonido.tscn`, no se crean en `_ready`: son nodos
## fijos con propiedades fijas -bus, stream, volumen de base- y eso es
## composicion, o sea escena. Aca solo queda lo que depende de correr: cuanto
## corre el piche, si esta en el aire, si hay camara lenta.
##
## El volumen DE BASE de cada clip se toca en el Inspector, en su nodo. Lo que
## esta aca son los RANGOS con los que ese volumen se mueve en juego.

const BUS_MUSICA := "Musica"
const BUS_EFECTOS := "Efectos"
const BUS_AMBIENTE := "Ambiente"

@export_group("Musica")
@export_range(0.0, 8.0, 0.1) var FUNDE_ENTRA := 2.5   # segundos de entrada
@export_range(0.0, 8.0, 0.1) var FUNDE_SALE := 1.2
## Cuanto se aparta la musica cuando pasa algo gordo (el portazo), y cuanto tarda
## en volver. Sin esto el momento del portazo se pelea con el charango.
@export_range(-40.0, 0.0, 0.5) var APARTA_DB := -9.0
@export_range(0.05, 3.0, 0.05) var APARTA_BAJA := 0.15
@export_range(0.1, 6.0, 0.1) var APARTA_SUBE := 1.8

@export_group("Vuelo")
## El giro en el aire suena en bucle mientras el piche vuela, mas fuerte y mas
## agudo cuanto mas rapido va. Por debajo de VUELO_MIN no suena nada.
@export_range(0.0, 40.0, 0.5) var VUELO_MIN := 6.0     # m/s
@export_range(1.0, 60.0, 0.5) var VUELO_MAX := 26.0    # va con VEL_MAX de impulso.gd
@export_range(-60.0, 0.0, 0.5) var VUELO_DB_MIN := -26.0
@export_range(-30.0, 12.0, 0.5) var VUELO_DB_MAX := 0.0
@export_range(0.2, 2.0, 0.01) var VUELO_TONO_MIN := 0.82
@export_range(0.2, 3.0, 0.01) var VUELO_TONO_MAX := 1.30
@export_range(0.5, 30.0, 0.5) var VUELO_SUAVIZA := 8.0  # para que no salte de golpe

@export_group("Impacto")
## El aterrizaje suena segun con cuanta velocidad se llega: un putt que rueda no
## puede sonar igual que caer de un impulso a 26 m/s.
@export_range(0.0, 40.0, 0.5) var CAIDA_MIN := 4.0     # por debajo, ni suena
@export_range(1.0, 60.0, 0.5) var CAIDA_MAX := 30.0
@export_range(-60.0, 0.0, 0.5) var CAIDA_DB_MIN := -20.0
@export_range(-30.0, 12.0, 0.5) var CAIDA_DB_MAX := 0.0
@export_range(0.2, 2.0, 0.01) var CAIDA_TONO_MIN := 1.15   # flojo: mas agudo y chico
@export_range(0.2, 2.0, 0.01) var CAIDA_TONO_MAX := 0.88

@export_group("Impulso")
## Con la barra a tope el grunido es mas grave y mas fuerte: es mas esfuerzo.
@export_range(-40.0, 12.0, 0.5) var IMPULSO_DB_MIN := -9.0
@export_range(-40.0, 12.0, 0.5) var IMPULSO_DB_MAX := 0.0
@export_range(0.2, 2.0, 0.01) var IMPULSO_TONO_MIN := 1.18
@export_range(0.2, 2.0, 0.01) var IMPULSO_TONO_MAX := 0.92

@export_group("Varios")
## La basura no trae sonido propio: se usa el del boton, subido de tono, que es
## el "tin" de recoger de toda la vida. Marcado a proposito, no es un descuido.
@export_range(0.5, 3.0, 0.01) var RECOGER_TONO := 1.6
@export_range(-40.0, 12.0, 0.5) var RECOGER_DB := -8.0
## Con camara lenta los efectos se estiran con ella. Sin esto, la puerta vuela
## a camara lenta y el golpe suena a velocidad normal: parecen dos escenas.
@export var SIGUE_CAMARA_LENTA := true
@export_range(0.1, 1.0, 0.01) var TONO_LENTO_MIN := 0.55

@onready var _musica: AudioStreamPlayer = $Musica
@onready var _olas: AudioStreamPlayer = $Olas
@onready var _gaviotas: AudioStreamPlayer = $Gaviotas
@onready var _vuelo: AudioStreamPlayer = $Vuelo
@onready var _impulso: AudioStreamPlayer = $Impulso
@onready var _salto: AudioStreamPlayer = $Salto
@onready var _aterrizaje: AudioStreamPlayer = $Aterrizaje
@onready var _jaula: AudioStreamPlayer = $Jaula
@onready var _chapuzon: AudioStreamPlayer = $Chapuzon
@onready var _boton: AudioStreamPlayer = $Boton

# El volumen que trae cada nodo de la escena es el TECHO: lo que se toca en el
# Inspector. Todo lo que hace este script se mueve por debajo de el, en relativo,
# para que subir un clip en el editor siga funcionando.
var _db_musica := 0.0
var _db_vuelo := 0.0
var _db_aterrizaje := 0.0
var _db_impulso := 0.0
var _db_boton := 0.0
var _vuelo_actual := 0.0     # 0..1 suavizado, para que el bucle no escalone
var _funde: Tween
var _aparta: Tween
# Cuantas veces se pidio cada cosa. Es para las comprobaciones: que los
# recursos carguen no dice que el juego los LLAME, y un enganche que se
# pierde en un refactor deja el juego mudo sin romper nada.
var _disparos := {}


func _ready() -> void:
	_db_musica = _musica.volume_db
	_db_vuelo = _vuelo.volume_db
	_db_aterrizaje = _aterrizaje.volume_db
	_db_impulso = _impulso.volume_db
	_db_boton = _boton.volume_db
	_musica.volume_db = -80.0     # entra fundiendo, no de un portazo


## Enciende o apaga la musica con un fundido. Los tweens corren en tiempo de
## juego y `Engine.time_scale` los escala: en pleno portazo (time_scale 0.18) un
## fundido de 2.5 s duraba catorce. De ahi el ignore_time_scale.
func musica(encendida: bool) -> void:
	if _funde and _funde.is_valid():
		_funde.kill()
	if encendida and not _musica.playing:
		_musica.play()
	_funde = create_tween().set_ignore_time_scale(true)
	_funde.tween_property(_musica, "volume_db",
		_db_musica if encendida else -80.0,
		FUNDE_ENTRA if encendida else FUNDE_SALE)
	if not encendida:
		_funde.tween_callback(_musica.stop)


## El mar y las gaviotas. Van en su propio bus para poder bajarlos juntos.
func ambiente(encendido: bool) -> void:
	for p in [_olas, _gaviotas]:
		if encendido and not p.playing:
			p.play()
		elif not encendido:
			p.stop()


## Baja la musica un momento para que se oiga lo que esta pasando. Se usa en el
## portazo, que es el unico momento con guion propio.
func apartar_musica() -> void:
	if _aparta and _aparta.is_valid():
		_aparta.kill()
	_aparta = create_tween().set_ignore_time_scale(true)
	_aparta.tween_property(_musica, "volume_db", _db_musica + APARTA_DB, APARTA_BAJA)
	_aparta.tween_property(_musica, "volume_db", _db_musica, APARTA_SUBE) \
		.set_delay(0.9).set_trans(Tween.TRANS_SINE)


## El impulso (G). `fuerza` es la barra, 0..1.
func impulso(fuerza: float) -> void:
	_contar("impulso")
	_impulso.volume_db = _db_impulso + lerpf(IMPULSO_DB_MIN, IMPULSO_DB_MAX, fuerza)
	_impulso.pitch_scale = _lento(lerpf(IMPULSO_TONO_MIN, IMPULSO_TONO_MAX, fuerza))
	_impulso.play()


## El brinco. El stream es un AudioStreamRandomizer con las tres tomas del pack
## original, asi que la variacion la pone la escena y no este script.
func salto() -> void:
	_contar("salto")
	_salto.pitch_scale = _lento(1.0)
	_salto.play()


## Tocar suelo. Por debajo de CAIDA_MIN no suena: rodar no es aterrizar.
func aterrizaje(velocidad: float) -> void:
	if velocidad < CAIDA_MIN:
		return
	_contar("aterrizaje")
	var k := clampf(inverse_lerp(CAIDA_MIN, CAIDA_MAX, velocidad), 0.0, 1.0)
	_aterrizaje.volume_db = _db_aterrizaje + lerpf(CAIDA_DB_MIN, CAIDA_DB_MAX, k)
	_aterrizaje.pitch_scale = _lento(lerpf(CAIDA_TONO_MIN, CAIDA_TONO_MAX, k))
	_aterrizaje.play()


## El bucle de giro en el aire. Se llama TODOS los fotogramas con la velocidad
## de ahora, y con 0 cuando el piche no vuela: asi no hay bandera que se quede
## pegada si quien llama corta antes con un return.
func vuelo(velocidad: float, dt := 0.0) -> void:
	var meta := clampf(inverse_lerp(VUELO_MIN, VUELO_MAX, velocidad), 0.0, 1.0)
	# suavizado por tiempo, no por fotograma: si no, depende de los fps
	_vuelo_actual = (meta if dt <= 0.0
		else lerpf(_vuelo_actual, meta, 1.0 - exp(-VUELO_SUAVIZA * dt)))
	if _vuelo_actual < 0.02:
		if _vuelo.playing:
			_vuelo.stop()
		return
	if not _vuelo.playing:
		_contar("vuelo")
		_vuelo.play()
	_vuelo.volume_db = _db_vuelo + lerpf(VUELO_DB_MIN, VUELO_DB_MAX, _vuelo_actual)
	_vuelo.pitch_scale = _lento(
		lerpf(VUELO_TONO_MIN, VUELO_TONO_MAX, _vuelo_actual))


## La puerta de la jaula reventada. Aparta la musica sola: es el momento.
func portazo() -> void:
	_contar("portazo")
	_jaula.pitch_scale = _lento(1.0)
	_jaula.play()
	apartar_musica()


## Se cayo del muelle.
func chapuzon() -> void:
	_contar("chapuzon")
	_chapuzon.pitch_scale = _lento(1.0)
	_chapuzon.play()


## Un boton de la interfaz.
func boton() -> void:
	_contar("boton")
	_boton.volume_db = _db_boton
	_boton.pitch_scale = 1.0
	_boton.play()


## Recoger basura. Es el sonido del boton subido de tono; ver RECOGER_TONO.
func recoger() -> void:
	_contar("recoger")
	_boton.volume_db = _db_boton + RECOGER_DB
	_boton.pitch_scale = RECOGER_TONO
	_boton.play()


## Corta todo lo que este sonando en bucle por efectos. Se llama al recolocar el
## piche: si no, el giro en el aire seguia sonando con el piche ya quieto.
func callar() -> void:
	_vuelo.stop()
	_vuelo_actual = 0.0


## El tono sigue a la camara lenta, con suelo: a time_scale 0.18 sin tope todo
## sonaba a cinta arrastrada.
func _lento(tono: float) -> float:
	if not SIGUE_CAMARA_LENTA:
		return tono
	return tono * maxf(float(Engine.time_scale), TONO_LENTO_MIN)


func _contar(que: String) -> void:
	_disparos[que] = int(_disparos.get(que, 0)) + 1


## Cuantas veces se ha pedido un sonido desde que arranco. Lo usan las
## comprobaciones para saber si el juego llama de verdad a lo que tiene enganchado.
func disparos(que: String) -> int:
	return int(_disparos.get(que, 0))


## Que este todo cargado y enrutado. Lo llama el _self_check() de juego.gd.
## Devuelve la lista de problemas: vacia es que esta bien.
func revisar() -> Array[String]:
	var males: Array[String] = []
	for bus in [BUS_MUSICA, BUS_EFECTOS, BUS_AMBIENTE]:
		if AudioServer.get_bus_index(bus) < 0:
			males.append("falta el bus %s" % bus)
	for hijo in get_children():
		var p := hijo as AudioStreamPlayer
		if p == null:
			males.append("%s no es un AudioStreamPlayer" % hijo.name)
		elif p.stream == null:
			males.append("%s se quedo sin stream" % hijo.name)
	return males
