extends Node3D
class_name Mapa
## El mapa que recorre el piche: un escenario real por fotogrametria (hoy el
## muelle) con su punto de salida y su meta.
##
## La malla trae su propio relieve, edificios y barcos, asi que aqui no se
## genera nada: solo se le pone colision, se sacan alturas por rayo, se ubica
## la salida sobre la jaula del modelo y se busca la camioneta, que es la meta.
##
## Para ver el mapa desde arriba y situar cosas: herramientas/VerMapa.tscn.

# La foto aerea del mapa viejo venia con la luz horneada y habia que
# desactivarle el sombreado (si no, los arboles salian casi negros). El
# muelle es un modelo normal con sus propios mapas de normal: sombrearlo es
# lo correcto, asi que esto queda en false.
const FOTO_AEREA := false

# La basura viene como un escaparate de Sketchfab: cuarenta y pico piezas
# sueltas (latas, cajas, ladrillos) repartidas sobre un plano. Se usan de
# molde, se duplican y se siembran por el camino de la salida a la meta.
const BASURA := "res://modelos/trash_and_debris.glb"
const BASURAS := 16            # piezas por nivel
# Un cuarto de los moldes del escaparate son laminas de espesor casi cero
# (papeles, calcos, latas pisadas): a ras del piso hacen z-fighting con el
# suelo (el flickering del playtest). Solo se siembran piezas con volumen.
@export var MOLDE_MIN := 0.05  # metros del lado mas fino que se acepta

# medidas reales de golf
# --- la meta: subirse a la camioneta ---
const META := "CAMIONETA"      # nombre de la malla dentro del glb del mapa
# Y la de la salida. Si el glb la trae, el piche arranca encerrado ahi y va la
# cinematica del portazo; si no, arranca de pie en el marcador Salida.
const JAULA := "jaula"
const MARGEN_META := 0.35      # fraccion del ancho que cuenta como "encima"
# A partir de que altura de su caja se considera que estas ARRIBA. Medido con
# rayos sobre la camioneta del muelle: el piso de la caja esta a 0.39 de su
# alto y el techo de la cabina a 1.0, mientras que las ruedas apoyan en 0. Con
# 0.45 solo valia subirse al techo; con esto vale la caja, que es donde se
# sube, y sigue sin valer meterse debajo del chasis.
const ALTURA_CAJA := 0.28
# --- el mar ---
# El glb del muelle trae una malla llamada asi, de 700 m de lado. Como todo
# el mapa, se le genera colision: el piche no se hunde, cae ENCIMA del agua.
# La altura se mide de su caja al montar el campo, no se clava a mano. Y OJO:
# no vale para saber si algo esta mojado, porque el muelle esta construido a
# nivel del agua -la salida sale a y=164.74 y el mar tambien-: para eso esta
# hay_agua(), que mira que malla devuelve el rayo.
const MAR := "Mar"             # nombre de la malla dentro del glb del mapa
const VEL_SUBIDO := 6.0        # m/s por encima de los cuales va de paso
# ---------------------------------------
# Pieza provisional: es una escena para poder cambiarla por el modelo bueno
# arrastrandolo encima, cosa que con un MeshInstance3D hecho a mano no se puede.
const ANIMAL := "res://escenas/piezas/Animal.tscn"
const ROCA := "res://escenas/piezas/Roca.tscn"
# Radio libre alrededor del piche donde no se suelta ninguna piedra.
const ROCA_SEGURO := 12.0
const COLOR_ANIMAL := Color(0.85, 0.82, 0.78)   # para el reventon al aturdirlo
const RADIO_BASURA := 22.0     # cuanto se aparta la basura del camino a la meta

const TECHO := 300.0           # desde donde se lanzan los rayos de altura
const SUELO := -80.0
# ...pero 300 se queda CORTO: el mapa del muelle mide 366 m de alto, asi que
# bajo los mastiles y las gruas mas altas el rayo arrancaba DENTRO de la
# geometria, y un rayo no cuenta lo que ya lo envuelve (hit_from_inside viene
# en false): la altura salia mal justo donde se coloca a ciegas. El techo de
# verdad se saca de la caja del mapa en preparar(); TECHO queda de arranque.
const MARGEN_TECHO := 10.0
# Cuanto puede hundirse una siembra respecto del camino salida-meta antes de
# darla por caida al mar o a la bodega por uno de los huecos del casco.
const HUNDIDO := 8.0
const INTENTOS_SIEMBRA := 6    # tiros de dado por pieza antes de rendirse
# Por debajo de esto ya es el mar (su superficie esta en 164.74) o la bodega
# baja del barco: no hay vuelta caminando. Lo caminable mas bajo son las
# plataformas del mar, con el tope en 165.2.
@export var NIVEL_PERDIDO := 165.0

