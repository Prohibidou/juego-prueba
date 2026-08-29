extends Node3D
class_name Campo
## El campo: una fotogrametria real de un club de golf, y los hoyos que se
## juegan sobre ella. Sustituye al terreno generado con Terrain3D.
##
## La malla trae su propio relieve, arboles y edificios, asi que aqui no se
## genera nada: solo se le pone colision, se sacan alturas por rayo y se montan
## la copa y la bandera de cada hoyo.
##
## Las coordenadas de HOYOS se sacaron mirando el campo desde arriba con
## herramientas/VerMapa.tscn. Para mover un tee o una bandera, se toca esta
## tabla y se vuelve a mirar el render.

# La foto aerea del campo viejo venia con la luz horneada y habia que
# desactivarle el sombreado (si no, los arboles salian casi negros). El
# muelle es un modelo normal con sus propios mapas de normal: sombrearlo es
# lo correcto, asi que esto queda en false.
const FOTO_AEREA := false

# La basura viene como un escaparate de Sketchfab: cuarenta y pico piezas
# sueltas (latas, cajas, ladrillos) repartidas sobre un plano. Se usan de
# molde, se duplican y se siembran por el pasillo del hoyo.
const BASURA := "res://modelos/trash_and_debris.glb"
const BASURAS := 16            # piezas por hoyo

# medidas reales de golf
# --- la meta: subirse a la camioneta ---
const META := "CAMIONETA"      # nombre de la malla dentro del glb del mapa
const MARGEN_META := 0.35      # fraccion del ancho que cuenta como "encima"
# A partir de que altura de su caja se considera que estas ARRIBA. Medido con
# rayos sobre la camioneta del muelle: el piso de la caja esta a 0.39 de su
# alto y el techo de la cabina a 1.0, mientras que las ruedas apoyan en 0. Con
# 0.45 solo valia subirse al techo; con esto vale la caja, que es donde se
# sube, y sigue sin valer meterse debajo del chasis.
const ALTURA_CAJA := 0.28
const VEL_SUBIDO := 6.0        # m/s por encima de los cuales va de paso
# ---------------------------------------
const R_COPA := 0.054          # 108 mm de diametro
const PROF_COPA := 0.12
const R_PLATAFORMA := 3.0
const ALTO_PLATAFORMA := 0.15  # la plataforma del hoyo se levanta sobre el
							   # terreno: sin eso la copa quedaria enterrada en
							   # la malla y la bola no podria bajar del labio
# Piezas provisionales: son escenas para poder cambiarlas por el modelo bueno
# arrastrandolo encima, cosa que con un MeshInstance3D hecho a mano no se puede.
const BANDERA := "res://escenas/piezas/Bandera.tscn"
const ANIMAL := "res://escenas/piezas/Animal.tscn"
const COLOR_ANIMAL := Color(0.85, 0.82, 0.78)   # para el reventon al aturdirlo
const R_GREEN := 14.0
const ANCHO_CALLE := 22.0

const TECHO := 300.0           # desde donde se lanzan los rayos de altura
const SUELO := -80.0
# ...pero 300 se queda CORTO: el mapa del muelle mide 366 m de alto, asi que
# bajo los mastiles y las gruas mas altas el rayo arrancaba DENTRO de la
# geometria, y un rayo no cuenta lo que ya lo envuelve (hit_from_inside viene
# en false): la altura salia mal justo donde se coloca a ciegas. El techo de
# verdad se saca de la caja del mapa en preparar(); TECHO queda de arranque.
const MARGEN_TECHO := 10.0
# Cuanto puede hundirse una siembra respecto del pasillo tee-bandera antes de
# darla por caida al mar o a la bodega por uno de los huecos del casco.
const HUNDIDO := 8.0
const INTENTOS_SIEMBRA := 6    # tiros de dado por pieza antes de rendirse

# Zonas. Sin mapa de control pintado hay que deducirlas de la geometria del
# hoyo: cerca de la bandera es green, en el pasillo tee-bandera es calle, y el
# resto rough. Los bunkers de la foto no se detectan.
const ZONA_ROUGH := 0
const ZONA_CALLE := 1
const ZONA_GREEN := 3
const NOMBRE_ZONA := {0: "rough", 1: "calle", 3: "green"}

const HOYOS := [
	{"par": 4, "viento": Vector3(1.0, 0, -0.5)},
]

var indice := 0
var excluir: Array[RID] = []   # la bola, para que no la pisen los rayos

