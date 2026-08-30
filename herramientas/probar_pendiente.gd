extends SceneTree
## Caer en una pendiente y poder moverse.
##
##   godot --headless --path . --script res://herramientas/probar_pendiente.gd
##
## Regresion de un bug viejo de cuando esto era golf: habia que esperar a que
## el piche se detuviera solo para recuperar el control, y en una ladera eso
## podia no pasar nunca -27 s rodando cuesta abajo sin poder hacer nada-.
##
## Se miden dos cosas por ladera:
##   SIN MANDO  cuanto rueda si no tocas nada. Puede ser largo, es el rebote
##              normal del impulso, y esta bien que lo sea.
##   CON MANDO  cuanto tarda en obedecer desde que apretas W. Tiene que ser
##              inmediato: decimas de segundo. Si sube, el jugador volvio a
##              quedar esperando a que la fisica termine.

func _initialize() -> void:
	_correr()


func _tecla(codigo: Key, apretada: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = codigo
	e.pressed = apretada
	Input.parse_input_event(e)


func _soltar_en(j: Node, m: Node, xz: Vector2) -> void:
	var piche: RigidBody3D = j.get("piche")
	var y: float = m.altura_terreno(xz.x, xz.y)
	piche.freeze = false
	piche.global_position = Vector3(xz.x, y + 0.3, xz.y)
	piche.linear_velocity = m._cuesta_abajo(xz.x, xz.y) * 9.0
	piche.angular_velocity = Vector3.ZERO
	j.set("quieto", false)
	j.set("_t_lento", 0.0)
	j.set("_t_caida", 0.0)
	j.set("_en_aire", false)


func _correr() -> void:
	await process_frame
	Juego.mapa_inicial = 1
	var j: Node = (load("res://escenas/Juego.tscn") as PackedScene).instantiate()
	get_root().add_child(j)
	while not j.get("listo"):
		await process_frame
	var m = j.get("mapa")
	for xz in [Vector2(500, 1520), Vector2(470, 1560)]:
		# --- sin tocar nada: rueda lo que tenga que rodar ---
		_soltar_en(j, m, xz)
		var n := 0
		while not j.get("quieto") and n < 600:
			await physics_frame
			n += 1
		var libre := n / 60.0
		var corto := n >= 600

		# --- apretando W a los 0.4 s ---
		_soltar_en(j, m, xz)
		for i in 24:
			await physics_frame
		_tecla(KEY_W, true)
		var t0 := Time.get_ticks_msec()
		n = 0
		while not j.get("quieto") and n < 600:
			await physics_frame
			n += 1
		var obedece := (Time.get_ticks_msec() - t0) / 1000.0
		_tecla(KEY_W, false)
		await physics_frame
		print("  ladera (%d,%d):  SIN MANDO %6.2f s%s   |   CON MANDO obedece en %.2f s"
			% [xz.x, xz.y, libre, "+ (sigue rodando)" if corto else "", obedece])
	quit()
