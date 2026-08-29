extends Node3D
## Reglas, marcador y estado de la vuelta. No sabe como esta hecho el campo:
## solo le pide el par, el viento, el tee, la bandera, la zona bajo la bola y
## si algo se ha chocado.

# --- calibracion de juego ---
const QUIETA := 0.3
# una bola rodando a QUIETA gira a QUIETA/RADIO rad/s: a escala real son 14
# rad/s, no los 2 que valian cuando la bola medía 40 cm
const QUIETA_GIRO := QUIETA / Util.RADIO * 2.0
const ESPERA_QUIETA := 0.2
# Un piche cae con backspin y frena de golpe, no rueda como una bola de golf:
# con el damp del cesped solo (calle 0.3) tardaba mas de 10 s en asentarse
# despues de caer, y hasta que no estaba "quieto" no se recuperaba el control.
const FRENO_ATERRIZAJE := 0.32   # fraccion de velocidad que le queda al tocar
# Tope duro ademas del freno: con poco damp (calle) el resto de velocidad que
# sobrevive al freno igual podia reptar mas de la cuenta. A partir de este
# tiempo EN EL SUELO (no cuenta el vuelo) se corta y se da por quieta.
const CAIDA_MAX := 0.5
const VEL_MARCA := 15.0
const PENA_ANIMAL := 2
const PENA_DROP := 1
const MAX_MARCAS := 30
# --- direccion en el aire (SBG) ---
const AIRE_ACEL := 11.0     # m/s2 laterales mientras se dirige
const AIRE_TIEMPO := 1.1    # segundos de timon por golpe
# --- rodar el piche con el mando ---
const CONDUCE_ACEL := 7.0   # m/s2 que mete el stick izquierdo
const CONDUCE_MAX := 4.5    # m/s: es andar, no un golpe
const GIRO_MAX := 9.0       # rad/s: por encima de esto la vuelta es un borron
# --- stamina y correa ---
# Andar es gratis pero solo alrededor de donde caiste; para ir mas lejos hay
# que saltar, y saltar cuesta stamina. La basura del campo la repone: es lo que
# obliga a desviarse de la linea recta al hoyo.
const RADIO_ANDAR := 5.0
const PASOS_LIMITE := 32      # puntos por anillo del suelo pintado
const ANILLOS := 3            # anillos concentricos: mas, mejor se pega al relieve
const STAMINA_MAX := 100.0
const STAMINA_BASURA := 20.0
const STAMINA_IMPULSO := 60.0 # lo que cuesta el impulso (G) a barra llena
const STAMINA_SALTO := 15.0   # lo que cuesta el salto (espacio)
const IMPULSO_SALTO := 5.5    # m/s hacia arriba, sin tocar lo que ya lleve
# Por debajo de esto no hay impulso: ni barra, ni golpe minimo. Es el mismo
# numero que pinta de rojo la barra, para que lo que se ve y lo que se puede
# hacer sean la misma regla.
const STAMINA_MIN := STAMINA_IMPULSO * 0.2
const R_RECOGE := 1.2
# --- puntos (SBG puntua, no cuenta golpes) ---
const PUNTOS_HOYO := 100
const PUNTOS_GOLPE := 25    # lo que vale cada golpe ahorrado sobre el par
# A escala real la bola son 4 cm: a 20 m ya no se ve. Se dibuja agrandada de
# modo que ocupe SIEMPRE la misma fraccion de la pantalla, calculada con el fov
# y la distancia reales de la camara. La colision sigue siendo la esfera de 4 cm.
const MODELO_BOLA := "res://modelos/PicheLowHighTest07.fbx"
# La jaula arranca cerrada en el tee y la puerta se cae al primer impulso. En
# el modelo la puerta esta en la cara +X del nodo raiz, asi que la jaula se
# gira para que esa cara mire a la bandera y el piche salga hacia el hoyo.
const JAULA := "res://modelos/PGJ_Jaulav04.glb"
const PUERTA_CAE := 100.0     # grados que gira la puerta al caer
const MURO := 0.30            # grosor de los muros de la jaula
const VISTA_PANTALLA := 0.14    # subelo y el piche se ve mas grande
# ...pero con un tope en metros. El tamano constante en pantalla se invento
# cuando la camara se iba a 14 m; ahora que no pasa de 5.5, y que hay una jaula
# de 2 m al lado para comparar, sin tope el piche salia hecho un monstruo al
# arrancar y encogia en cuanto la camara se acercaba.
const VISTA_MAX := 0.34         # metros de ancho como mucho
# ----------------------------

var indice := 0
var golpes := 0
var total := 0
var tarjeta: Array[int] = []
var embocada := false
var quieto := true
var listo := false
var _t_lento := 0.0
var _t_caida := 0.0       # cuanto lleva EN EL SUELO desde que aterrizo, para CAIDA_MAX
var _golpe_volo := false  # si este golpe llego a volar (pos.y > umbral); ver CAIDA_MAX
var _v_pendiente := Vector3.ZERO
var _giro := 0.0
var _en_aire := false
var _desde := Vector3.ZERO
var _ultimo := 0.0        # distancia del ultimo golpe, para el aviso
var _diam_bola := 1.0     # tamano del modelo tal cual viene, en sus unidades
var _caja_bola := AABB()
var stamina := STAMINA_MAX
var _ancla := Vector3.ZERO               # centro del circulo en el que se anda
var _limite: MeshInstance3D
var _jaula: Node3D
var _puerta: MeshInstance3D
var _bisagra: Node3D
var _tapa: StaticBody3D
var _pulso_salto := false     # para detectar el flanco del espacio
var _saltando := false        # brinco en curso: sin correa y sin soltar el mando
var _angulo_rueda := 0.0                 # cuanto lleva rodado
var _eje_rueda := Vector3.RIGHT          # el eje del disco: su cara plana
var _dir_rueda := Vector3.FORWARD
var _mira_rueda := 0.0                   # ultima mira vista, para girar en el sitio con A/D
var _aire := 0.0          # timon que le queda a este golpe
var _marcas: Array = []

var campo: Campo
var bola: RigidBody3D
var vista: Node3D
var estela: CPUParticles3D
var camara: Camera3D
var golpe: Node3D
var entorno: WorldEnvironment
var hud: Label
var msg: Label
var barra: ProgressBar
var barra_stam: ProgressBar