# Constante por mapa y solo en vuelo. Se setea por escena en el Inspector, que
# es donde se ve el mapa al que pertenece; antes vivia en una tabla paralela.
@export var viento := Vector3(1.0, 0, -0.5)

@export_group("Desprendimiento")
## Segundos entre piedra y piedra. En 0 no se desprende ninguna: un mapa sin
## cerro encima no tiene de donde tirarlas.
@export_range(0.0, 20.0, 0.25) var rocas_cada := 0.0
## De que tamano salen. Distintas a proposito: una de 40 cm se esquiva y una de
## 3 m hay que verla venir.
@export_range(0.2, 5.0, 0.1) var roca_min := 0.4
@export_range(0.2, 6.0, 0.1) var roca_max := 2.4
## Cuanto se reparten alrededor del punto de suelta, para que no caigan todas
## por la misma linea.
@export_range(0.0, 60.0, 1.0) var roca_dispersa := 18.0
## Empujon inicial ladera abajo. Sin el se quedan quietas en una cima plana.
@export_range(0.0, 20.0, 0.5) var roca_empuje := 4.0
## A cuantos metros por debajo del punto de suelta se dan por perdidas.
@export_range(10.0, 400.0, 5.0) var roca_muere := 90.0

var excluir: Array[RID] = []   # el piche, para que no la pisen los rayos
var _rids_mar: Array[RID] = []   # los cuerpos del agua: ahi no se siembra

var _escenario: Node3D
var _salida := Vector3.ZERO
# La meta es SUBIRSE A LA CAMIONETA que trae el mapa: se busca su malla al
# montar el escenario y se guarda su caja en coordenadas de mundo. Un mapa sin
# camioneta no tiene meta: se avisa por consola y no se puede terminar.
var _meta := AABB()
# Como dejo el glb su malla "jaula" en el mundo: sitio Y giro. Ahi va el salida y
# ahi se planta la jaula de verdad, sin tocarle ni la altura ni la orientacion.
# Vale IDENTITY si el mapa no trae ninguna.
var _jaula_mapa := Transform3D.IDENTITY
# El punto al que hay que llegar: el techo de la caja de la camioneta. Es lo
# que mira la camara, lo que mide el HUD y hacia donde apunta la salida.
var _punto_meta := Vector3.ZERO
var _mar := NAN                 # altura de la superficie del agua; NAN si el mapa no trae mar
var _techo := TECHO             # el de verdad lo mide preparar() con la caja del mapa
var animales: Array = []
var basura: Array = []
var rocas: Array = []
# La camioneta que se va, si el mapa la trae. Cuando esta, ELLA es la meta: se
# le pide su caja cada vez, porque se mueve.
var _camioneta: Camioneta
var _t_roca := 0.0

var _moldes: Array[MeshInstance3D] = []


