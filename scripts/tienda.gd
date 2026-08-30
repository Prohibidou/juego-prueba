extends Control
class_name Tienda
## La tienda: el tablero de la pared con las skins del piche.
##
## Las ocho cartas NO son ocho archivos: son ocho `AtlasTexture` recortando la
## misma lamina (`ui/skins_lamina.png`, 4x2 celdas de 384x512), asi que cambiar
## el arte es reemplazar UN png. Los recortes estan en Tienda.tscn, no aqui.
##
## Aca solo va lo que un .tscn no guarda: quien avisa a quien y el movimiento.
## Las cartas entran una detras de otra y despues se quedan meciendose.

const MENU := "res://escenas/Menu.tscn"

# En el orden de la lamina: primero la fila de arriba, izquierda a derecha.
const NOMBRES := ["Araña", "Panda", "Arcoíris", "Rey",
	"Camuflaje", "Hielo", "Lava", "Galaxia"]

# Cuanto tarda una carta en entrar, y cuanto se espera entre una y la siguiente.
@export_range(0.1, 1.0, 0.05) var entrada := 0.35
@export_range(0.0, 0.3, 0.01) var escalon := 0.07
# El vaiven de reposo: cuanto se inclina la carta y cuanto tarda la ida.
@export_range(0.0, 6.0, 0.1) var vaiven_grados := 1.6
@export_range(0.4, 6.0, 0.1) var vaiven_seg := 1.3
# El realce al pasar por encima.
@export_range(1.0, 1.3, 0.01) var realce := 1.08

@onready var _rejilla: GridContainer = $Tablero/Rejilla
@onready var _cartas: Array[Node] = _rejilla.get_children()


func _ready() -> void:
	$Volver.pressed.connect(_al_menu)
	$Volver.pivot_offset = Vector2.ZERO   # crece hacia la derecha, no al centro
	$Volver.mouse_entered.connect(func(): _realzar($Volver, true))
	$Volver.mouse_exited.connect(func(): _realzar($Volver, false))
	for i in _cartas.size():
		var carta := _cartas[i] as TextureButton
		carta.tooltip_text = NOMBRES[i]
		# el pivote se pone cuando ya hay tamano: dentro de un contenedor no se
		# sabe hasta que reparte el espacio, y sin el la escala tira del borde
		carta.resized.connect(func(): carta.pivot_offset = carta.size * 0.5)
		carta.mouse_entered.connect(func(): _realzar(carta, true))
		carta.mouse_exited.connect(func(): _realzar(carta, false))
		carta.focus_entered.connect(func(): _realzar(carta, true))
		carta.focus_exited.connect(func(): _realzar(carta, false))
		carta.pressed.connect(func(): _pendiente("%s: comprar todavia no" % NOMBRES[i]))
		carta.scale = Vector2.ZERO
		carta.modulate.a = 0.0

	await get_tree().process_frame   # la rejilla ya repartio el espacio
	_entrar()
	# el foco realza la carta, y el realce tambien va en `scale`: si se pide
	# mientras entra, los dos tweens se pisan y la primera carta se queda sin
	# realzar. Se espera a que la entrada acabe.
	await get_tree().create_timer(_lo_que_tarda_entrar()).timeout
	_cartas[0].grab_focus()          # con mando o teclado ya hay algo elegido
	await _self_check()


## Las cartas caen sobre el tablero una detras de otra, con un rebote al final,
## y cada una se queda meciendose. El escalon deja las mecidas desfasadas entre
## si sin tener que darle a cada una su propio retardo.
func _entrar() -> void:
	for i in _cartas.size():
		var carta := _cartas[i] as TextureButton
		carta.pivot_offset = carta.size * 0.5
		var t := create_tween().set_parallel()
		t.tween_property(carta, "scale", Vector2.ONE, entrada) \
			.set_delay(i * escalon).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(carta, "modulate:a", 1.0, entrada * 0.6).set_delay(i * escalon)
		t.finished.connect(_mecer.bind(carta))


## El vaiven va en `rotation` a proposito: `scale` se la queda el realce del
## raton, y dos tweens sobre la misma propiedad se pisan.
func _mecer(carta: Control) -> void:
	var g := deg_to_rad(vaiven_grados)
	var t := create_tween().set_loops()
	t.tween_property(carta, "rotation", g, vaiven_seg) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(carta, "rotation", -g, vaiven_seg) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## La ultima carta arranca en escalon * (n - 1) y tarda `entrada` en llegar.
func _lo_que_tarda_entrar() -> float:
	return escalon * (_cartas.size() - 1) + entrada


func _realzar(carta: Control, encima: bool) -> void:
	var t := create_tween().set_parallel()
	t.tween_property(carta, "modulate",
		Color(1.15, 1.12, 1.0) if encima else Color.WHITE, 0.12)
	t.tween_property(carta, "scale", Vector2.ONE * (realce if encima else 1.0), 0.12)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
		_al_menu()


func _al_menu() -> void:
	get_tree().change_scene_to_file(MENU)


## ponytail: la carta responde, pero detras no hay cobro ni skin que ponerle al
## piche. Mejor decirlo que dejarlo mudo, que parece roto.
func _pendiente(texto: String) -> void:
	$Aviso.text = texto
	$Aviso.modulate.a = 1.0
	create_tween().tween_property($Aviso, "modulate:a", 0.0, 1.6).set_delay(0.6)


func _self_check() -> void:
	assert(_cartas.size() == NOMBRES.size(),
		"el tablero tiene %d cartas y hay %d nombres" % [_cartas.size(), NOMBRES.size()])
	# cada carta recorta un trozo distinto de la lamina, y ninguno se sale
	var recortes := {}
	for i in _cartas.size():
		var atlas := (_cartas[i] as TextureButton).texture_normal as AtlasTexture
		assert(atlas != null, "la carta %s no recorta la lamina" % NOMBRES[i])
		assert(not recortes.has(atlas.region),
			"%s recorta el mismo trozo que otra carta" % NOMBRES[i])
		recortes[atlas.region] = true
		assert(Rect2(Vector2.ZERO, atlas.atlas.get_size()).encloses(atlas.region),
			"el recorte de %s se sale de la lamina" % NOMBRES[i])
	print("tienda: %d cartas de %s sobre la tabla de %s"
		% [_cartas.size(), str(_rejilla.size.round()), str($Tablero.size.round())])
	assert(_rejilla.size.x <= $Tablero.size.x and _rejilla.size.y <= $Tablero.size.y,
		"la rejilla de cartas no cabe en la tabla de la pared")

	# y despues de la entrada las cartas estan puestas, no a medio camino
	await get_tree().create_timer(_lo_que_tarda_entrar() + 0.2).timeout
	var ultima := _cartas[-1] as TextureButton
	print("tienda: la ultima carta acaba en escala %.2f y alfa %.2f"
		% [ultima.scale.x, ultima.modulate.a])
	assert(is_equal_approx(ultima.scale.x, 1.0) and is_equal_approx(ultima.modulate.a, 1.0),
		"la entrada deja las cartas a medio camino")
