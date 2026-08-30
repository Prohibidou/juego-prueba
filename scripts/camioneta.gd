extends PathFollow3D
class_name Camioneta
## La camioneta que se va: arranca al empezar el mapa y baja el cerro por el
## camino. Alcanzarla es el objetivo, asi que ES la meta -mapa.gd le pide su
## caja en vez de buscar una malla quieta en el glb-.
##
## El recorrido vive en la escena, no aca: es la `Curve3D` del `Path3D` padre,
## y se ajusta arrastrando los puntos en el editor sobre el camino de verdad.
## Poner el trazado en codigo seria clavar veinte Vector3 a mano.
##
## De la curva se usan SOLO x y z: la altura la pone un rayo al suelo en cada
## paso. Asi el artista dibuja el recorrido en planta, mirando el mapa desde
## arriba, sin tener que acertarle tambien a la cota de cada curva.

@export_range(0.5, 30.0, 0.5) var velocidad := 7.0
## Cuanto espera despues de arrancar el mapa antes de moverse. Da el respiro
## para entender que hay que perseguirla.
@export_range(0.0, 10.0, 0.1) var espera := 1.5
## A cuanto de la CARROCERIA cuenta como alcanzada. Subirse a una camioneta
## que anda es otro juego; con tocarla alcanza. Es distancia a la chapa, no al
## centro, asi que 1 m se lee como "la toco".
@export_range(0.2, 10.0, 0.1) var alcance := 1.0
## Cuanto sube el modelo sobre el suelo, para que las ruedas apoyen.
@export_range(-2.0, 2.0, 0.05) var alto_ruedas := 0.0

var _andando := false
var _suelo: Callable          # (x, z) -> altura; lo pone mapa.gd
var _caja_modelo := AABB()

@onready var _modelo: Node3D = $Modelo


func _ready() -> void:
	loop = false
	# la altura la manda el rayo, no la curva
	rotation_mode = PathFollow3D.ROTATION_XYZ
	_caja_modelo = _medir(_modelo)
	get_tree().create_timer(espera).timeout.connect(func(): _andando = true)


## Quien la monta le pasa como preguntar la altura del terreno. Es una llamada
## hacia abajo: la camioneta no sale a buscar el mapa.
func suelo(f: Callable) -> void:
	_suelo = f


func _physics_process(dt: float) -> void:
	if _andando and progress_ratio < 1.0:
		progress += velocidad * dt
		if progress_ratio >= 1.0:
			# ponytail: al final del camino se queda parada y se deja alcanzar.
			# Si tiene que poder ESCAPARSE -y perder el mapa-, aca va la senal.
			_andando = false
	_apoyar()


## Baja el modelo hasta el suelo. La curva solo dice por donde pasa en planta;
## si se usara su altura, cualquier punto mal puesto la dejaria enterrada o
## flotando sobre el camino.
##
## Se toca la posicion GLOBAL pero el modelo sigue colgando del PathFollow3D:
## con `top_level` se veia bien jugando y en el editor aparecia en el origen
## del mundo, porque esto no corre ahi. El giro lo hereda del padre.
func _apoyar() -> void:
	if not _suelo.is_valid():
		return
	var p := global_position
	_modelo.global_position = Vector3(p.x, _suelo.call(p.x, p.z) + alto_ruedas, p.z)


## Su caja en coordenadas de mundo, AHORA. Se recalcula porque se mueve: una
## caja cacheada al arrancar dejaria la meta clavada donde ya no esta.
## OJO: esta caja esta REALINEADA con los ejes del mundo, asi que girada mide
## mas que la camioneta -una de 4x8 en diagonal da 8.5x8.5-. Vale para el
## centro y el alto (que es para lo que la usan el HUD y la camara), NO para
## medir distancias: eso va en ejes del modelo, en _a_la_carroceria().
func caja() -> AABB:
	return Transform3D(_modelo.global_basis, _modelo.global_position) * _caja_modelo


## Alcanzada: el piche llego hasta ella. No hace falta subirse -la caja se
## mueve y embocar ahi seria un juego de precision que este no es-, alcanza
## con arrimarse a `alcance` de su carroceria.
func alcanzada(pos: Vector3) -> bool:
	return _a_la_carroceria(pos) < alcance


## Distancia del punto a la carroceria, EN EJES DEL MODELO.
##
## No con la caja de mundo: `Transform3D * AABB` la realinea con los ejes y la
## infla, asi que una camioneta de 4x8 puesta en diagonal pasa a medir 8.5x8.5
## y la meta se ganaba metros antes de tocarla. Se lleva el punto a ejes de la
## camioneta y ahi la caja es la de verdad (ver CLAUDE.md).
func _a_la_carroceria(pos: Vector3) -> float:
	var local := _modelo.global_transform.affine_inverse() * pos
	var c := _caja_modelo
	var cerca := Vector3(
		clampf(local.x, c.position.x, c.position.x + c.size.x),
		clampf(local.y, c.position.y, c.position.y + c.size.y),
		clampf(local.z, c.position.z, c.position.z + c.size.z))
	return local.distance_to(cerca)


## A que distancia minima le pasa el recorrido a un punto en sus primeros
## `metros`. Sirve para comprobar que la ruta se ALEJA de la salida: si le pasa
## por encima, la camioneta va a buscar al piche y el mapa se gana quieto.
func roza_en_la_salida(punto: Vector3, metros := 90.0) -> float:
	var c := (get_parent() as Path3D).curve
	var t := get_parent() as Node3D
	var minimo := INF
	var d := 0.0
	while d < metros:
		minimo = minf(minimo, (t.global_transform * c.sample_baked(d)).distance_to(punto))
		d += 2.0
	return minimo


## La caja del modelo tal cual viene, en ejes del propio modelo.
func _medir(raiz: Node3D) -> AABB:
	var caja := AABB()
	var primera := true
	for n in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var c: AABB = mi.transform * mi.mesh.get_aabb()
		caja = c if primera else caja.merge(c)
		primera = false
	assert(not primera, "la camioneta no trae ninguna malla")
	return caja