func _ready() -> void:
	randomize()
	camara = Camera3D.new()
	camara.fov = 62.0
	camara.far = 4000.0
	add_child(camara)

	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-48, -35, 0)
	sol.light_energy = 1.35
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 300.0
	add_child(sol)

	var cielo_mat := ProceduralSkyMaterial.new()
	cielo_mat.sky_top_color = Color(0.32, 0.55, 0.90)
	cielo_mat.sky_horizon_color = Color(0.78, 0.87, 0.95)
	cielo_mat.ground_horizon_color = Color(0.78, 0.87, 0.95)
	cielo_mat.sun_angle_max = 12.0
	var cielo := Sky.new()
	cielo.sky_material = cielo_mat
	entorno = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = cielo
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# con 0.9 el relleno del cielo tapaba la sombra propia y el piche se veia
	# como una silueta plana; a 0.5 el sol vuelve a modelar el volumen
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_density = 0.0008
	env.fog_light_color = Color(0.78, 0.87, 0.95)
	entorno.environment = env
	add_child(entorno)

	_crear_bola()
	_crear_limite()
	_crear_ui()

	golpe = $Golpe
	golpe.preparar(bola, camara)
	golpe.golpeado.connect(_on_golpeado)

	campo = Campo.new()
	add_child(campo)
	campo.excluir = [bola.get_rid()]
	msg.text = "Cargando el campo..."
	await campo.preparar()
	msg.text = ""

	golpe.suelo = Callable(campo, "altura_terreno")
	_ir_a_hoyo(0)
	listo = true
	_self_check()


func _crear_bola() -> void:
	bola = RigidBody3D.new()
	bola.mass = Util.MASA
	bola.physics_material_override = Util.fisica()
	bola.continuous_cd = true
	bola.contact_monitor = true      # para saber cuando le pega a la puerta
	bola.max_contacts_reported = 4
	bola.freeze = true
	var col := CollisionShape3D.new()
	var esf := SphereShape3D.new()
	esf.radius = Util.RADIO
	col.shape = esf
	bola.add_child(col)

	# el .fbx es una escena entera (cuerpo, garras y ojos, cada uno con su
	# material) y trae animaciones sueltas de Blender: una camara y unas cajas
	# que, si alguna arrancara, moverian el modelo. Fuera.
	vista = (load(MODELO_BOLA) as PackedScene).instantiate()
	var reproductor := vista.get_node_or_null("AnimationPlayer")
	if reproductor:
		reproductor.free()
	# la vista se coloca a mano en coordenadas de mundo, no la arrastra la bola
	vista.top_level = true
	bola.add_child(vista)

	estela = Util.particulas(Color(1, 1, 1, 0.5), 0.4, 20)
	estela.one_shot = false
	estela.emitting = false
	bola.add_child(estela)
	add_child(bola)
	# ya en el arbol y sin mover: las cajas globales de las mallas son la caja
	# del modelo en sus propias unidades
	_caja_bola = _preparar_modelo(vista)
	_diam_bola = maxf(_caja_bola.size[_caja_bola.size.max_axis_index()], 0.0001)
	_escalar_vista(1.0)


## El piche no es una bola, es un disco: su lado corto es la X del modelo
## (1.43 contra 2.05 y 2.17), asi que esa es la cara plana. Rueda como una
## RUEDA, con la cara plana de eje; acumulando la vuelta sin mas caia de canto
## y avanzaba de costado.
##
## Tampoco vale la vuelta del cuerpo rigido: la esfera de colision son 2 cm y a
## 4 m/s giraria a 200 rad/s, un borron. Se rueda como rodaria un disco del
## tamano DIBUJADO, con tope para que a velocidad de drive siga leyendose.
func _rodar(e: float, dt: float) -> Basis:
	var plana := Vector3(bola.linear_velocity.x, 0.0, bola.linear_velocity.z)
	if plana.length() > 0.05:
		# el eje se recoloca con el rumbo: la rueda gira para seguir la linea
		_dir_rueda = plana.normalized()
		_eje_rueda = Vector3.UP.cross(_dir_rueda)
		var radio := _diam_bola * e * 0.5
		if dt > 0.0 and radio > 0.0:
			_angulo_rueda += minf(plana.length() / radio, GIRO_MAX) * dt
	elif dt > 0.0 and golpe.activo:
		# quieto o girando en el sitio: A/D solo cambia la mira (golpe.gd), no
		# empuja, asi que aqui no hay avance del que sacar rumbo. Sin esto el
		# piche se quedaba mirando para el ultimo lado que rodo, y A/D no se
		# notaba en el modelo, solo en la camara. Se sigue la mira y se gira
		# sobre el propio eje lo mismo que giro ella, como si pivotara.
		# Solo con activo=true (el jugador manda): si no, un golpe real que
		# frena por debajo de 0.05 antes de quedar "quieto" haria que el
		# piche pegara un giro brusco hacia la mira vieja del ultimo apunte.
		var d_mira := wrapf(golpe.mira - _mira_rueda, -PI, PI)
		_mira_rueda = golpe.mira
		_dir_rueda = Vector3(sin(golpe.mira), 0, cos(golpe.mira))
		_eje_rueda = Vector3.UP.cross(_dir_rueda)
		_angulo_rueda += absf(d_mira)
	return Basis(_eje_rueda, _angulo_rueda) \
		* Basis(_eje_rueda, Vector3.UP, _dir_rueda)


## Junta la caja de todas las mallas del modelo y les da algo de brillo: el
## .fbx las exporta con rugosidad 1, y sin un reflejo el piche vuelve a leerse
## como una silueta plana por muy bien iluminado que este.
func _preparar_modelo(raiz: Node3D) -> AABB:
	var caja := AABB()
	var primera := true
	for n in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var c: AABB = mi.global_transform * mi.mesh.get_aabb()
		caja = c if primera else caja.merge(c)
		primera = false
		for i in mi.mesh.get_surface_count():
			var mat: StandardMaterial3D = mi.get_active_material(i)
			if mat:
				mat.roughness = 0.55
	assert(not primera, "el modelo de la bola no trae ninguna malla")
	return caja


