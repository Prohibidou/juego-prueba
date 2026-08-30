extends SceneTree
## Mirar una pantalla de UI sin el MCP de Godot: la abre con render de verdad,
## espera y guarda una captura en user://ui.png. Los asserts confirman que el
## codigo CORRE, no que se VEA; esto es para lo segundo.
##
##   Godot --path . --script res://herramientas/ver_ui.gd --resolution 1280x720 \
##     -- res://escenas/Tienda.tscn 2.5
##
## El segundo argumento son los segundos de espera: bajarlo pilla la animacion
## de entrada a medias, que es como se comprueba que la animacion existe.

func _initialize() -> void:
	_correr()

func _correr() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	get_root().add_child((load(args[0]) as PackedScene).instantiate())
	await create_timer(float(args[1]) if args.size() > 1 else 2.5).timeout
	await process_frame
	var img: Image = get_root().get_texture().get_image()
	img.save_png("user://ui.png")
	print("captura en ", ProjectSettings.globalize_path("user://ui.png"))
	quit()
