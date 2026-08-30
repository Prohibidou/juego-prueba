extends Control
## Pantalla de inicio, y escena principal del proyecto. Abre al instante porque
## no carga nada pesado; JUGAR pasa al juego, que ya se tapa a si mismo con la
## portada mientras monta el mapa.

const JUEGO := "res://escenas/Juego.tscn"
const TIENDA := "res://escenas/Tienda.tscn"


func _ready() -> void:
	$Botones/Jugar.pressed.connect(func(): _jugar())
	# ponytail: atajo de desarrollo para entrar directo a un mapa sin jugarse
	# los anteriores. Se esconde solo en el build exportado, asi que no hay que
	# acordarse de sacarlo antes de publicar.
	$Debug.visible = OS.is_debug_build()
	$Debug.pressed.connect(func(): _jugar(1))
	$Botones/Tienda.pressed.connect(func(): get_tree().change_scene_to_file(TIENDA))
	$Botones/Ajustes.pressed.connect(func(): _pendiente("Los ajustes todavia no"))

	for b in $Botones.get_children():
		var boton := b as TextureButton
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
	get_tree().change_scene_to_file(JUEGO)


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
