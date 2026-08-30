extends CanvasLayer
class_name Cinematica
## La cinematica de arranque: el video a pantalla completa, con su propio
## audio, salteable con cualquier tecla, clic o boton de mando.
##
## Se monta y corre sola -nadie de afuera le dice cuando arrancar-: como hijo
## de Juego, su _ready() corre ANTES que el de Juego (los hijos van primero),
## asi que para cuando juego.gd pregunta algo esto ya se decidio. Solo avisa
## hacia arriba con una senal, `terminada()`, cuando el video se vio entero o
## lo saltearon.
##
## `lista()` existe ademas de la senal porque en headless la cinematica se
## resuelve DENTRO de este mismo _ready(), antes de que juego.gd llegue
## siquiera a conectarse: sin este metodo, quien pregunte por la senal se
## quedaria esperando un aviso que ya paso.

signal terminada()

@onready var _video: VideoStreamPlayer = $Video

var _hecha := false


func _ready() -> void:
	# ponytail: en headless no hay pantalla que mostrar, y el self-check de
	# juego.gd (que corre con --quit-after de unos segundos) no puede quedarse
	# 23 s esperando el video: se da por vista de entrada, sin reproducir
	# nada. Sincrono, antes de que nadie llegue a preguntar lista() o a
	# conectarse a terminada().
	if DisplayServer.get_name() == "headless":
		_hecha = true
		visible = false
		return
	_video.finished.connect(_terminar)
	_video.play()


## Se lee con _input(), no _unhandled_input(): igual que Tab en pausa.gd, si
## el click cae sobre el VideoStreamPlayer (un Control a pantalla completa)
## el sistema de GUI se lo come antes de que _unhandled_input lo vea.
func _input(e: InputEvent) -> void:
	if _hecha:
		return
	if (e is InputEventKey and e.pressed and not e.echo) \
			or (e is InputEventMouseButton and e.pressed) \
			or (e is InputEventJoypadButton and e.pressed):
		get_viewport().set_input_as_handled()
		_video.stop()
		_terminar()


## Si ya se resolvio -sea porque termino, la saltearon, o estamos en
## headless- sin tener que esperar la senal.
func lista() -> bool:
	return _hecha


func _terminar() -> void:
	if _hecha:
		return
	_hecha = true
	visible = false
	terminada.emit()