## Escala el modelo para que ocupe VISTA_PANTALLA del alto del encuadre, este
## donde este la camara y con el fov que tenga. Nunca por debajo del tamano real.
##
## El apoyo es lo delicado: el piche gira con la bola, asi que su punto mas bajo
## cambia con la vuelta que lleve. Se calcula la caja YA GIRADA y se apoya justo
## en el punto de contacto de la bola. Antes el levante iba en ejes de la bola y
## al rodar apuntaba hacia abajo: por eso se hundia en el mapa.
func _escalar_vista(dist: float, dt := 0.0) -> void:
	var alto := 2.0 * dist * tan(deg_to_rad(camara.fov) * 0.5)
	var e := clampf(VISTA_PANTALLA * alto, Util.RADIO * 2.0, VISTA_MAX) / _diam_bola
	var base := _rodar(e, dt).scaled(Vector3.ONE * e)
	var caja := Transform3D(base, Vector3.ZERO) * _caja_bola
	vista.global_transform = Transform3D(base, bola.global_position - Vector3(
		caja.get_center().x, caja.position.y + Util.RADIO, caja.get_center().z))


## Planta la jaula en el tee, con la puerta mirando a la bandera y la bola ya
## dentro. Los cuerpos de la jaula se sacan de los rayos de altura: si no, el
## rayo del tee daria en su techo y todo se colocaria dos metros mas arriba.
func _montar_jaula() -> void:
	for n in [_jaula, _bisagra]:
		if is_instance_valid(n):
			n.queue_free()
	_jaula = (load(JAULA) as PackedScene).instantiate()
	add_child(_jaula)
	var t := campo.pos_tee()
	var b := campo.pos_bandera()
	_jaula.global_position = Vector3(t.x, campo.altura_terreno(t.x, t.z), t.z)
	# la cara de la puerta es el +X del modelo: se gira para que apunte al hoyo
	_jaula.rotation.y = atan2(-(b.z - t.z), b.x - t.x)

	_puerta = _jaula.find_child("Plane_002", true, false)
	campo.excluir = [bola.get_rid()]
	_murar()
	_tapar_puerta()
	for sb in _jaula.find_children("*", "StaticBody3D", true, false):
		campo.excluir.append((sb as StaticBody3D).get_rid())


## Caja de una malla, en coordenadas de la jaula. Se compone a mano subiendo
## por los padres en vez de ir a mundo y volver: Transform3D * AABB REALINEA la
## caja con los ejes, asi que ida y vuelta la infla. Con la jaula girada hacia
## la bandera dejaba una jaula de 3.13 m en vez de 2, y una puerta de 63 cm de
## grosor en vez de 12: los muros quedaban lejos y el hueco era un porton.
func _caja_en_jaula(m: MeshInstance3D) -> AABB:
	var t := m.transform
	var n := m.get_parent()
	while n != _jaula and n is Node3D:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t * m.mesh.get_aabb()


## La colision de la jaula NO es su malla. Los barrotes tienen hueco entre ellos
## y una bola de 4 cm se cuela por cualquiera: con trimesh la jaula era un
## colador, y habia que atar la bola aparte con un circulo que ademas
## desaparecia al romper la puerta. Aqui se levantan muros macizos por fuera de
## cada cara, recortando SOLO el hueco de la puerta. La unica salida es la
## puerta, con la jaula entera o con ella ya tirada.
func _murar() -> void:
	var cuerpo: MeshInstance3D = _jaula.find_child("jaula", true, false)
	var j := _caja_en_jaula(cuerpo)
	var d := _caja_en_jaula(_puerta)
	var x0 := j.position.x
	var x1 := j.position.x + j.size.x
	var z0 := j.position.z
	var z1 := j.position.z + j.size.z
	var alto := j.size.y
	# bajan medio metro bajo el suelo: en cuesta, si no, queda una rendija
	var h := alto + 0.5
	var y := (alto - 0.5) * 0.5
	_muro(Vector3(MURO, h, j.size.z), Vector3(x0 - MURO * 0.5, y, j.get_center().z))
	_muro(Vector3(j.size.x, h, MURO), Vector3(j.get_center().x, y, z0 - MURO * 0.5))
	_muro(Vector3(j.size.x, h, MURO), Vector3(j.get_center().x, y, z1 + MURO * 0.5))
	# techo: sin el, un brinco de 1.56 m casi despeja el 1.65 de la jaula
	_muro(Vector3(j.size.x, MURO, j.size.z),
		Vector3(j.get_center().x, alto + MURO * 0.5, j.get_center().z))
	# la cara +X es la de la puerta: dos jambas y un dintel, con el hueco libre
	var hz0 := d.position.z
	var hz1 := d.position.z + d.size.z
	var dintel := d.position.y + d.size.y
	_muro(Vector3(MURO, h, hz0 - z0), Vector3(x1 + MURO * 0.5, y, (z0 + hz0) * 0.5))
	_muro(Vector3(MURO, h, z1 - hz1), Vector3(x1 + MURO * 0.5, y, (hz1 + z1) * 0.5))
	_muro(Vector3(MURO, alto - dintel, hz1 - hz0),
		Vector3(x1 + MURO * 0.5, (dintel + alto) * 0.5, (hz0 + hz1) * 0.5))


func _muro(medidas: Vector3, donde: Vector3) -> void:
	var forma := BoxShape3D.new()
	forma.size = medidas
	var cs := CollisionShape3D.new()
	cs.shape = forma
	var cuerpo := StaticBody3D.new()
	cuerpo.add_child(cs)
	_jaula.add_child(cuerpo)
	cuerpo.position = donde


## Lo que cierra el hueco mientras la puerta aguante: el panel arranca a 19 cm
## del suelo y la bola se colaba por debajo, asi que su caja baja hasta el piso.
func _tapar_puerta() -> void:
	var c := _caja_en_jaula(_puerta)
	var alto := c.position.y + c.size.y
	var forma := BoxShape3D.new()
	forma.size = Vector3(c.size.x, alto, c.size.z)
	var cs := CollisionShape3D.new()
	cs.shape = forma
	_tapa = StaticBody3D.new()
	_tapa.add_child(cs)
	_jaula.add_child(_tapa)
	_tapa.position = Vector3(c.get_center().x, alto * 0.5, c.get_center().z)


