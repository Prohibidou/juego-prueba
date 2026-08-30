extends CanvasLayer
class_name Pausa
## El menu de pausa: Tab congela el juego, Tab lo suelta.
##
## No sabe nada de lo que hay debajo. Congela el arbol y avisa por senal que se
## pidio reintentar o salir; que significa cada cosa lo decide quien la use.
##
## El nodo va en PROCESS_MODE_ALWAYS (puesto en la escena): con el arbol
## pausado el resto de nodos deja de procesar, y sin eso no quedaria nadie
## leyendo la tecla para despausar.
##
## Lo que se muestra y se esconde es el Control de dentro, no el CanvasLayer:
## un Control invisible tampoco recibe raton, asi que los botones no se pueden
## apretar sin querer con el menu cerrado.

## El jugador quiere volver a empezar. Quien la use decide que rebobina.
signal reintentar()
## El jugador quiere irse.
signal salir()
## Se abrio -por Tab de verdad, no porque algun cartel lo sugiriera-. La usa
## quien quiera enterarse de que el jugador ya encontro la pausa solo, sin
## que se lo digan (ver notas.gd, la nota de "Presionar TAB").
signal abierta_evento()

@export_range(0.0, 0.4, 0.01) var REALCE := 0.06      # cuanto crece el boton apuntado
@export_range(0.02, 0.6, 0.01) var REALCE_SEG := 0.12

## Mientras esta en false, Tab no hace nada. Lo enciende quien la use cuando la
## partida ya esta en marcha: pausar a media carga congelaria los temporizadores
## que estan montando el campo y la portada no se iria nunca.
var habilitada := false

@onready var _fondo: Control = $Fondo
@onready var _reintentar: TextureButton = $Fondo/Menu/Reintentar
@onready var _salir: TextureButton = $Fondo/Menu/Salir


func _ready() -> void:
	_fondo.visible = false
	_reintentar.pressed.connect(func(): _cerrar_y(reintentar))
	_salir.pressed.connect(func(): _cerrar_y(salir))
	for boton in [_reintentar, _salir]:
		# el pivote se pone cuando ya hay tamano: dentro de un contenedor no se
		# sabe hasta que reparte el espacio, y sin el la escala tira del borde
		boton.resized.connect(func(): boton.pivot_offset = boton.size * 0.5)
		boton.mouse_entered.connect(func(): _realzar(boton, true))
		boton.mouse_exited.connect(func(): _realzar(boton, false))
		boton.focus_entered.connect(func(): _realzar(boton, true))
		boton.focus_exited.connect(func(): _realzar(boton, false))


## Tab se lee en _input() y se marca consumido. En _unhandled_input() no
## llegaria: la interfaz usa Tab para saltar de un boton a otro y se lo come
## antes. Y si se dejara pasar, ademas de pausar movería el foco.
func _input(e: InputEvent) -> void:
	var t := e as InputEventKey
	if t == null or not t.pressed or t.echo or t.keycode != KEY_TAB:
		return
	get_viewport().set_input_as_handled()
	alternar()


func abierta() -> bool:
	return _fondo.visible


func alternar() -> void:
	if abierta():
		cerrar()
	elif habilitada:
		abrir()


func abrir() -> void:
	_fondo.visible = true
	get_tree().paused = true
	_reintentar.grab_focus()   # con mando o teclado ya hay algo elegido
	abierta_evento.emit()


func cerrar() -> void:
	_fondo.visible = false
	get_tree().paused = false


## Se cierra ANTES de avisar: reintentar con el arbol congelado dejaria la
## partida nueva sin correr un solo tick, y salir con la pausa puesta se
## llevaria la pausa puesta a donde sea que se vaya.
func _cerrar_y(aviso: Signal) -> void:
	cerrar()
	aviso.emit()


func _realzar(boton: TextureButton, encima: bool) -> void:
	var t := create_tween()
	# los tweens paran con el arbol, y aca hay que animar justo con el arbol
	# congelado: es el unico momento en que se ve este menu
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.set_parallel()
	t.tween_property(boton, "modulate",
		Color(1.18, 1.14, 1.0) if encima else Color.WHITE, REALCE_SEG)
	t.tween_property(boton, "scale",
		Vector2.ONE * (1.0 + REALCE if encima else 1.0), REALCE_SEG)