var _curso: Node3D
var _copa: Node3D
var _tee := Vector3.ZERO
# La meta es SUBIRSE A LA CAMIONETA que trae el mapa: se busca su malla al
# montar el escenario y se guarda su caja en coordenadas de mundo. Si algun
# mapa no la trae, se cae de vuelta a la copa de golf de siempre.
var _meta := AABB()
var _bandera := Vector3.ZERO
var _labio := 0.0
var _techo := TECHO             # el de verdad lo mide preparar() con la caja del mapa
var animales: Array = []
var basura: Array = []

var _moldes: Array[MeshInstance3D] = []


## Monta el campo. Hay que esperarlo: la colision no existe hasta que la fisica
## ha corrido un fotograma, y sin ella los rayos de altura no devuelven nada.
func preparar() -> void:
	# El mapa esta instanciado y recentrado en Campo.tscn (esquina del campo en
	# el origen): moverlo, escalarlo o cambiarlo se hace ahi, arrastrando.
	_curso = $Curso

	# el marcador "jaula" que trae el modelo es solo para saber donde va el
	# tee: la jaula de verdad (con puerta y todo) la arma _montar_jaula() en
	# juego.gd. Dejarlo metia una caja solida encima del spawn. Se cae aca
	# porque un nodo de dentro de una instancia no se puede borrar en el editor.
	var marcador := _curso.find_child("jaula", true, false)
	if marcador:
		marcador.queue_free()
	await get_tree().process_frame   # que el marcador se haya ido antes de colisionar

	# ponytail: la colision se genera en cada arranque y son varios segundos
	# (por eso hay portada de carga). El techo se sube pasando las formas al
	# importador del glb (_subresources/generate/physics), pero el casco del
	# barco esta afinado a mano aca abajo y el importador no expone esos
	# ajustes: mover eso es una sesion entera, no un renglon.
	# El mapa ya viene recentrado desde Campo.tscn, asi que aca no se toca su
	# position: solo se mide la caja para saber hasta donde llega lo mas alto
	# (mastiles, gruas) y subir el techo de los rayos por encima de eso.
	var caja := _aabb(_curso)
	_techo = caja.position.y + caja.size.y + MARGEN_TECHO

	var n := 0
	for m: MeshInstance3D in _mallas(_curso):
		if m.name == "Barco":
			# un ConcavePolygonShape3D (el trimesh de siempre) es para suelo
			# quieto: contra un cuerpo rigido rapido puede dejarlo atravesar,
			# sobre todo en una carcasa fina como un casco. Con varios cascos
			# convexos (V-HACD) el piche ya no se cuela. Con los ajustes por
			# defecto cada casco infla un poco de mas alla de la malla real
			# (queda "hinchado"): eso dejaba la cubierta solida mas arriba
			# que la cubierta que se ve, y la jaula flotaba sobre el barco en
			# vez de pisarlo. project_hull_vertices pega los vertices del
			# casco a la malla real; max_concavity bajo y mas cascos hacen
			# que le cueste mas alejarse de la forma original.
			#
			# Se probo pasar esto a trimesh liso (mas simple, y en teoria mas
			# fiel a la malla real): rompia el ajuste de la jaula, que esta
			# calibrada sobre ESTA cubierta inflada -el tee bajaba 5 m y la
			# puerta dejaba de frenar a la bola andando. Se queda como estaba.
			var ajuste := MeshConvexDecompositionSettings.new()
			ajuste.max_concavity = 0.001
			ajuste.resolution = 400000
			ajuste.max_convex_hulls = 32
			ajuste.project_hull_vertices = true
			m.create_multiple_convex_collisions(ajuste)
		else:
			m.create_trimesh_collision()
		# Un trimesh choca solo por el lado de las normales (backface_collision
		# arranca en false, y desde Godot 4.5 Jolt lo respeta de verdad). Medio
		# mapa esta modelado a una cara -galpones, silos-, asi que la bola
		# atravesaba esas paredes al pegarles "desde atras", y el CCD no la
		# salva porque su cast respeta el mismo flag. Doble cara y listo. Los
		# cascos convexos del barco no tienen esta propiedad -un convexo no
		# tiene "el otro lado"-, el chequeo de tipo los salta solo. Los rayos
		# de altura no cambian: hit_back_faces ya venia en true.
		for cuerpo in m.get_children():
			if cuerpo is StaticBody3D:
				for cs in cuerpo.get_children():
					if cs is CollisionShape3D and cs.shape is ConcavePolygonShape3D:
						cs.shape.backface_collision = true
		# La foto aerea del campo viejo venia con la luz horneada; volver a
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
	var escaparate := (load(BASURA) as PackedScene).instantiate()
	escaparate.visible = false     # se queda de molde, no se ve
	add_child(escaparate)
	for m in escaparate.find_children("*", "MeshInstance3D", true, false):
		_moldes.append(m as MeshInstance3D)

	# la camioneta del mapa es la meta: se guarda su caja YA colocada en el
	# mundo, que el glb viene recentrado y sus coordenadas crudas no valen
	var cam := _curso.find_child(META, true, false)
	if cam is MeshInstance3D:
		var mi := cam as MeshInstance3D
		_meta = mi.global_transform * mi.mesh.get_aabb()
		print("meta: %s en %s, caja %s" % [META,
			str(_meta.get_center().round()), str(_meta.size.round())])

	await get_tree().physics_frame
	await get_tree().physics_frame
	print("campo listo: %d mallas con colision, %s m" % [n, str(_aabb(_curso).size.round())])