## El impulso tira la puerta: se le cuelga una bisagra en el canto de abajo y
## cae hacia fuera. Su colision se va con ella, que es lo que abre el hueco.
func _tirar_puerta() -> void:
	if not is_instance_valid(_puerta):
		return
	var caja: AABB = _puerta.global_transform * _puerta.mesh.get_aabb()
	var fuera := _jaula.global_basis.x
	fuera.y = 0.0
	fuera = fuera.normalized()


	# la bisagra cuelga de juego, no de la jaula: su padre tiene que estar sin
	# girar para que el eje de caida, que es de mundo, valga tal cual
	_bisagra = Node3D.new()
	add_child(_bisagra)
	_bisagra.global_position = Vector3(caja.get_center().x, caja.position.y,
		caja.get_center().z)
	var antes := _puerta.global_transform
	_puerta.get_parent().remove_child(_puerta)
	_bisagra.add_child(_puerta)
	_puerta.global_transform = antes

	var tw := create_tween()
	tw.tween_property(_bisagra, "quaternion",
		Quaternion(Vector3.UP.cross(fuera), deg_to_rad(PUERTA_CAE)), 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	Util.reventar(self, caja.get_center(), Color(0.62, 0.56, 0.48), 16)
	_puerta = null


## El suelo hasta donde se puede andar, pintado. Se dibuja una vez por anclaje
## y no por fotograma: cada punto es un rayo contra el terreno y son 128.
func _crear_limite() -> void:
	_limite = MeshInstance3D.new()
	_limite.mesh = ImmediateMesh.new()
	var m := Util.mat(Color.WHITE)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED   # se mira desde arriba y de lado
	_limite.material_override = m
	_limite.top_level = true
	add_child(_limite)


## Fija el centro del circulo donde esta la bola y redibuja el borde.
func _anclar() -> void:
	_ancla = bola.global_position
	# se muestrea en anillos concentricos y se cosen entre si: pintar un solo
	# disco plano se hundiria en cuanto el terreno tuviera algo de pendiente
	var aros: Array[PackedVector3Array] = []
	for k in ANILLOS + 1:
		var r := RADIO_ANDAR * k / float(ANILLOS)
		var aro := PackedVector3Array()
		for i in PASOS_LIMITE:
			var a := TAU * i / PASOS_LIMITE
			var x := _ancla.x + cos(a) * r
			var z := _ancla.z + sin(a) * r
			# los rayos de altura pegan en la primera colision, que bajo un
			# arbol es la copa y no el suelo. Sin acotar, un vertice se iba 15 m
			# arriba y el area se volvia un telon delante de la camara. En 5 m
			# el terreno no da mas de metro y medio.
			var h := clampf(campo.altura_terreno(x, z), _ancla.y - 1.5, _ancla.y + 1.5)
			aro.push_back(Vector3(x, h + 0.08, z))
		aros.append(aro)

	var im: ImmediateMesh = _limite.mesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in ANILLOS:
		for i in PASOS_LIMITE:
			var j := (i + 1) % PASOS_LIMITE
			im.surface_add_vertex(aros[k][i])
			im.surface_add_vertex(aros[k + 1][i])
			im.surface_add_vertex(aros[k + 1][j])
			im.surface_add_vertex(aros[k][i])
			im.surface_add_vertex(aros[k + 1][j])
			im.surface_add_vertex(aros[k][j])
	im.surface_end()


func _crear_ui() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)

	hud = Label.new()
	hud.position = Vector2(24, 18)
	hud.add_theme_font_size_override("font_size", 20)
	capa.add_child(hud)

	msg = Label.new()
	msg.add_theme_font_size_override("font_size", 44)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	capa.add_child(msg)

	barra = ProgressBar.new()
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(320, 22)
	barra.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 40)
	capa.add_child(barra)

	barra_stam = ProgressBar.new()
	barra_stam.show_percentage = false
	barra_stam.max_value = STAMINA_MAX
	barra_stam.custom_minimum_size = Vector2(320, 14)
	barra_stam.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM,
		Control.PRESET_MODE_MINSIZE, 72)
	capa.add_child(barra_stam)

	if DisplayServer.is_touchscreen_available():
		var pegar := Button.new()
		pegar.text = "GOLPE"
		pegar.custom_minimum_size = Vector2(190, 190)
		pegar.focus_mode = Control.FOCUS_NONE   # con foco, el espacio lo pulsaria
		pegar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT,
			Control.PRESET_MODE_MINSIZE, 32)
		pegar.button_down.connect(func(): golpe.cargar())
		pegar.button_up.connect(func(): golpe.soltar())
		capa.add_child(pegar)

		var drop := Button.new()
		drop.text = "DROP +1"
		drop.custom_minimum_size = Vector2(130, 64)
		drop.focus_mode = Control.FOCUS_NONE
		drop.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT,
			Control.PRESET_MODE_MINSIZE, 24)
		drop.pressed.connect(_drop)
		capa.add_child(drop)


func _ir_a_hoyo(i: int) -> void:
	_marcas.clear()
	campo.ir_a(i)
	golpe.reset(campo.pos_tee(), campo.pos_bandera())
	golpe.viento = campo.viento()
	stamina = STAMINA_MAX
	_poner_bola(campo.pos_tee())
	_montar_jaula()    # despues de colocar la bola: la deja dentro
	golpe.encuadrar()


func _poner_bola(donde: Vector3) -> void:
	bola.freeze = true
	bola.linear_velocity = Vector3.ZERO
	bola.angular_velocity = Vector3.ZERO
	bola.global_position = Vector3(donde.x,
		campo.altura_terreno(donde.x, donde.z) + Util.RADIO, donde.z)
	bola.angular_damp = 0.6
	quieto = true
	_saltando = false
	_en_aire = false
	_giro = 0.0
	estela.emitting = false
	_t_lento = 0.0
	_t_caida = 0.0
	_mira_rueda = golpe.mira  # que no arranque girando por la diferencia con la mira anterior
	_aplicar_damp()
	_anclar()


func _aplicar_damp() -> void:
	var p := bola.global_position
	bola.linear_damp = campo.damp_suelo() * campo.factor_damp(campo.zona(p.x, p.z))


func _drop() -> void:
	if not (quieto and not embocada and listo):
		return
	golpes += PENA_DROP
	_poner_bola(bola.global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))
	_aviso("Drop  +%d" % PENA_DROP, 1.0)


func _on_golpeado(velocidad: Vector3) -> void:
	golpes += 1
	# fuerza sigue puesta: golpe.gd la borra despues de emitir
	stamina = maxf(0.0, stamina - STAMINA_IMPULSO * golpe.fuerza)
	_desde = bola.global_position
	_aire = AIRE_TIEMPO
	_v_pendiente = velocidad
	_golpe_volo = false
	# el angulo de salida ya es fijo, asi que el efecto sale casi constante; lo
	# que si cambia es el rough, de donde la bola sale sin freno
	var z := campo.zona(_desde.x, _desde.z)
	_giro = clampf(velocidad.normalized().y * 2.2, 0.25, 1.0) * campo.retiene_efecto(z)