## Monta el mapa. Hay que esperarlo: la colision no existe hasta que la fisica
## ha corrido un fotograma, y sin ella los rayos de altura no devuelven nada.
func preparar() -> void:
	# El mapa esta instanciado y recentrado en mapas/Muelle.tscn (esquina del mapa en
	# el origen): moverlo, escalarlo o cambiarlo se hace ahi, arrastrando.
	_escenario = $Escenario

	# La "jaula" que trae el modelo es una malla hueca: bonita de lejos, pero
	# el piche de 4 cm se le cuela entre los barrotes y no tiene puerta que
	# tirar. Se la quita y en su MISMO sitio se planta la jaula de verdad, con
	# muros macizos y puerta (_montar_jaula() en juego.gd, sobre la salida). Se
	# hace aca porque un nodo de dentro de una instancia no se puede borrar en
	# el editor. El sitio se copia al marcador Salida antes de borrarla: asi el
	# salida sigue a la jaula si el artista la mueve en el glb.
	var marcador := _escenario.find_child(JAULA, true, false)
	if marcador is Node3D:
		_jaula_mapa = (marcador as Node3D).global_transform
		$Salida.global_transform = _jaula_mapa
		marcador.queue_free()
	elif $Salida.position.is_zero_approx():
		# Sin jaula en el glb el piche arranca en el marcador Salida, a pie y
		# sin cinematica; pero si nadie lo movio, arrancaria en el origen.
		push_error("%s: no trae malla '%s' ni tiene el marcador Salida colocado"
			% [name, JAULA])
	await get_tree().process_frame   # que el marcador se haya ido antes de colisionar

	# ponytail: la colision se genera en cada arranque y son varios segundos
	# (por eso hay portada de carga). El techo se sube pasando las formas al
	# importador del glb (_subresources/generate/physics), pero el casco del
	# barco esta afinado a mano aca abajo y el importador no expone esos
	# ajustes: mover eso es una sesion entera, no un renglon.
	# El mapa ya viene recentrado desde mapas/Muelle.tscn, asi que aca no se toca su
	# position: solo se mide la caja para saber hasta donde llega lo mas alto
	# (mastiles, gruas) y subir el techo de los rayos por encima de eso.
	var caja := _aabb(_escenario)
	_techo = caja.position.y + caja.size.y + MARGEN_TECHO

	var n := 0
	for m: MeshInstance3D in _mallas(_escenario):
		if m.name == MAR:
			# la superficie es el TECHO de su caja: la malla del agua tiene
			# espesor y el piche se posa arriba, no en el medio
			var cm: AABB = m.global_transform * m.get_aabb()
			_mar = cm.position.y + cm.size.y
		# El barco tambien va con trimesh. Se probo descomponerlo en cascos
		# convexos (V-HACD, 32 cascos) por miedo a que el piche atravesara el
		# casco fino, pero un convexo no puede tener huecos: los cascos
		# rellenaban las concavidades del barco y eso metia COLISION DONDE NO
		# SE VE NADA -un muro invisible a 3 m del salida camino a la meta (49
		# celdas fantasma en la linea de juego, medidas a rayos), y la
		# cubierta solida un metro por encima de la que se dibuja, con el
		# piche flotando. Del tunelado por el casco fino se encarga Jolt con
		# el continuous_cd de el piche: en 36 tiros de barrido no atraveso ni
		# una vez. OJO: trimesh aqui exige la tapa de la jaula hundida bajo
		# el piso (Jaula.tscn): sobre la cubierta real, irregular, el piche se
		# colaba por la rendija entre tapa y suelo y "la puerta no paraba".
		m.create_trimesh_collision()
		if m.name == "Mar":
			for cuerpo in m.get_children():
				if cuerpo is StaticBody3D:
					_rids_mar.append((cuerpo as StaticBody3D).get_rid())
		# Un trimesh choca solo por el lado de las normales (backface_collision
		# arranca en false, y desde Godot 4.5 Jolt lo respeta de verdad). Medio
		# mapa esta modelado a una cara -galpones, silos, el casco-, asi que la
		# piche atravesaba esas paredes al pegarles "desde atras", y el CCD no
		# la salva porque su cast respeta el mismo flag. Doble cara y listo.
		# Los rayos de altura NO cambian: _rayo() pide hit_back_faces=false.
		for cuerpo in m.get_children():
			if cuerpo is StaticBody3D:
				for cs in cuerpo.get_children():
					if cs is CollisionShape3D and cs.shape is ConcavePolygonShape3D:
						cs.shape.backface_collision = true
		# La foto aerea del mapa viejo venia con la luz horneada; volver a
		# sombrearla dejaba los arboles casi negros, asi que se le sacaba el
		# sombreado. Un modelo normal, con sus mapas de normal, hay que
		# dejarlo sombreado de verdad.
		if FOTO_AEREA:
			for i in m.get_surface_override_material_count():
				var mat: BaseMaterial3D = m.mesh.surface_get_material(i)
				if mat:
					var copia: BaseMaterial3D = mat.duplicate()
					copia.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					m.set_surface_override_material(i, copia)
		n += 1
	if _rids_mar.is_empty():
		push_warning("no se encontro la malla 'Mar': el filtro de siembra sobre el agua queda apagado")
	var escaparate := (load(BASURA) as PackedScene).instantiate()
	escaparate.visible = false     # se queda de molde, no se ve
	add_child(escaparate)
	for m in escaparate.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var s: Vector3 = (Transform3D(mi.global_transform.basis, Vector3.ZERO)
			* mi.mesh.get_aabb()).size.abs()
		if minf(s.x, minf(s.y, s.z)) < MOLDE_MIN:
			continue
		_moldes.append(mi)

	# la camioneta del mapa es la meta: se guarda su caja YA colocada en el
	# mundo, que el glb viene recentrado y sus coordenadas crudas no valen
	var cam := _escenario.find_child(META, true, false)
	if cam is MeshInstance3D:
		var mi := cam as MeshInstance3D
		_meta = mi.global_transform * mi.mesh.get_aabb()
		print("meta: %s en %s, caja %s" % [META,
			str(_meta.get_center().round()), str(_meta.size.round())])

	# La camioneta NPC, si la hay: cuelga de un Path3D de la escena del mapa.
	# Cuando esta, la meta es ella y no una malla quieta del glb.
	for c in find_children("*", "Camioneta", true, false):
		_camioneta = c as Camioneta
		_camioneta.suelo(Callable(self, "altura_terreno"))
		break

	await get_tree().physics_frame
	await get_tree().physics_frame
	print("mapa listo: %d mallas con colision, %s m%s" % [n,
		str(_aabb(_escenario).size.round()),
		" | camioneta NPC" if _camioneta else ""])


