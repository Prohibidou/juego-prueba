extends Control
## Pantalla de inicio, y escena principal del proyecto. Abre al instante porque
## no carga nada pesado; JUGAR pasa al juego, que ya se tapa a si mismo con la
## portada mientras monta el mapa.

const JUEGO := "res://escenas/Juego.tscn"
const TIENDA := "res://escenas/Tienda.tscn"

## Lo que se espera desde el clic hasta cambiar de escena. Cambiar de escena
## libera esta -el nodo de sonido incluido-, asi que sin esta pausa JUGAR y
## TIENDA sonaban un fotograma y se cortaban; AJUSTES, que no cambia de
## escena, no la necesita. Es corto a proposito; de aqui para arriba se
## empieza a notar como boton que no responde.
@export_range(0.0, 0.6, 0.01) var ESPERA_CLIC := 0.18


@onready var sonido: Sonido = $Sonido
var _yendo := false          # ya se apreto JUGAR: no encolar otro cambio de escena


func _ready() -> void:
	sonido.musica(true)
	sonido.ambiente(true)
	$Botones/Jugar.pressed.connect(func(): _jugar())
	# ponytail: atajo de desarrollo para entrar directo a un mapa sin jugarse
	# los anteriores. Se esconde solo en el build exportado, asi que no hay que
	# acordarse de sacarlo antes de publicar.
	$Debug.visible = OS.is_debug_build()
	$Debug.pressed.connect(func(): _jugar(1))
	$Botones/Tienda.pressed.connect(_ir.bind(TIENDA))
	$Botones/Ajustes.pressed.connect(func(): _pendiente("Los ajustes todavia no"))

	for b in $Botones.get_children():
		var boton := b as TextureButton
		# el clic va en pressed de cada boton y no dentro de las lambdas de
		# arriba: asi suena tambien el que todavia no lleva a ningun lado
		boton.pressed.connect(sonido.boton)
		# el pivote se pone cuando ya hay tamano: dentro de un contenedor no se
		# sabe hasta que reparte el espacio, y sin el la escala tira del borde
		boton.resized.connect(func(): boton.pivot_offset = boton.size * 0.5)
		boton.mouse_entered.connect(func(): _realzar(boton, true))
		boton.mouse_exited.connect(func(): _realzar(boton, false))
		boton.focus_entered.connect(func(): _realzar(boton, true))
		boton.focus_exited.connect(func(): _realzar(boton, false))
	$Botones/Jugar.grab_focus()   # con mando o teclado ya hay algo elegido


## `mapa` es el indice en la lista `mapas` de Juego.tscn: 0 el muelle, 1 el cerro.
func _jugar(mapa := 0) -> void:
	Juego.mapa_inicial = mapa
	await _ir(JUEGO)


## Deja sonar el clic y recien ahi cambia de escena; ver ESPERA_CLIC. El pestillo
## es para que aporrear el boton no encole dos cambios de escena. Sirve para
## JUGAR y para TIENDA: los dos salen de esta pantalla y se llevan el sonido.
func _ir(escena: String) -> void:
	if _yendo:
		return
	_yendo = true
	await get_tree().create_timer(ESPERA_CLIC).timeout
	get_tree().change_scene_to_file(escena)


func _realzar(boton: TextureButton, encima: bool) -> void:
	var t := create_tween().set_parallel()
	t.tween_property(boton, "modulate",
		Color(1.15, 1.12, 1.0) if encima else Color.WHITE, 0.12)
	t.tween_property(boton, "scale", Vector2.ONE * (1.05 if encima else 1.0), 0.12)


## ponytail: el boton existe y responde, pero detras no hay nada todavia. Mejor
## decirlo que dejarlo mudo, que parece roto.
func _pendiente(texto: String) -> void:
	$Aviso.text = texto
	$Aviso.modulate.a = 1.0
	create_tween().tween_property($Aviso, "modulate:a", 0.0, 1.6).set_delay(0.6)