func _process(dt: float) -> void:
	if not listo:
		return
	golpe.activo = quieto and not embocada
	# desde el rough se controla peor: el mismo dato que retiene el efecto
	golpe.estabilidad = campo.retiene_efecto(campo.zona(
		bola.global_position.x, bola.global_position.z))
	# sin stamina no hay impulso: la barra no sube y cargar() ni empieza
	golpe.tope = clampf(stamina / STAMINA_IMPULSO, 0.0, 1.0)
	golpe.puede_saltar = stamina >= STAMINA_MIN
	golpe.enjaulado = _en_la_jaula()

	var cogidas := campo.recoger(bola.global_position, R_RECOGE)
	if cogidas > 0:
		stamina = minf(STAMINA_MAX, stamina + cogidas * STAMINA_BASURA)
		_aviso("+%d stamina" % roundi(cogidas * STAMINA_BASURA), 0.8)

	# espacio (o X del mando) salta. Flanco a mano: no hay accion en el mapa.
	var salta := Input.is_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0, JOY_BUTTON_X)
	if salta and not _pulso_salto:
		_saltar()
	_pulso_salto = salta

	# el suelo es rojizo siempre, que es lo que marca el area; se satura cuando
	# ya no queda para el impulso. El verde/rojo de la stamina vive en su barra.
	var hay := stamina >= STAMINA_MIN
	_limite.visible = golpe.activo and not _enjaulado()
	_limite.material_override.albedo_color = (Color(0.85, 0.25, 0.20, 0.26)
		if hay else Color(1.0, 0.18, 0.12, 0.42))
	barra_stam.value = stamina
	barra_stam.modulate = Color(0.45, 1.0, 0.55) if hay else Color(1.0, 0.4, 0.35)

	if golpe.activo and Input.is_key_pressed(KEY_R):
		_drop()

	campo.mover_animales(dt, bola.global_position,
		not quieto and bola.linear_velocity.length() > 10.0)

	# Que la bola no se pierda de vista. Parada se dibuja a tamano real, que es
	# cuando la camara esta encima y se vería un melon al lado del palo; en
	# juego se agranda con la distancia, de modo que ocupa siempre lo mismo.
	_escalar_vista(camara.global_position.distance_to(bola.global_position), dt)

	barra.value = golpe.fuerza * 100.0
	var p := bola.global_position
	var b := campo.pos_bandera()
	var dist := Vector2(p.x - b.x, p.z - b.z).length()
	var v := campo.viento()
	hud.text = ("Hoyo %d/%d | Par %d | Golpes %d | %d puntos | %d m al hoyo\n"
		+ "Stamina %d | basura %d | Fuerza %d%% (%.0f m/s) +-%.1f deg | %s | viento %.0f m/s\n"
		+ "Timon %s") % [
		indice + 1, Campo.HOYOS.size(), campo.par(), golpes, total, roundi(dist),
		roundi(stamina), campo.basura.size(),
		roundi(golpe.fuerza * 100), golpe.velocidad(),
		rad_to_deg(golpe.dispersion()),
		campo.nombre_zona(campo.zona(p.x, p.z)), Vector2(v.x, v.z).length(),
		"#".repeat(ceili(_aire / AIRE_TIEMPO * 10.0)) if _aire > 0.0 else "-"]


func _physics_process(dt: float) -> void:
	if not listo or embocada:
		return

	# el golpe se aplica aqui: descongelar y empujar en el mismo tick de fisica
	if _v_pendiente != Vector3.ZERO:
		bola.freeze = false
		quieto = false
		_t_lento = 0.0
		_saltando = false
		bola.apply_central_impulse(_v_pendiente * Util.MASA)
		_v_pendiente = Vector3.ZERO
		return

	if quieto:
		_conducir()
		if _saltando:
			_aterrizar()
		_atar()
		# tambien vale meterlo rodando: es la parte de "llevalo tu" de SBG
		if campo.embocada(bola.global_position):
			_embocar()
		return

	var pos := bola.global_position
	var vel := bola.linear_velocity
	if pos.y < -60.0:
		_poner_bola(_desde)
		return

	if campo.embocada(pos):
		_embocar()
		return

	var suelo := campo.altura_terreno(pos.x, pos.z)
	var volando := pos.y > suelo + Util.RADIO + 0.4
	_golpe_volo = _golpe_volo or volando
	var zona := campo.zona(pos.x, pos.z)
	bola.linear_damp = 0.0 if volando else campo.damp_suelo() * campo.factor_damp(zona)
	estela.emitting = volando and vel.length() > 20.0
	if _en_aire and not volando:
		if vel.length() > VEL_MARCA:
			_marca(pos, vel.length())
		# el toque de aterrizaje: como el piche cae con backspin, aqui pierde
		# de golpe casi toda la velocidad en vez de seguir rodando largo. El
		# giro tambien se corta, si no la friccion lo va reacelerando y el
		# check de "quieto" (que mira angular_velocity) no llega a cumplirse.
		bola.linear_velocity *= FRENO_ATERRIZAJE
		bola.angular_velocity *= FRENO_ATERRIZAJE
		vel = bola.linear_velocity
	_en_aire = volando

	# Solo por aqui, que es el camino del impulso: andando o brincando la bola
	# sigue "quieta", asi que empujar la puerta o subirse encima no la tira.
	_chocar_puerta()

	_giro = maxf(0.0, _giro - dt / Util.VIDA_GIRO)
	bola.apply_central_force(Util.fuerza_aire(vel, campo.viento(), _giro))

	# timon: solo en el aire y solo mientras quede presupuesto. Empuja de lado,
	# perpendicular al avance, asi que corrige la linea sin regalar distancia.
	var plana := Vector3(vel.x, 0, vel.z)
	if volando and _aire > 0.0 and absf(golpe.timon) > 0.05 and plana.length() > 1.0:
		var lado := Vector3.UP.cross(plana.normalized())
		bola.apply_central_force(lado * golpe.timon * AIRE_ACEL * Util.MASA)
		_aire = maxf(0.0, _aire - dt)

	if campo.choque(pos, vel) == "animal":
		golpes += PENA_ANIMAL
		_aviso("Le diste a un animal!  +%d golpes" % PENA_ANIMAL, 1.2)

	# ponytail: el frenado es exponencial, asi que la cola es larga y la bola
	# repta un rato. Si se nota flotante, cambiarlo por resistencia a la
	# rodadura: fuerza constante en contra, no proporcional a la velocidad.
	if not volando:
		var casi_quieta := vel.length() < QUIETA and bola.angular_velocity.length() < QUIETA_GIRO
		_t_lento = _t_lento + dt if casi_quieta else 0.0
		# CAIDA_MAX solo corta el REBOTE despues de un golpe que voló: para un
		# piche corto que nunca despega (un putt) no hay caida que cortar, y
		# aplicarlo igual lo paraba en seco a mitad de rodada. Sin volar de
		# por medio, se frena solo como siempre: gradual, con el damp del suelo.
		var corte_por_tiempo := false
		if _golpe_volo:
			_t_caida += dt
			corte_por_tiempo = _t_caida >= CAIDA_MAX
		if _t_lento >= ESPERA_QUIETA or corte_por_tiempo:
			bola.linear_velocity = Vector3.ZERO
			bola.angular_velocity = Vector3.ZERO
			bola.freeze = true
			quieto = true
			_ultimo = Vector2(pos.x - _desde.x, pos.z - _desde.z).length()
			if _enjaulado():
				# por si el impulso no llego a tocarla: siempre la tira, o el
				# jugador se quedaria encerrado gastando golpes
				_tirar_puerta()
				_abrir_puerta()
			_anclar()
			_aviso("%d m" % roundi(_ultimo), 1.6)
	else:
		_t_lento = 0.0
		_t_caida = 0.0


