extends SceneTree
## Lista lo que trae un glb de mapa: mallas, tamano y si cumple el contrato
## (una malla CAMIONETA para la meta, y opcionalmente una "jaula" de salida).
##   godot --headless --path . --script res://herramientas/ver_glb.gd -- res://ruta.glb
##
## Las transformadas se acumulan a mano: el glb se instancia fuera del arbol y
## global_transform no vale hasta que el nodo esta dentro.

const META := "CAMIONETA"
const SALIDA := "jaula"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("falta la ruta al glb")
		quit(1)
		return
	var escena := load(args[0]) as PackedScene
	if escena == null:
		print("no se pudo cargar ", args[0])
		quit(1)
		return

	var piezas: Array = []
	_juntar(escena.instantiate(), Transform3D.IDENTITY, piezas)

	var caja := AABB()
	for i in piezas.size():
		caja = piezas[i]["caja"] if i == 0 else caja.merge(piezas[i]["caja"])
	print("\n=== %s ===" % args[0].get_file())
	print("mallas: %d | triangulos: %d" % [piezas.size(),
		piezas.reduce(func(a, p): return a + p["tris"], 0)])
	print("caja en mundo: pos %s  tam %s" % [str(caja.position.round()), str(caja.size.round())])
	print("--- mallas ---")
	for p in piezas:
		var c: AABB = p["caja"]
		print("  %-34s centro %-24s tam %-20s %d tris" % [p["nombre"],
			str(c.get_center().round()), str(c.size.round()), p["tris"]])
	print("--- contrato ---")
	for nombre in [META, SALIDA]:
		var hay := piezas.filter(func(p): return p["nombre"] == nombre)
		print("  %-12s %s" % [nombre, "OK" if hay else "FALTA"])
	quit()


func _juntar(n: Node, t: Transform3D, r: Array) -> void:
	if n is Node3D:
		t = t * (n as Node3D).transform
	if n is MeshInstance3D:
		var m := n as MeshInstance3D
		var tris := 0
		for i in m.mesh.get_surface_count():
			var arr: Array = m.mesh.surface_get_arrays(i)
			var idx = arr[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else arr[Mesh.ARRAY_VERTEX].size()) / 3
		r.append({"nombre": m.name, "caja": t * m.mesh.get_aabb(), "tris": tris})
	for h in n.get_children():
		_juntar(h, t, r)
