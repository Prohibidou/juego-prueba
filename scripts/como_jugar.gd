extends CanvasLayer
class_name ComoJugar
## El cartel de "como jugar": WASD, espacio y G explicados en un cartel, una
## sola vez por partida, arriba del barco antes de arrancar a jugar de verdad.
##
## No sabe quien la muestra ni por que: solo se anuncia con una senal
## (`cerrada`) cuando se cierra. Mientras esta puesta pausa el arbol -mismo
## truco que escenas/Pausa.tscn-, y por eso el nodo raiz va en
## PROCESS_MODE_ALWAYS (puesto en la escena): con el arbol pausado, sin eso ni
## el boton ni esta tecla seguirian vivos para cerrarla.

signal cerrada()

@onready var _cerrar: TextureButton = $Fondo/Cerrar


func _ready() -> void:
	visible = false
	_cerrar.pressed.connect(_cerrar_cartel)


## Se lee con _input(), no _unhandled_input(): el mismo motivo que Tab en
## pausa.gd -un click sobre el fondo o la imagen (Controles a pantalla
## completa) lo consumiria la GUI antes de llegar a _unhandled_input. El boton
## Cerrar sigue conectado ademas por su propia senal: en pantalla tactil el
## toque llega como InputEventScreenTouch, que esto no mira, y tiene que poder
## cerrarla igual.
func _input(e: InputEvent) -> void:
	if not visible:
		return
	if (e is InputEventKey and e.pressed and not e.echo) \
			or (e is InputEventMouseButton and e.pressed) \
			or (e is InputEventJoypadButton and e.pressed):
		get_viewport().set_input_as_handled()
		_cerrar_cartel()


func _cerrar_cartel() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	cerrada.emit()


## La usa quien la instancia: la muestra, pausa el juego, y espera a que se
## cierre -boton, tecla, clic o toque-. Nunca en headless: el self-check mueve
## el piche de verdad con el arbol corriendo, y pausarlo esperando un click
## que no va a llegar lo dejaria colgado para siempre.
func mostrar() -> void:
	if DisplayServer.get_name() == "headless":
		return
	visible = true
	get_tree().paused = true
	await cerrada
