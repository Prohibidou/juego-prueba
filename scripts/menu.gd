extends Control
## Pantalla de inicio, y escena principal del proyecto. Abre al instante porque
## no carga nada pesado; JUGAR pasa al juego, que ya se tapa a si mismo con la
## portada mientras monta el campo.

const JUEGO := "res://escenas/Juego.tscn"


func _ready() -> void:
	$Botones/Jugar.pressed.connect(func(): get_tree().change_scene_to_file(JUEGO))
	$Botones/Tienda.pressed.connect(func(): _pendiente("La tienda todavia no"))
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