func par() -> int:
	return HOYOS[indice]["par"]


func viento() -> Vector3:
	return HOYOS[indice]["viento"]


func pos_tee() -> Vector3:
	return _tee


func pos_bandera() -> Vector3:
	return _bandera


func labio_copa() -> float:
	return _labio


## Cambia de hoyo: recoloca tee, bandera y copa. El campo no se recarga.
func ir_a(i: int) -> void:
	indice = i
	# Tee y Bandera son marcadores de Campo.tscn: se arrastran en el editor.
	# De ellos se usa solo el plano; la altura la pone el rayo al suelo. El tee
	# NO va donde el glb pone su marcador "jaula" -ese cae sobre un hueco del
	# casco y la jaula quedaba dentro del barco-, sino en una meseta de la
	# cubierta con sitio detras para la camara.
	var t: Vector3 = $Tee.position
	var b: Vector3 = $Bandera.position
	_tee = Vector3(t.x, altura_suelo(t.x, t.z), t.z)
	if _meta.size != Vector3.ZERO:
		# la meta es la camioneta: la bandera apunta a su caja, que es a donde
		# hay que llegar, y no se planta ninguna copa sobre la cubierta
		var c := _meta.get_center()
		_bandera = Vector3(c.x, _meta.position.y + _meta.size.y, c.z)
		_labio = _bandera.y
	else:
		_bandera = Vector3(b.x, altura_suelo(b.x, b.z), b.z)
		_labio = _bandera.y + ALTO_PLATAFORMA
		_montar_copa()
	_poblar_fauna()
	_poblar_basura()


## `techo` es desde donde cae el rayo. Por defecto desde muy arriba, que es lo
## que hace falta para colocar cosas a ciegas; pero el rayo para en la PRIMERA
## colision, y bajo un arbol esa es la copa, no el suelo. Quien ya sabe mas o
## menos a que altura esta lo que busca puede bajar el techo y saltarselas.
func altura_terreno(x: float, z: float, techo := INF) -> float:
	var desde: float = _techo if is_inf(techo) else techo
	var h := _rayo(x, z, desde)
	return _bandera.y if is_inf(h) else h


## Rayo hacia abajo, en crudo. Devuelve INF si no encuentra NADA, que no es lo
## mismo que encontrar suelo a la altura cero: altura_suelo necesita saber la
## diferencia para no seguir pelando capas cuando ya no queda nada debajo.
func _rayo(x: float, z: float, desde: float) -> float:
	var esp := get_world_3d().direct_space_state
	if esp == null:
		return INF
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, desde, z), Vector3(x, SUELO, z))
	q.exclude = excluir
	var golpe := esp.intersect_ray(q)
	return golpe["position"].y if golpe else INF


## Lo mismo que altura_terreno pero sin el apano: NAN cuando el rayo no da en
## NADA. Quien coloca cosas a ciegas necesita distinguir "aqui no hay suelo" de
## "el suelo esta justo a la altura de la bandera", que es lo que devolvia el
## apano de arriba y dejaba piezas flotando en el aire.
func _altura_cruda(x: float, z: float, techo := INF) -> float:
	var desde: float = _techo if is_inf(techo) else techo
	var h := _rayo(x, z, desde)
	return NAN if is_inf(h) else h


## Altura para SEMBRAR: ademas de exigir que el rayo pegue en algo, tira las
## que se cuelan por los huecos del casco y acaban en el mar o en la bodega,
## muy por debajo del pasillo tee-bandera. Devuelve NAN si el sitio no vale.
func _altura_sembrable(x: float, z: float) -> float:
	var y := _altura_cruda(x, z)
	if is_nan(y) or y < minf(_tee.y, _bandera.y) - HUNDIDO:
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
	# atravesar antes de quedarse sin vueltas, y el tee salia mas abajo de lo
	# que va.
	var h := _rayo(x, z, TECHO)
	if is_inf(h):
		return _bandera.y
	for i in 4:
		var abajo := _rayo(x, z, h - 0.3)
		if is_inf(abajo) or abajo >= h - 0.05:
			break                      # ya no queda nada debajo: eso es suelo
		h = abajo
	return h