func pos_salida() -> Vector3:
	return _salida


## El punto al que hay que llegar. Con la camioneta NPC se recalcula cada vez:
## el HUD, la camara y la mira tienen que seguirla mientras se va.
func pos_meta() -> Vector3:
	if _camioneta:
		var c := _camioneta.caja()
		return Vector3(c.get_center().x, c.position.y + c.size.y, c.get_center().z)
	return _punto_meta


## Hay suelo firme bajo este punto: el rayo pega en algo. Es lo que valida que
## la salida de un mapa este puesta sobre el escenario y no en el aire.
func hay_suelo(x: float, z: float) -> bool:
	return not is_nan(_altura_cruda(x, z))


## Trae camioneta, o sea que se puede terminar. Puede ser la NPC que se va o
## una malla quieta del glb.
func tiene_meta() -> bool:
	return _camioneta != null or _meta.size != Vector3.ZERO


## Se va sola: alcanzarla es perseguirla, no llegar a un sitio.
func meta_se_mueve() -> bool:
	return _camioneta != null


## La caja de la camioneta, en mundo, AHORA. Si se mueve se recalcula: una caja
## cacheada al arrancar dejaria la meta clavada donde ya no esta.
func caja_meta() -> AABB:
	return _camioneta.caja() if _camioneta else _meta


func camioneta() -> Camioneta:
	return _camioneta


## Trae jaula de salida: el piche arranca encerrado y va la cinematica del
## portazo. Sin ella arranca de pie en el marcador Salida.
func tiene_jaula() -> bool:
	return _jaula_mapa != Transform3D.IDENTITY


## Como traia el glb su malla "jaula": ahi va, igualita, la de verdad.
func trafo_jaula_mapa() -> Transform3D:
	return _jaula_mapa


## Altura de la superficie del agua, o NAN si este mapa no tiene mar.
func altura_mar() -> float:
	return _mar


## Si lo que hay bajo (x, z) es el agua y no el muelle. Sirve para saber si el
## piche cae al mar o sobre tablas, que no suenan igual.
##
## Se pregunta por la MALLA que devuelve el rayo, NO por la altura: un muelle se
## construye justo en la linea del agua, y aqui la salida y la superficie del mar
## estan los dos a y=164.74 clavados. Con un margen de altura, medio muelle era
## agua. `create_trimesh_collision()` cuelga el cuerpo de la malla, asi que el
## padre del colisionador es el MeshInstance3D y trae su nombre puesto.
##
## Solo el mapa del muelle trae "Mar": en un mapa sin agua _mar queda NAN y esto
## siempre da false, asi que el chapuzon nunca suena ahi (ver sonido.gd).
func hay_agua(x: float, z: float) -> bool:
	if is_nan(_mar):
		return false
	var cuerpo := _colisionador(x, z)
	var malla := cuerpo.get_parent() if cuerpo else null
	return malla != null and malla.name == MAR


## Deja el mapa listo para jugarse: fija la salida, la meta y siembra. Se llama
## una vez, despues de preparar(); cambiar de mapa es cambiar de escena.
func ir_a() -> void:
	# Salida es un marcador de la escena del mapa: se arrastra en el editor.
	# Ademas se recoloca en preparar() encima de la jaula que trae el
	# glb, y de ahi se usa TAL CUAL, sin rayo: altura y giro son los que le dio
	# el artista. Un rayo AQUI MIENTE. La cubierta bajo la jaula esta a 171.44,
	# pero es de las caras que _rayo() no ve (pide hit_back_faces=false), asi
	# que el rayo la cruza y devuelve 168.51, tres metros mas abajo, dentro del
	# barco. El piche SI se apoya en ella, porque las formas van a doble cara.
	# De ahi salio la fama de que este sitio "cae sobre un hueco del casco".
	_salida = $Salida.position
	if _camioneta:
		_punto_meta = pos_meta()
		_poblar_fauna()
		_poblar_basura()
		return
	if _meta.size == Vector3.ZERO:
		# Sin meta el mapa se puede recorrer pero no terminar. No se corta: asi
		# un mapa a medio armar igual se puede abrir y mirar.
		push_error("%s: no trae malla '%s', no hay meta y no se puede terminar"
			% [name, META])
		_punto_meta = _salida
		return
	# el punto de llegada es el techo de la caja de la camioneta
	var c := _meta.get_center()
	_punto_meta = Vector3(c.x, _meta.position.y + _meta.size.y, c.z)
	_poblar_fauna()
	_poblar_basura()