## El stick izquierdo rueda el piche mientras esta parado. En el aire ese mismo
## stick es el timon, asi que no se pisan. El tope de velocidad es lo que separa
## andar de pegar: para cruzar el campo hay que golpear.
func _conducir() -> void:
	var dir: Vector3 = golpe.mando()
	if dir == Vector3.ZERO:
		# sin mando no se mueve nada. Si quedo descongelada de un empujon
		# anterior, aqui mismo se frena y se congela: si no, quedaba como
		# cuerpo rigido libre y la gravedad/la pendiente la seguian moviendo
		# solas hasta el proximo empujon. Que la mueva solo el jugador.
		if not bola.freeze:
			bola.linear_velocity = Vector3.ZERO
			bola.angular_velocity = Vector3.ZERO
			bola.freeze = true
		return
	if Vector3(bola.linear_velocity.x, 0, bola.linear_velocity.z).length() > CONDUCE_MAX:
		return
	# la correa: andando no se sale del circulo. En el borde se deja empujar
	# hacia dentro, si no se quedaria pegado al limite sin poder volver.
	var fuera := Vector2(bola.global_position.x - _ancla.x,
		bola.global_position.z - _ancla.z)
	if not _saltando and fuera.length() >= RADIO_ANDAR \
			and Vector2(dir.x, dir.z).dot(fuera.normalized()) > 0.0:
		return
	bola.freeze = false      # congelada no admite fuerzas
	# que una pendiente no desvie el rumbo: se descarta la parte de la
	# velocidad que no va en la linea de "dir" (adelante/atras), que es lo
	# unico que el jugador esta pidiendo. Sin esto, en una bajada la
	# gravedad la iba corriendo de costado aunque se empujara derecho.
	var recta := dir.normalized()
	var horizontal := Vector3(bola.linear_velocity.x, 0, bola.linear_velocity.z)
	bola.linear_velocity = recta * horizontal.dot(recta) + Vector3.UP * bola.linear_velocity.y
	bola.apply_central_force(dir * CONDUCE_ACEL * Util.MASA)


## Andando no se sale del circulo. No basta con dejar de empujar: con la
## inercia se cruzaba igual. Se le quita la velocidad que apunta hacia fuera y
## se le devuelve al borde.
##
## ponytail: mover un cuerpo rigido a mano fuera de _integrate_forces no es lo
## fino, pero aqui son centimetros y solo en el borde. Si diera guerra, lo suyo
## seria un muro de colision cilindrico que se mueve con el ancla.
## El salto (espacio) despega con lo que ya lleve encima y sirve para salir del
## area: mientras esta en el aire no hay correa, y al caer se ancla donde quede.
##
## No toca `quieto`. Sacar la bola de ese estado la metia por el camino del
## golpe: la camara se iba atras, el area desaparecia y al caer salia el aviso
## de distancia. O sea que un brinco se veia igual que un impulso y cortaba el
## juego. Aqui se sigue andando, solo que por el aire.
func _saltar() -> void:
	if _saltando or not (listo and quieto and not embocada) or stamina < STAMINA_SALTO:
		return
	stamina -= STAMINA_SALTO
	_saltando = true
	bola.freeze = false      # congelada no admite ni fuerzas ni velocidad
	bola.linear_velocity += Vector3.UP * IMPULSO_SALTO


## Abre el hueco de verdad. Va aparte de tirar la puerta a proposito: la puerta
## se cae en cuanto la bola le pega, para que se vea, pero el hueco no se abre
## hasta que la bola para. Si se abriera al momento, la misma bola que acaba de
## romperla saldria disparada por el hueco en el mismo impulso, y la idea es que
## el primero rompa y rebote dentro, y el siguiente ya salga.
func _abrir_puerta() -> void:
	if is_instance_valid(_tapa):
		campo.excluir.erase(_tapa.get_rid())
		_tapa.queue_free()


## La puerta se cae cuando la bola le pega, no al apretar el boton: asi se ve
## el golpe y el rebote, que es lo que cuenta el primer impulso.
func _chocar_puerta() -> void:
	if not (is_instance_valid(_tapa) and is_instance_valid(_puerta)):
		return
	for c in bola.get_colliding_bodies():
		if c == _tapa:
			_tirar_puerta()
			return


## Cierra el brinco al tocar suelo bajando, y ancla el area donde haya caido.
func _aterrizar() -> void:
	var p := bola.global_position
	if bola.linear_velocity.y > 0.0 or p.y > campo.altura_terreno(p.x, p.z) + Util.RADIO + 0.06:
		return
	_saltando = false
	_anclar()