## Llego a la meta. Con la camioneta hay que estar ENCIMA, no al lado: dentro
## de su huella -recortada, para que rozarle un guardabarros no cuente- y por
## encima de la caja. Y hay que haberse posado: pasarle por arriba volando a
## veinte metros por segundo no es subirse.
func embocada(pos: Vector3, vel := Vector3.ZERO) -> bool:
	if _meta.size == Vector3.ZERO:
		return pos.y < _labio - 0.04 \
			and Vector2(pos.x - _bandera.x, pos.z - _bandera.z).length() < R_COPA
	if vel.length() > VEL_SUBIDO:
		return false
	var c := _meta.get_center()
	return absf(pos.x - c.x) < _meta.size.x * MARGEN_META \
		and absf(pos.z - c.z) < _meta.size.z * MARGEN_META \
		and pos.y > _meta.position.y + _meta.size.y * ALTURA_CAJA


## ponytail: zonas por geometria, no por textura. La foto no dice donde acaba la
## calle; deducirlo del pasillo tee-bandera es aproximado pero suficiente para
## que el rough penalice. Si hace falta precision, pintar un mapa de zonas.
func zona(x: float, z: float) -> int:
	var p := Vector2(x, z)
	if p.distance_to(Vector2(_bandera.x, _bandera.z)) < R_GREEN:
		return ZONA_GREEN
	var a := Vector2(_tee.x, _tee.z)
	var b := Vector2(_bandera.x, _bandera.z)
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return ZONA_CALLE if p.distance_to(a + ab * t) < ANCHO_CALLE else ZONA_ROUGH


func factor_damp(z: int) -> float:
	match z:
		ZONA_CALLE: return 1.0
		ZONA_GREEN: return 0.7
		_: return 3.5


func retiene_efecto(z: int) -> float:
	return 1.0 if z != ZONA_ROUGH else 0.45


func es_peligro(_z: int) -> bool:
	return false   # el campo real no tiene lava; el agua no esta marcada


func damp_suelo() -> float:
	return 0.30


func nombre_zona(z: int) -> String:
	return NOMBRE_ZONA.get(z, "?")


# ---------------------------------------------------------------------------
# La copa: plataforma levantada con el agujero de 108 mm y la cazoleta debajo.
# ---------------------------------------------------------------------------

func _montar_copa() -> void:
	if _copa:
		_copa.queue_free()
	_copa = Node3D.new()
	add_child(_copa)

	var c := Vector2(_bandera.x, _bandera.z)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lados := 40
	var anillos := 5
	for i in lados:
		var a0 := TAU * i / lados
		var a1 := TAU * (i + 1) / lados
		for k in anillos:
			var r0: float = lerpf(R_COPA, R_PLATAFORMA, float(k) / anillos)
			var r1: float = lerpf(R_COPA, R_PLATAFORMA, float(k + 1) / anillos)
			var p00 := _punto(c, a0, r0)
			var p01 := _punto(c, a1, r0)
			var p10 := _punto(c, a0, r1)
			var p11 := _punto(c, a1, r1)
			st.add_vertex(p00); st.add_vertex(p10); st.add_vertex(p11)
			st.add_vertex(p00); st.add_vertex(p11); st.add_vertex(p01)
	# pared y fondo de la cazoleta
	for i in lados:
		var a0 := TAU * i / lados
		var a1 := TAU * (i + 1) / lados
		var s0 := Vector3(c.x + cos(a0) * R_COPA, _labio, c.y + sin(a0) * R_COPA)
		var s1 := Vector3(c.x + cos(a1) * R_COPA, _labio, c.y + sin(a1) * R_COPA)
		var f0 := s0 - Vector3(0, PROF_COPA, 0)
		var f1 := s1 - Vector3(0, PROF_COPA, 0)
		st.add_vertex(s0); st.add_vertex(f1); st.add_vertex(f0)
		st.add_vertex(s0); st.add_vertex(s1); st.add_vertex(f1)
		st.add_vertex(f0); st.add_vertex(f1); st.add_vertex(Vector3(c.x, _labio - PROF_COPA, c.y))
	st.generate_normals()

	var malla := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = Util.mat(Color(0.42, 0.68, 0.30))
	_copa.add_child(mi)

	var cuerpo := StaticBody3D.new()
	cuerpo.physics_material_override = Util.fisica()
	var cs := CollisionShape3D.new()
	cs.shape = malla.create_trimesh_shape()
	cuerpo.add_child(cs)
	_copa.add_child(cuerpo)

	var bandera := (load(BANDERA) as PackedScene).instantiate()
	bandera.position = Vector3(_bandera.x, _labio, _bandera.z)
	_copa.add_child(bandera)


