extends Node3D
class_name Jaula
## La jaula de la que hay que salir. La puerta esta en su cara +X: se la planta
## girada hacia donde uno quiera que salga el piche.
##
## No depende de nada de fuera. Se le dice a quien vigilar y avisa por senal
## cuando ese alguien atraviesa la puerta; quien la use decide que hacer.
##
## La GEOMETRIA vive en la escena, no aca: cuerpo, puerta, bisagra, los siete
## muros y la tapa son nodos de verdad, editables en el editor. Antes se
## construian a mano en _ready a partir de las cajas de los modelos, y eso
## costo dos bugs feos: encadenar `Transform3D * AABB` inflaba la jaula de 2 a
## 3.13 m, y el AABB de una malla no dice donde se dibuja.
##
## Los muros son macizos y no la malla del modelo. Los barrotes tienen hueco
## entre ellos y el piche mide 4 cm: con la malla, la jaula era un colador.
## Solo se sale por la puerta, este entera o ya tirada.

## El vigilado atraveso la puerta. Llega la direccion de salida, ya aplanada.
signal reventada(fuera: Vector3)

const MARGEN := 0.35           # cuanto antes del plano de la puerta se dispara
# La puerta solo cede a un golpe, no a que se apoyen en ella. La jaula no sabe
# que es un "impulso" y no tiene por que saberlo: le alcanza con la velocidad.
# Empujando se anda a 4.5 m/s como mucho y un impulso pasa de 20, asi que en el
# medio hay sitio de sobra para separarlos.
const MINIMA := 10.0           # m/s por debajo de los cuales la puerta aguanta
const CAE := 250.0             # grados que da la puerta al salir despedida
const ABRE := 80.0             # los que cede mientras la empujan
const VUELA := 2.0             # metros que la manda hacia fuera el impacto

@onready var _bisagra: Node3D = $Bisagra
@onready var _puerta: Node3D = $Bisagra/Puerta
@onready var _tapa: StaticBody3D = $Tapa

var _vigilado: RigidBody3D
var _frente := 0.0             # x del plano de la puerta, en ejes de la jaula
var _ancho := 0.0              # medio ancho del hueco
var _dintel := 0.0             # hasta donde llega la puerta
var _rota := false


func _ready() -> void:
	# la tapa ES el hueco: de su caja salen las medidas con las que se decide
	# si el piche va a dar en la puerta o en una jamba
	var caja: BoxShape3D = ($Tapa/Forma as CollisionShape3D).shape
	_frente = _tapa.position.x - caja.size.x * 0.5
	_ancho = caja.size.z * 0.5
	_dintel = _tapa.position.y + caja.size.y * 0.5


## A quien mirar. Es una llamada hacia abajo: la jaula no sale a buscar el
## piche, se lo pasan.
func vigilar(cuerpo: RigidBody3D) -> void:
	_vigilado = cuerpo


## Los cuerpos de la jaula, para que quien lance rayos de altura los excluya:
## si no, el rayo del tee da en el techo y todo se coloca dos metros mas arriba.
func cuerpos() -> Array[RID]:
	var rids: Array[RID] = []
	for sb in find_children("*", "StaticBody3D", true, false):
		rids.append((sb as StaticBody3D).get_rid())
	return rids


## Sigue tapado el hueco.
func cerrada() -> bool:
	return is_instance_valid(_tapa)


## La puerta sigue en su sitio, sin tumbar.
func puerta_entera() -> bool:
	return not _rota


## x del plano de la puerta, en ejes de la jaula. Lo usan las comprobaciones
## para saber si a quien la empuja lo paro la puerta o un muro.
func frente() -> float:
	return _frente


## Apagar o encender los muros. Se apagan cuando la jaula viaja en la caja de
## la camioneta: alli al piche lo coloca el guion, no lo sostienen los muros, y
## mover ocho cuerpos estaticos cada fotograma es trabajo regalado.
func colision(activa: bool) -> void:
	for sb in find_children("*", "StaticBody3D", true, false):
		(sb as StaticBody3D).collision_layer = 1 if activa else 0


## Hacia donde escupe: su cara +X, aplanada.
func fuera() -> Vector3:
	var d := global_basis.x
	d.y = 0.0
	return d.normalized()


## Abre el hueco de verdad. Va aparte de tirar la puerta a proposito: la puerta
## se cae en cuanto le pegan, para que se vea, pero el hueco no se abre hasta
## que quien la rompio se detiene. Si se abriera al momento, el mismo impulso
## que la revento saldria disparado por el hueco.
func abrir() -> void:
	if not is_instance_valid(_tapa):
		return
	# la capa a cero deja de estorbar en ESTE tick; queue_free no borra el
	# cuerpo hasta el final del frame y el piche aun chocaria con el
	_tapa.collision_layer = 0
	_tapa.queue_free()
	_tapa = null


## Tumba la puerta. Los tiempos los pone quien llama, para que la caida cuadre
## con lo que este haciendo el piche: si la puerta tarda medio segundo mientras
## el otro recorre trece metros, los dos van lentos pero descoordinados.
func tirar_puerta(empuje: float, suelta: float) -> void:
	if _rota:
		return
	_rota = true
	# todo en ejes de la jaula: la puerta mira al +X, asi que sale hacia alli y
	# gira sobre el eje horizontal perpendicular
	var eje := Vector3.UP.cross(Vector3.RIGHT)
	var t := create_tween().set_parallel()
	# 1) cede a ritmo constante: la esta empujando algo, no cayendose sola
	t.tween_property(_bisagra, "quaternion", Quaternion(eje, deg_to_rad(ABRE)),
		empuje).set_trans(Tween.TRANS_LINEAR)
	# 2) ya suelta: termina de caer acelerando y sale despedida
	t.tween_property(_bisagra, "quaternion", Quaternion(eje, deg_to_rad(CAE)),
		suelta).set_delay(empuje).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(_bisagra, "position",
		_bisagra.position + Vector3.RIGHT * VUELA, suelta) \
		.set_delay(empuje).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	Util.reventar(self, _bisagra.global_position, Color(0.62, 0.56, 0.48), 16)


## Se mira la GEOMETRIA y no los contactos: a 26 m/s la colision la resuelve el
## CCD y get_colliding_bodies() no la reporta, asi que la puerta no caia hasta
## que el piche se paraba. El margen es generoso a proposito: un fotograma a esa
## velocidad son 43 cm y hay que cazarla igual.
func _physics_process(_dt: float) -> void:
	if _rota or _vigilado == null or not is_instance_valid(_tapa):
		return
	var salida := fuera()
	if _vigilado.linear_velocity.length() < MINIMA:
		return                                  # se apoya, no golpea
	if _vigilado.linear_velocity.dot(salida) <= 0.0:
		return                                  # va hacia dentro: no es portazo
	var p: Vector3 = global_transform.affine_inverse() * _vigilado.global_position
	if p.x < _frente - MARGEN or absf(p.z) > _ancho or p.y > _dintel:
		return                                  # lejos, o va a dar en una jamba
	reventada.emit(salida)