## `techo` es desde donde cae el rayo. Por defecto desde muy arriba, que es lo
## que hace falta para colocar cosas a ciegas; pero el rayo para en la PRIMERA
## colision, y bajo un arbol esa es la copa, no el suelo. Quien ya sabe mas o
## menos a que altura esta lo que busca puede bajar el techo y saltarselas.
func altura_terreno(x: float, z: float, techo := INF) -> float:
	var desde: float = _techo if is_inf(techo) else techo
	var h := _rayo(x, z, desde)
	return _punto_meta.y if is_inf(h) else h


## Rayo hacia abajo, en crudo, resultado entero (posicion + rid + collider del
## cuerpo). Diccionario vacio si no pega en nada. Primitiva unica: _rayo() y
## _colisionador() salen de aca, para que "donde apoya" y "sobre que apoya"
## no puedan divergir.
func _rayo_crudo(x: float, z: float, desde: float) -> Dictionary:
	# Entre el remove_child(mapa) viejo y que el mapa nuevo termine preparar()
	# (_cargar_mapa/_reiniciar en juego.gd, tanto en el arranque como al
	# reintentar), este nodo pasa varios fotogramas fuera del arbol mientras
	# impulso.gd sigue con un Callable atado a ESTE mapa (el suyo se actualiza
	# recien cuando termina preparar()). Pedir get_world_3d() ahi no devuelve
	# null en silencio: tira un ERROR de motor y despues un SCRIPT ERROR al
	# leer .direct_space_state de esa referencia nula. Cortar antes de pedirlo
	# evita las dos. Esta es la unica puerta a la fisica (ver comentario de la
	# funcion de arriba), asi que tapa a la vez _rayo(), _colisionador() y,
	# via g.is_empty(), _altura_sembrable().
	if not is_inside_tree():
		return {}
	var esp := get_world_3d().direct_space_state
	if esp == null:
		return {}
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, desde, z), Vector3(x, SUELO, z))
	q.exclude = excluir
	# Los rayos de altura ignoran las caras traseras A PROPOSITO. Al poner las
	# formas a doble cara (backface_collision, para que la BOLA no atraviese
	# paredes) los rayos tambien empezaron a ver la cara de abajo de cada
	# superficie: el pelado de altura_suelo cruzaba el mar (el salida salia 4 m
	# bajo el agua) y el piso de tierra (la basura se sembraba enterrada).
	# Con esto los rayos ven lo mismo de siempre y la doble cara queda solo
	# para los cuerpos, que es donde hace falta.
	q.hit_back_faces = false
	return esp.intersect_ray(q)


## Rayo hacia abajo. Devuelve INF si no encuentra NADA, que no es lo mismo que
## encontrar suelo a la altura cero: altura_suelo necesita saber la diferencia
## para no seguir pelando capas cuando ya no queda nada debajo.
func _rayo(x: float, z: float, desde: float) -> float:
	var golpe := _rayo_crudo(x, z, desde)
	return golpe["position"].y if golpe else INF


## Que hay bajo (x, z), como nodo. Mismo rayo que la altura, misma exclusion y
## mismo hit_back_faces: si divergieran, "donde apoya" y "sobre que apoya"
## podrian contestar cosas distintas.
func _colisionador(x: float, z: float) -> Node:
	var golpe := _rayo_crudo(x, z, _techo)
	return golpe["collider"] if golpe else null


## Lo mismo que altura_terreno pero sin el apano: NAN cuando el rayo no da en
## NADA. Quien coloca cosas a ciegas necesita distinguir "aqui no hay suelo" de
## "el suelo esta justo a la altura de la meta", que es lo que devolvia el
## apano de arriba y dejaba piezas flotando en el aire.
func _altura_cruda(x: float, z: float, techo := INF) -> float:
	var desde: float = _techo if is_inf(techo) else techo
	var h := _rayo(x, z, desde)
	return NAN if is_inf(h) else h


