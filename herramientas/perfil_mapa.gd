extends SceneTree
## Perfil de alturas de un mapa: monta la escena de verdad y tira rayos en
## rejilla, para poder elegir a ojo donde va la salida.
##
## Usa altura_terreno (primer choque), que es con lo que el juego apoya al
## piche. NO altura_suelo: esa pela capas hacia abajo y se mete por DEBAJO de
## un camino elevado o un techo, devolviendo el terreno de abajo.
##   godot --headless --path . --script res://herramientas/perfil_mapa.gd -- res://escenas/mapas/Cerro.tscn

func _initialize() -> void:
	_correr()

func _correr() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var mapa: Node3D = (load(args[0]) as PackedScene).instantiate()
	get_root().add_child(mapa)
	await mapa.preparar()

	var caja: AABB = mapa.call("_aabb", mapa.get_node("Escenario"))
	if args.size() >= 5:   # x0 x1 z0 z1 para afinar una zona
		caja = AABB(Vector3(float(args[1]), caja.position.y, float(args[3])),
			Vector3(float(args[2]) - float(args[1]), caja.size.y,
				float(args[4]) - float(args[3])))
	print("caja: pos %s tam %s" % [str(caja.position.round()), str(caja.size.round())])
	var pasos := 14
	var linea := "        "
	for j in pasos:
		linea += "%6d" % roundi(caja.position.z + caja.size.z * j / (pasos - 1.0))
	print("z ->" + linea)
	for i in pasos:
		var x := caja.position.x + caja.size.x * i / (pasos - 1.0)
		var fila := "x%7d" % roundi(x)
		for j in pasos:
			var z := caja.position.z + caja.size.z * j / (pasos - 1.0)
			var y: float = mapa.altura_terreno(x, z)
			fila += "%6s" % ("  -  " if is_nan(y) else str(roundi(y)))
		print(fila)
	quit()
