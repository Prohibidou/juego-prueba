extends RigidBody3D
class_name Roca
## Una piedra que se desprende de la cima y baja rodando. Si alcanza al piche,
## lo mata.
##
## Rueda de verdad, con la fisica: no es una animacion. Por eso hay que soltarla
## EN la cima y dejar que el terreno la lleve -aparecer de golpe a mitad de
## ladera se ve como un truco-.
##
## Lo unico procedural es el TAMANO, que cambia en cada piedra: el cuerpo, su
## esfera de colision y el modelo estan en Roca.tscn.
##
## El golpe NO se detecta por contactos: una roca grande baja a mas de 20 m/s y
## a esa velocidad la colision la resuelve el CCD, que no reporta contacto (ver
## CLAUDE.md). Quien vigila mira geometria -distancia entre centros-, y para eso
## esta `pisa()`.

const RADIO_MODELO := 1.0     # el glb viene de 2 m de diametro
## Densidad de piedra, para que una roca de 3 m pese como una roca de 3 m y no
## salga rebotando como un globo.
const DENSIDAD := 2600.0

@onready var _modelo: Node3D = $Modelo
@onready var _forma: CollisionShape3D = $Forma

var _radio := 1.0


## El tamano se pone ANTES de meterla en el arbol: _ready() es quien lo aplica,
## y una vez dentro el cuerpo ya esta en el mundo de la fisica.
func tamano(r: float) -> void:
	_radio = r


func radio() -> float:
	return _radio


func _ready() -> void:
	_modelo.scale = Vector3.ONE * (_radio / RADIO_MODELO)
	# la forma es propia de esta roca: sin duplicar, todas las piedras
	# compartirian la misma esfera y la ultima le pisaria el radio a las demas
	var esfera: SphereShape3D = _forma.shape.duplicate()
	esfera.radius = _radio
	_forma.shape = esfera
	mass = DENSIDAD * 4.0 / 3.0 * PI * pow(_radio, 3)


## El piche esta dentro de la piedra. Geometria, no contactos: ver la cabecera.
func pisa(pos: Vector3, radio_piche: float) -> bool:
	return global_position.distance_to(pos) < _radio + radio_piche