## Altura para SEMBRAR: ademas de exigir que el rayo pegue en algo, tira los
## sitios donde una pieza no se puede recoger andando: el mar (que colisiona y
## el rayo lo ve como piso), lo que este por debajo de todo lo caminable, lo
## que se hundio mucho respecto del camino salida-meta, y lo que quedo BAJO
## TECHO -un rayo que se colo por un hueco del casco pega en la bodega, y esa
## botella se ve por el agujero pero no hay como agarrarla-. Devuelve NAN si
## el sitio no vale.
func _altura_sembrable(x: float, z: float) -> float:
	var g := _rayo_crudo(x, z, _techo)
	if g.is_empty():
		return NAN
	var y: float = g["position"].y
	if y < minf(_salida.y, _punto_meta.y) - HUNDIDO or y < NIVEL_PERDIDO + 0.1:
		return NAN
	if _rids_mar.has(g["rid"]):
		return NAN
	# cielo abierto: el rayo va de +0.4 (salta el volumen de la propia pieza)
	# a +2.5; si en ese tramo hay geometria, esto es la bodega (o un
	# entrepiso): se ve, no se alcanza. hit_back_faces en true porque la cara
	# de la cubierta mira hacia arriba y desde abajo es trasera.
	var esp := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(x, y + 0.4, z), Vector3(x, y + 2.5, z))
	q.exclude = excluir
	q.hit_back_faces = true
	if esp.intersect_ray(q):
		return NAN
	return y


## El SUELO, no lo primero que encuentre el rayo. altura_terreno para en la
## primera colision, y bajo un arbol esa es la copa: por eso la fauna, la
## basura y la gente aparecian plantadas quince metros en el aire. Se vuelve a
## tirar desde justo debajo de lo que encontro, y asi se van pelando capas
## hasta que una tirada ya no baja: eso es el suelo.
func altura_suelo(x: float, z: float) -> float:
	# Aca se deja TECHO fijo, no _techo: esta funcion pela capas de a 30 cm y
	# con pocas vueltas, para atravesar hojas de un arbol, no un mastil entero.
	# Arrancar mas alto (por los mastiles altos, que es lo que _techo corrige
	# en altura_terreno) la hacia enganchar en cosas que el pelado no llegaba a
	# atravesar antes de quedarse sin vueltas, y el salida salia mas abajo de lo
	# que va.
	var h := _rayo(x, z, TECHO)
	if is_inf(h):
		return _punto_meta.y
	for i in 4:
		var abajo := _rayo(x, z, h - 0.3)
		if is_inf(abajo) or abajo >= h - 0.05:
			break                      # ya no queda nada debajo: eso es suelo
		h = abajo
	return h


## Llego a la meta: subirse a la camioneta. Hay que estar ENCIMA, no al lado:
## dentro de su huella -recortada, para que rozarle un guardabarros no cuente-
## y por encima de la caja. Y hay que haberse posado: pasarle por arriba
## volando a veinte metros por segundo no es subirse.
func llego(pos: Vector3, vel := Vector3.ZERO) -> bool:
	if _camioneta:
		# se le corre: alcanza con arrimarse, no hay que embocar en la caja
		return _camioneta.alcanzada(pos)
	if _meta.size == Vector3.ZERO or vel.length() > VEL_SUBIDO:
		return false
	var c := _meta.get_center()
	return absf(pos.x - c.x) < _meta.size.x * MARGEN_META \
		and absf(pos.z - c.z) < _meta.size.z * MARGEN_META \
		and pos.y > _meta.position.y + _meta.size.y * ALTURA_CAJA


## Ya no hay vuelta: el agua y la bodega quedan por debajo de todo lo caminable.
## Quien la use decide que hacer (reponer, penalizar); el mapa solo sabe donde
## termina lo jugable.
func perdida(pos: Vector3) -> bool:
	return pos.y < NIVEL_PERDIDO


## Cuanto frena el suelo. Un solo valor para todo el mapa: las zonas de golf
## -calle, rough, green- eran una franja invisible entre la salida y la meta
## que cambiaba el rozamiento sin que el jugador pudiera verla.
func damp_suelo() -> float:
	return 0.30


# ---------------------------------------------------------------------------

