extends SceneTree
## Herramienta suelta: lista las mallas del mapa con su caja, para encontrar a
## que altura esta el agua. Se corre con
##   <godot> --headless --path . -s herramientas/ver_agua.gd
## No forma parte del juego; es para mirar el modelo sin abrir el editor.


func _init() -> void:
	var mapa := (load("res://escenas/mapas/Muelle.tscn") as PackedScene).instantiate()
	var escenario: Node3D = mapa.get_node("Escenario")
	var filas: Array = []
	for m: MeshInstance3D in escenario.find_children("*", "MeshInstance3D", true, false):
		var caja: AABB = m.get_aabb()
		var t := m.global_transform if m.is_inside_tree() else _hasta_raiz(m, escenario)
		var mundo := t * caja
		filas.append({
			"nombre": m.name,
			"y0": mundo.position.y, "y1": mundo.position.y + mundo.size.y,
			"ancho": maxf(mundo.size.x, mundo.size.z),
		})
	filas.sort_custom(func(a, b): return a["ancho"] > b["ancho"])
	print("--- mallas del mapa, de mas ancha a menos (y en ejes de Muelle) ---")
	for f in filas.slice(0, 22):
		print("  %-34s y %8.2f .. %8.2f   ancho %8.1f"
			% [f["nombre"], f["y0"], f["y1"], f["ancho"]])
	print("(el nodo Escenario esta desplazado a y=%.2f en Muelle.tscn)"
		% escenario.position.y)
	quit()


func _hasta_raiz(n: Node3D, raiz: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var a := n
	while a != null and a != raiz:
		t = a.transform * t
		a = a.get_parent() as Node3D
	return raiz.transform * t