func _punto(c: Vector2, ang: float, r: float) -> Vector3:
	var x := c.x + cos(ang) * r
	var z := c.y + sin(ang) * r
	var borde := altura_terreno(c.x + cos(ang) * R_PLATAFORMA, c.y + sin(ang) * R_PLATAFORMA)
	return Vector3(x, lerpf(_labio, borde, r / R_PLATAFORMA), z)


# ---------------------------------------------------------------------------

func _poblar_fauna() -> void:
	for a in animales:
		if is_instance_valid(a["nodo"]):
			a["nodo"].queue_free()
	animales.clear()
	var medio := (Vector2(_tee.x, _tee.z) + Vector2(_bandera.x, _bandera.z)) * 0.5
	for n in 6:
		# se tira el dado varias veces: medio radio de estos 60 m cae fuera del
		# barco o sobre un hueco del casco, y ahi el bicho salia nadando en el
		# mar o colgado en el aire a la altura de la bandera
		var p := Vector2.ZERO
		var y := NAN
		for intento in INTENTOS_SIEMBRA:
			p = medio + Vector2(randf_range(-60, 60), randf_range(-60, 60))
			if p.distance_to(Vector2(_tee.x, _tee.z)) < 35.0:
				continue
			y = _altura_sembrable(p.x, p.y)
			if not is_nan(y):
				break
		if is_nan(y):
			continue
		var nodo := (load(ANIMAL) as PackedScene).instantiate()
		# altura_suelo pela la copa: _altura_sembrable ya valido que p es firme,
		# pero el rayo bajo un arbol para en la copa, no en el pasto.
		nodo.position = Vector3(p.x, altura_suelo(p.x, p.y), p.y)
		add_child(nodo)
		animales.append({"nodo": nodo, "dir": randf() * TAU, "t": randf() * 3.0,
			"vivo": true, "color": COLOR_ANIMAL})


## Siembra basura por el pasillo tee-bandera: es el camino que se recorre, asi
## que se encuentra sin desviarse, pero repartida para que haya que buscarla.
func _poblar_basura() -> void:
	for b in basura:
		if is_instance_valid(b):
			b.queue_free()
	basura.clear()
	if _moldes.is_empty():
		return
	var a := Vector2(_tee.x, _tee.z)
	var b := Vector2(_bandera.x, _bandera.z)
	for i in BASURAS:
		# el pasillo cruza el costado del barco: hay tramos que caen al agua y
		# huecos del casco por los que el rayo se cuela hasta la bodega. Se
		# vuelve a tirar el dado unas cuantas veces y, si no sale sitio firme,
		# esta pieza se queda sin sembrar.
		var p := Vector2.ZERO
		var y := NAN
		for intento in INTENTOS_SIEMBRA:
			p = a.lerp(b, randf_range(0.08, 0.95)) \
				+ Vector2.from_angle(randf() * TAU) * randf_range(2.0, ANCHO_CALLE)
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
		pieza.position = Vector3(p.x, altura_suelo(p.x, p.y) + caja.size.y * 0.5, p.y)
		pieza.rotation.y = randf() * TAU
		add_child(pieza)
		basura.append(pieza)


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


func mover_animales(dt: float, pos_bola: Vector3, peligro: bool) -> void:
	for a in animales:
		if not a["vivo"]:
			continue
		var n: Node3D = a["nodo"]
		a["t"] -= dt
		if a["t"] <= 0.0:
			a["dir"] = randf() * TAU
			a["t"] = randf_range(1.5, 4.0)
		if peligro and n.global_position.distance_to(pos_bola) < 25.0:
			a["dir"] = atan2(n.global_position.x - pos_bola.x, n.global_position.z - pos_bola.z)
		var vel := 6.0 if peligro else 1.6
		var np := n.position + Vector3(sin(a["dir"]), 0, cos(a["dir"])) * vel * dt
		var y := _altura_cruda(np.x, np.z)
		# el suelo no da saltos de dos metros de un paso al otro: si los da es
		# el borde de la cubierta, un hueco del casco o un rayo que no pega en
		# nada, y pegar el bicho a esa altura lo teletransportaba al mar o a la
		# bandera. No se da el paso: se queda donde esta y se da la vuelta.
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