func _poblar_fauna() -> void:
	for a in animales:
		if is_instance_valid(a["nodo"]):
			a["nodo"].queue_free()
	animales.clear()
	var medio := (Vector2(_salida.x, _salida.z) + Vector2(_punto_meta.x, _punto_meta.z)) * 0.5
	for n in 6:
		# se tira el dado varias veces: medio radio de estos 60 m cae fuera del
		# barco o sobre un hueco del casco, y ahi el bicho salia nadando en el
		# mar o colgado en el aire a la altura de la meta
		var p := Vector2.ZERO
		var y := NAN
		for intento in INTENTOS_SIEMBRA:
			p = medio + Vector2(randf_range(-60, 60), randf_range(-60, 60))
			if p.distance_to(Vector2(_salida.x, _salida.z)) < 35.0:
				continue
			y = _altura_sembrable(p.x, p.y)
			if not is_nan(y):
				break
		if is_nan(y):
			continue
		var nodo := (load(ANIMAL) as PackedScene).instantiate()
		# se coloca en la misma y que valido _altura_sembrable: pelar de nuevo con
		# altura_suelo cruza la cubierta por los huecos del casco y devuelve la
		# bodega o el mar, que es justo lo que _altura_sembrable ya descarto.
		nodo.position = Vector3(p.x, y, p.y)
		add_child(nodo)
		animales.append({"nodo": nodo, "dir": randf() * TAU, "t": randf() * 3.0,
			"vivo": true, "color": COLOR_ANIMAL})


## Siembra basura por el camino salida-meta: es por donde se pasa, asi
## que se encuentra sin desviarse, pero repartida para que haya que buscarla.
func _poblar_basura() -> void:
	for b in basura:
		if is_instance_valid(b):
			b.queue_free()
	basura.clear()
	if _moldes.is_empty():
		return
	var a := Vector2(_salida.x, _salida.z)
	var b := Vector2(_punto_meta.x, _punto_meta.z)
	for i in BASURAS:
		# el camino cruza el costado del barco: hay tramos que caen al agua y
		# huecos del casco por los que el rayo se cuela hasta la bodega. Se
		# vuelve a tirar el dado unas cuantas veces y, si no sale sitio firme,
		# esta pieza se queda sin sembrar.
		var p := Vector2.ZERO
		var y := NAN
		for intento in INTENTOS_SIEMBRA:
			p = a.lerp(b, randf_range(0.08, 0.95)) \
				+ Vector2.from_angle(randf() * TAU) * randf_range(2.0, RADIO_BASURA)
			y = _altura_sembrable(p.x, p.y)
			if not is_nan(y):
				break
		if is_nan(y):
			continue
		var molde: MeshInstance3D = _moldes.pick_random()
		var caja: AABB = molde.mesh.get_aabb()
		var malla: MeshInstance3D = molde.duplicate()
		malla.position = -caja.get_center()   # el molde viene donde lo dejo el escaparate
		var pieza := Node3D.new()
		pieza.add_child(malla)
		# la misma y que valido _altura_sembrable: pelar de nuevo con altura_suelo
		# cruza la cubierta por los huecos del casco y termina en la bodega o el mar.
		pieza.position = Vector3(p.x, y + caja.size.y * 0.5, p.y)
		pieza.rotation.y = randf() * TAU
		add_child(pieza)
		basura.append(pieza)
	print("basura sembrada: %d de %d" % [basura.size(), BASURAS])


# ---------------------------------------------------------------------------
# El desprendimiento: piedras que se sueltan en la cima y bajan rodando.
# ---------------------------------------------------------------------------

## Suelta una piedra cada `rocas_cada` segundos desde el marcador `Rocas`, si
## el mapa lo trae. Las sueltas SE HACEN EN LA CIMA y bajan por fisica: nacer
## a mitad de ladera se ve como un truco.
func rodar_rocas(dt: float, lejos_de := Vector3.INF) -> void:
	var cima := get_node_or_null("Rocas") as Node3D
	if rocas_cada <= 0.0 or cima == null:
		return
	for i in range(rocas.size() - 1, -1, -1):
		var r: Roca = rocas[i]
		if not is_instance_valid(r):
			rocas.remove_at(i)
		elif r.global_position.y < cima.global_position.y - roca_muere:
			r.queue_free()          # se fue por la ladera, ya no molesta
			rocas.remove_at(i)
	_t_roca -= dt
	if _t_roca > 0.0:
		return
	_t_roca = rocas_cada
	_soltar_roca(cima, lejos_de)


func _soltar_roca(cima: Node3D, lejos_de: Vector3) -> void:
	var p := cima.global_position + Vector3(
		randf_range(-roca_dispersa, roca_dispersa), 0.0,
		randf_range(-roca_dispersa, roca_dispersa))
	# Nunca encima del piche: aparecer dentro de el es una muerte que no se
	# pudo ver venir, y las piedras tienen que poder esquivarse.
	if not is_inf(lejos_de.x) and Vector2(p.x - lejos_de.x, p.z - lejos_de.z).length() < ROCA_SEGURO:
		return
	var y := altura_terreno(p.x, p.z)
	var radio := randf_range(roca_min, roca_max)
	var roca: Roca = (load(ROCA) as PackedScene).instantiate()
	roca.tamano(radio)
	add_child(roca)
	# apoyada en el suelo de la cima, no enterrada ni cayendo del cielo
	roca.global_position = Vector3(p.x, y + radio, p.z)
	# el empujon la manda ladera abajo: se mira donde baja el terreno alrededor
	roca.linear_velocity = _cuesta_abajo(p.x, p.z) * roca_empuje
	rocas.append(roca)