## La puerta sigue en pie: la salida esta tapada.
func _enjaulado() -> bool:
	return is_instance_valid(_tapa)


## Otra pregunta distinta de _enjaulado(): esa mira si la puerta sigue puesta,
## que es lo que ata la correa. Esta mira si el piche sigue entre los barrotes,
## que es lo que aparta la camara. Al caer la puerta la jaula sigue ahi, y sin
## esto la camara se metia dentro a mirar los barrotes.
func _en_la_jaula() -> bool:
	if not is_instance_valid(_jaula):
		return false
	return Vector2(bola.global_position.x - _jaula.global_position.x,
		bola.global_position.z - _jaula.global_position.z).length() < 1.8


func _atar() -> void:
	# brincar es como se sale del area; de la jaula sacan los muros, no esto
	if _saltando:
		return
	var d := Vector2(bola.global_position.x - _ancla.x,
		bola.global_position.z - _ancla.z)
	if d.length() <= RADIO_ANDAR:
		return
	var n := d.normalized()
	var fuera := Vector3(n.x, 0, n.y)
	var salida := bola.linear_velocity.dot(fuera)
	if salida > 0.0:
		bola.linear_velocity -= fuera * salida
	bola.global_position = Vector3(_ancla.x + n.x * RADIO_ANDAR,
		bola.global_position.y, _ancla.z + n.y * RADIO_ANDAR)


func _marca(pos: Vector3, v: float) -> void:
	var r := clampf(v * 0.005, 0.06, 0.35)
	var m := Util.disco(r, 0.02, Color(0.30, 0.24, 0.14))
	m.position = Vector3(pos.x, campo.altura_terreno(pos.x, pos.z) + 0.02, pos.z)
	campo.add_child(m)
	_marcas.append(m)
	if _marcas.size() > MAX_MARCAS:
		var viejo: Node3D = _marcas.pop_front()
		if is_instance_valid(viejo):
			viejo.queue_free()
	Util.reventar(campo, pos, Color(0.35, 0.30, 0.18), 10)


func _aviso(texto: String, seg: float) -> void:
	msg.text = texto
	await get_tree().create_timer(seg).timeout
	if msg.text == texto:
		msg.text = ""


func _embocar() -> void:
	embocada = true
	bola.freeze = true
	estela.emitting = false
	tarjeta.append(golpes)
	var d := golpes - campo.par()
	# SBG puntua en vez de contar golpes: terminar vale, ahorrar golpes vale mas
	var puntos := maxi(0, PUNTOS_HOYO - d * PUNTOS_GOLPE)
	total += puntos
	msg.text = "%s  +%d" % [
		"Birdie!" if d < 0 else ("Par" if d == 0 else "+%d" % d), puntos]
	await get_tree().create_timer(1.8).timeout
	msg.text = ""
	golpes = 0
	indice += 1
	if indice >= Campo.HOYOS.size():
		indice = 0
		total = 0
		tarjeta.clear()
	_ir_a_hoyo(indice)
	embocada = false


## Los asserts de arriba miran datos: que la jaula este puesta y mire al hoyo.
## Que RETENGA es otra cosa, y solo se sabe con la fisica corriendo. Aqui se
## empuja la bola contra la puerta y se comprueba que no sale; luego se tira la
## puerta y se comprueba que ahora si. Solo en headless: mueve la bola de
## verdad y en una partida se veria.
func _probar_jaula() -> void:
	var a_puerta := _jaula.global_basis.x       # la cara de la puerta es el +X
	var a_barrotes := _jaula.global_basis.z     # una cara ciega

	# 1. contra la puerta no se sale, y ANDANDO no se cae: solo la tira el impulso
	var p := await _empujar(a_puerta)
	var tope_puerta := _caja_en_jaula(_puerta).position.x
	print("jaula: contra la puerta, la bola queda en x=%.2f (puerta en %.2f)"
		% [p.x, tope_puerta])
	assert(p.x < tope_puerta, "la puerta no para a la bola andando")
	assert(is_instance_valid(_puerta), "andar contra la puerta la tira")

	# 2. y por los barrotes tampoco, que era el colador de la malla
	var b := await _empujar(a_barrotes)
	print("jaula: contra los barrotes, la bola queda en z=%.2f" % b.z)
	assert(absf(b.z) < 1.0, "la bola se cuela entre los barrotes")

	# 3. brincar ni tira la puerta ni despeja el techo
	_poner_bola(campo.pos_tee())
	_saltar()
	var cima := 0.0
	for i in 120:
		await get_tree().physics_frame
		var y: float = (_jaula.global_transform.affine_inverse() * bola.global_position).y
		cima = maxf(cima, y)
	print("jaula: brincando sube hasta y=%.2f" % cima)
	assert(cima > 0.5, "el brinco no despega dentro de la jaula")
	assert(cima < 1.65, "el brinco se sale por el techo")
	assert(is_instance_valid(_puerta), "brincar tira la puerta")

	# 4. con la puerta tirada se sale, pero SOLO por el hueco
	_tirar_puerta()
	_abrir_puerta()                 # como al pararse tras el primer impulso
	_poner_bola(campo.pos_tee())
	var f := await _empujar(a_puerta)
	print("jaula: con la puerta tirada, sale a x=%.2f" % f.x)
	assert(f.x > 1.2, "con la puerta tirada la bola sigue encerrada")
	_poner_bola(campo.pos_tee())
	var g := await _empujar(a_barrotes)
	print("jaula: y por los barrotes sigue sin pasar, z=%.2f" % g.z)
	assert(absf(g.z) < 1.0, "rota la puerta, la bola se cuela por los barrotes")

	_poner_bola(campo.pos_tee())
	_montar_jaula()


## Empuja la bola en linea recta un rato y devuelve donde acabo, en coordenadas
## de la jaula. Le anula la velocidad lateral en cada tick: en cuesta se iba de
## lado y acababa contra otra pared, asi que la prueba no medía lo que creia.
func _empujar(dir: Vector3) -> Vector3:
	var d := dir.normalized()
	var empuje := d * CONDUCE_ACEL * 2.0 * Util.MASA
	for i in 150:
		# cada tick: _conducir() congela la bola cuando no hay mando, y aqui se
		# empuja a mano sin pasar por el mando
		bola.freeze = false
		var v := bola.linear_velocity
		bola.linear_velocity = d * v.dot(d) + Vector3.UP * v.y
		bola.apply_central_force(empuje)
		await get_tree().physics_frame
	return _jaula.global_transform.affine_inverse() * bola.global_position


