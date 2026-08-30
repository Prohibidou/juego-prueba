extends CanvasLayer
class_name Notas
## Las notas de arranque: TRES carteles en fila, nunca dos a la vez. Un solo
## hueco de pantalla que cambia de contenido -imagen o texto- con un fundido
## corto entre medio, asi nunca compiten por el mismo lugar ni queda una
## pegada detras de otra.
##
## 1. "Presionar G para escapar" (imagen: nota_g.png), hasta DURACION_G
##    segundos o hasta que la puerta reviente antes -ver saltar_a_basura().
## 2. "Recolecta basura" (imagen: nota_basura.png), DURACION_BASURA segundos.
## 3. "Presionar TAB para pausar" (texto: no hay imagen para esta, se estila
##    un Label sobre un panel color papel -mismo tono y misma letra marron
##    que las otras dos- para que la secuencia se vea de una pieza),
##    DURACION_TAB segundos, salvo que el jugador ya haya abierto la pausa
##    por su cuenta -ver cancelar_tab().
##
## No sabe nada de por que se muestra ni de cuando: `mostrar()` corre la
## secuencia entera sola, en paralelo a lo que sea que haga el resto del
## juego. `saltar_a_basura()` y `cancelar_tab()` son las dos entradas que le
## abre quien la usa, para cortar una nota que ya dejo de aplicar.

@export_range(1.0, 30.0, 0.5) var DURACION_G := 10.0
@export_range(1.0, 30.0, 0.5) var DURACION_BASURA := 8.0
@export_range(1.0, 30.0, 0.5) var DURACION_TAB := 8.0
@export_range(0.05, 1.5, 0.05) var FUNDE := 0.35

enum Paso { NINGUNO, G, BASURA, TAB }

@onready var tex_g: Texture2D = preload("res://ui/nota_g.png")
@onready var tex_basura: Texture2D = preload("res://ui/nota_basura.png")
@onready var _hueco: Control = $Hueco
@onready var _imagen: TextureRect = $Hueco/Imagen
@onready var _texto: Control = $Hueco/Texto

var _paso := Paso.NINGUNO
var _tab_cancelada := false
# se invalida cualquier secuencia vieja: si saltar_a_basura() o
# cancelar_tab() cortan el paso de ahora, o mostrar() se llamara dos veces,
# los await colgados de la vuelta anterior tienen que darse por vencidos y no
# tocar nada.
var _vuelta := 0


func _ready() -> void:
	visible = false
	_hueco.modulate.a = 0.0
	_imagen.visible = false
	_texto.visible = false


## Arranca la secuencia entera. Nunca en headless: es puramente cosmetico, y
## el self-check no tiene por que esperar temporizadores reales de hasta
## DURACION_G + DURACION_BASURA + DURACION_TAB segundos.
func mostrar() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_vuelta += 1
	var propia := _vuelta
	visible = true
	await _ir_a(Paso.G)
	await _esperar(DURACION_G)
	if propia != _vuelta:
		return
	await _avanzar_a_basura(propia)


## La puerta ya revento: si todavia se ve la nota de la G, salta directo a la
## de la basura -quedarse con "escapa" puesto despues de haber escapado es
## ruido-. Si ya se paso de ahi, o la secuencia nunca arranco (headless, o
## mostrar() no se llamo), no hace nada.
func saltar_a_basura() -> void:
	if not visible or _paso != Paso.G:
		return
	_vuelta += 1
	await _avanzar_a_basura(_vuelta)


## El jugador ya abrio la pausa por su cuenta -Tab de verdad, no porque el
## cartel se lo sugiriera-: si la nota de TAB no salio todavia, que no salga
## mas adelante; si ya esta en pantalla, se apaga antes de tiempo. Se puede
## llamar aunque las notas nunca hayan arrancado (headless): no hace nada.
func cancelar_tab() -> void:
	if _tab_cancelada:
		return
	_tab_cancelada = true
	if visible and _paso == Paso.TAB:
		_vuelta += 1
		await _terminar()


func _avanzar_a_basura(propia: int) -> void:
	await _ir_a(Paso.BASURA)
	await _esperar(DURACION_BASURA)
	if propia != _vuelta:
		return
	if _tab_cancelada:
		await _terminar()
		return
	await _ir_a(Paso.TAB)
	await _esperar(DURACION_TAB)
	if propia != _vuelta:
		return
	await _terminar()


func _ir_a(paso: Paso) -> void:
	if _hueco.modulate.a > 0.0:
		await _fundir(0.0)
	_imagen.visible = paso == Paso.G or paso == Paso.BASURA
	_texto.visible = paso == Paso.TAB
	if paso == Paso.G:
		_imagen.texture = tex_g
	elif paso == Paso.BASURA:
		_imagen.texture = tex_basura
	_paso = paso
	await _fundir(1.0)


func _terminar() -> void:
	await _fundir(0.0)
	visible = false
	_paso = Paso.NINGUNO


func _fundir(alfa: float) -> void:
	# tiempo REAL: si el portazo entra en camara lenta a mitad de una nota, el
	# fundido no tiene por que estirarse con el -mismo motivo que los avisos
	# de juego.gd (_aviso). El tween se pausa solo con el arbol -pause_mode
	# por defecto-, que es lo que se quiere: leer el cartel no debe seguir
	# corriendo detras del menu de pausa.
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(_hueco, "modulate:a", alfa, FUNDE)
	await t.finished


func _esperar(seg: float) -> void:
	# process_always=false a proposito: si el jugador pausa (Tab de verdad, o
	# el cartel de como-jugar) el reloj de la nota se frena con el resto del
	# juego, no sigue corriendo detras de la pantalla de pausa hasta apagarse
	# solo -en este proyecto ya hubo dos bugs de banderas que quedaban
	# pegadas por procesar detras de una pausa (ver CLAUDE.md).
	await get_tree().create_timer(seg, false, false, true).timeout