## Hacia donde baja el terreno en este punto, en horizontal. Se sondea en cruz
## y se apunta al vecino mas bajo: no hace falta la normal exacta, solo saber
## para donde rueda.
func _cuesta_abajo(x: float, z: float) -> Vector3:
	var d := 6.0
	var g := Vector3(altura_terreno(x + d, z) - altura_terreno(x - d, z), 0.0,
		altura_terreno(x, z + d) - altura_terreno(x, z - d))
	if g.length() < 0.01:
		return Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	return -g.normalized()


## La piedra que este aplastando al piche, si hay alguna.
func roca_encima(pos: Vector3, radio_piche: float) -> Roca:
	for r in rocas:
		if is_instance_valid(r) and r.pisa(pos, radio_piche):
			return r
	return null


## Recoge lo que haya a tiro y devuelve cuantas piezas eran.
func recoger(pos: Vector3, radio: float) -> int:
	var n := 0
	for i in range(basura.size() - 1, -1, -1):
		var b: Node3D = basura[i]
		if not is_instance_valid(b):
			basura.remove_at(i)
			continue
		if b.global_position.distance_to(pos) < radio:
			Util.reventar(self, b.global_position, Color(0.55, 0.85, 0.45), 10)
			b.queue_free()
			basura.remove_at(i)
			n += 1
	return n


func choque(pos: Vector3, vel: Vector3) -> String:
	if vel.length() < 5.0:
		return ""
	for a in animales:
		if not a["vivo"]:
			continue
		var n: Node3D = a["nodo"]
		if pos.distance_to(n.global_position + Vector3.UP * 0.4) < 1.3:
			_aturdir(a)
			return "animal"
	return ""


func mover_animales(dt: float, pos_piche: Vector3, peligro: bool) -> void:
	for a in animales:
		if not a["vivo"]:
			continue
		var n: Node3D = a["nodo"]
		a["t"] -= dt
		if a["t"] <= 0.0:
			a["dir"] = randf() * TAU
			a["t"] = randf_range(1.5, 4.0)
		if peligro and n.global_position.distance_to(pos_piche) < 25.0:
			a["dir"] = atan2(n.global_position.x - pos_piche.x, n.global_position.z - pos_piche.z)
		var vel := 6.0 if peligro else 1.6
		var np := n.position + Vector3(sin(a["dir"]), 0, cos(a["dir"])) * vel * dt
		var y := _altura_cruda(np.x, np.z)
		# el suelo no da saltos de dos metros de un paso al otro: si los da es
		# el borde de la cubierta, un hueco del casco o un rayo que no pega en
		# nada, y pegar el bicho a esa altura lo teletransportaba al mar o a la
		# meta. No se da el paso: se queda donde esta y se da la vuelta.
		if is_nan(y) or absf(y - n.position.y) > 2.0:
			a["dir"] = randf() * TAU
			continue
		np.y = y
		n.position = np
		n.rotation.y = a["dir"] + PI


## El animal queda aturdido, no muerto: se levanta y sale corriendo (DISENO.md).
func _aturdir(a: Dictionary) -> void:
	a["vivo"] = false
	var nodo: Node3D = a["nodo"]
	Util.reventar(self, nodo.global_position + Vector3.UP * 0.4, a["color"], 12)
	var t := create_tween()
	t.tween_property(nodo, "rotation:z", PI / 2.0, 0.25)
	t.tween_interval(1.0)
	t.tween_property(nodo, "rotation:z", 0.0, 0.3)
	t.tween_callback(func(): a["vivo"] = true)


func _aabb(n: Node) -> AABB:
	var caja := AABB()
	var primero := true
	for m: MeshInstance3D in _mallas(n):
		var c: AABB = m.global_transform * m.get_aabb()
		if primero:
			caja = c
			primero = false
		else:
			caja = caja.merge(c)
	return caja


func _mallas(n: Node) -> Array[MeshInstance3D]:
	var r: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		r.append(n)
	for h in n.get_children():
		r.append_array(_mallas(h))
	return r