# ponytail: un solo chequeo, salta si el campo o el hoyo se montan mal
func _self_check() -> void:
	var t := campo.pos_tee()
	var b := campo.pos_bandera()
	assert(t != Vector3.ZERO and b != Vector3.ZERO, "tee o bandera sin colocar")
	assert(absf(t.y) > 0.01, "el rayo de altura no encuentra el campo bajo el tee")
	assert(campo.R_COPA > Util.RADIO * 1.5, "la copa no admite la bola")
	# el piche ocupa lo mismo en pantalla mientras no llegue al tope de tamano:
	# eso es lo que lo salva cuando la camara se queda atras en un vuelo largo
	_escalar_vista(1.0)
	var cerca := _diam_bola * vista.scale.x / 1.0
	_escalar_vista(1.6)
	assert(is_equal_approx(cerca, _diam_bola * vista.scale.x / 1.6),
		"la bola no mantiene el tamano en pantalla")
	# y de ahi no crece, o al lado de la jaula parecia un monstruo
	_escalar_vista(60.0)
	assert(_diam_bola * vista.scale.x <= VISTA_MAX + 0.001,
		"la bola pasa del tope de tamano")
	# y apoyarse en el suelo con cualquier vuelta, que es lo que se hundia
	_angulo_rueda = 2.1
	_escalar_vista(6.0)
	var apoyo: AABB = vista.global_transform * _caja_bola
	assert(absf(apoyo.position.y - (bola.global_position.y - Util.RADIO)) < 0.001,
		"el piche no se apoya en el suelo al girar")
	# y rodar como una rueda: la cara plana del disco se queda en el eje de
	# giro, perpendicular a la marcha, en vez de irse de canto
	bola.linear_velocity = Vector3(3.0, 0, 0)
	var antes := _angulo_rueda
	_escalar_vista(6.0, 0.1)
	assert(_angulo_rueda > antes, "el piche no rueda")
	assert(is_zero_approx(_eje_rueda.dot(bola.linear_velocity.normalized())),
		"la cara plana del disco no queda perpendicular a la marcha")
	bola.linear_velocity = Vector3.ZERO
	_angulo_rueda = 0.0
	assert(campo.basura.size() > 0, "el hoyo se quedo sin basura que recoger")
	# la jaula: la bola arranca dentro y la puerta mira a la bandera
	assert(is_instance_valid(_jaula) and is_instance_valid(_puerta), "no hay jaula")
	var dentro := bola.global_position - _jaula.global_position
	assert(absf(dentro.x) < 1.0 and absf(dentro.z) < 1.0, "la bola no arranca dentro")
	var al_hoyo := campo.pos_bandera() - campo.pos_tee()
	var cara := _jaula.global_basis.x
	assert(Vector2(cara.x, cara.z).normalized().dot(
		Vector2(al_hoyo.x, al_hoyo.z).normalized()) > 0.99,
		"la puerta no mira a la bandera")
	# y los rayos de altura no la ven: si no, la bola se colocaria en su techo
	assert(absf(campo.altura_terreno(bola.global_position.x, bola.global_position.z)
		- (bola.global_position.y - Util.RADIO)) < 0.2,
		"la jaula tapa los rayos de altura")
	# la correa: se le empuja lejos y tiene que volver al borde de la que toque
	var vuelve := bola.global_position
	bola.global_position = vuelve + Vector3(RADIO_ANDAR * 3.0, 0, 0)
	bola.linear_velocity = Vector3(9.0, 0, 0)
	_atar()
	assert(Vector2(bola.global_position.x - _ancla.x,
		bola.global_position.z - _ancla.z).length() <= RADIO_ANDAR + 0.001,
		"el piche se sale de la correa")
	assert(bola.linear_velocity.x <= 0.001, "no se le quita la velocidad de salida")
	bola.global_position = vuelve
	bola.linear_velocity = Vector3.ZERO
	# y sin stamina no hay impulso
	var stamina_previa := stamina
	stamina = 0.0
	golpe.puede_saltar = false
	golpe.activo = true
	golpe.cargar()
	golpe.soltar()
	assert(_v_pendiente == Vector3.ZERO, "salio impulso sin stamina")
	stamina = stamina_previa
	golpe.puede_saltar = true
	# el salto despega, cobra, y no saca a la bola del estado de andar: si lo
	# hiciera, un brinco se veria como un impulso
	var stamina_salto := stamina
	_saltar()
	assert(bola.linear_velocity.y > 0.0, "el salto no despega")
	assert(stamina == stamina_salto - STAMINA_SALTO, "el salto no cobra stamina")
	assert(quieto and golpe.activo, "el salto corta el estado de andar")
	assert(_saltando, "el salto no levanta la correa")
	bola.linear_velocity = Vector3.ZERO
	bola.freeze = true
	_saltando = false
	stamina = stamina_salto
	print("modelo %s | caja %s | diametro %.2f u"
		% [MODELO_BOLA.get_file(), str(_caja_bola), _diam_bola])
	print("self-check OK | tee %s | bandera %s | %d m | par %d"
		% [str(t.round()), str(b.round()),
		   roundi(Vector2(t.x - b.x, t.z - b.z).length()), campo.par()])
	if DisplayServer.get_name() == "headless":
		await _probar_jaula()
		await get_tree().create_timer(0.5).timeout
		golpe.activo = true      # soltar() sale de vacio si no hubo cargar()
		golpe.cargar()
		golpe.fuerza = 1.0
		golpe.soltar()
		assert(_v_pendiente != Vector3.ZERO, "el golpe no salio")
		assert(stamina < STAMINA_MAX, "el salto no gasta stamina")
		# la puerta ya no se cae al apretar: se cae cuando la bola le pega. El
		# primer impulso choca, la tira y rebota dentro de la jaula.
		await get_tree().physics_frame
		await get_tree().physics_frame
		for i in 900:
			if quieto:
				break
			await get_tree().physics_frame
		var d := bola.global_position.distance_to(_jaula.global_position)
		print("primer impulso: puerta abajo y la bola queda a %.2f m de la jaula" % d)
		assert(_puerta == null, "el primer impulso no tiro la puerta")
		assert(_tapa == null, "el hueco no quedo abierto para el siguiente")
		assert(d < 1.5, "el primer impulso se escapo de la jaula")
