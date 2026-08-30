extends MeshInstance3D
class_name Mar
## El oleaje, en un solo sitio. Este nodo es el plano subdividido que se dibuja
## encima del mar plano del mapa, PERO ademas es la fuente de verdad de la
## forma de la ola: el shader y las chapas que flotan leen la MISMA funcion.
##
## Por eso el tiempo se manda por uniform en vez de usar TIME dentro del
## shader: con dos relojes distintos -uno de render y otro de fisica- las
## chapas subian mientras la ola bajaba, y el piche saltaba a una tabla que en
## pantalla estaba en otro sitio.
##
## No conoce a nadie de fuera. Quien quiera flotar pide altura() y normal(),
## y es mapa.gd quien se los presenta (llamadas hacia abajo).

# Los cuatro trenes cruzados. Tienen que ser IGUALES que las constantes del
# mismo nombre en mar.gdshader: si se toca uno hay que tocar el otro.
const DIRS := [Vector2(1.0, 0.25), Vector2(-0.4, 1.0),
	Vector2(0.75, -0.6), Vector2(-0.9, -0.45)]
const PESOS := [0.50, 0.28, 0.14, 0.08]
const K_MUL := [1.0, 2.1, 3.7, 6.3]
const W_MUL := [1.0, 1.3, 0.85, 1.6]

@export_range(0.0, 1.0, 0.01) var amplitud := 0.16   # metros de la cresta mas alta
@export_range(2.0, 40.0, 0.5) var largo_ola := 11.0  # metros entre crestas del tren grande
@export_range(0.0, 3.0, 0.05) var velocidad := 0.8   # uniforme: no acelera ni frena
@export_range(0.0, 1.0, 0.01) var espuma := 0.35
@export_range(0.0, 1.0, 0.01) var rugosidad := 0.06
@export var color_profundo := Color(0.02, 0.13, 0.26)
@export var color_superficie := Color(0.18, 0.58, 0.66)

var _reloj := 0.0
var _mat: ShaderMaterial


func _ready() -> void:
	_mat = material_override as ShaderMaterial
	_empujar_uniforms()


func _physics_process(delta: float) -> void:
	# el mismo reloj que leeran las chapas en SU _physics_process
	_reloj += delta
	if _mat != null:
		_mat.set_shader_parameter("tiempo", _reloj)
		# en caliente: mover un deslizador del Inspector se ve al momento
		if Engine.is_editor_hint() or OS.is_debug_build():
			_empujar_uniforms()


func _empujar_uniforms() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("amplitud", amplitud)
	_mat.set_shader_parameter("largo_ola", largo_ola)
	_mat.set_shader_parameter("velocidad", velocidad)
	_mat.set_shader_parameter("espuma", espuma)
	_mat.set_shader_parameter("rugosidad", rugosidad)
	_mat.set_shader_parameter("color_profundo", color_profundo)
	_mat.set_shader_parameter("color_superficie", color_superficie)
	_mat.set_shader_parameter("tiempo", _reloj)


## Altura de la ola sobre el plano de reposo, en un punto del MUNDO. Es la
## traduccion exacta de altura_ola() del shader.
func altura(x: float, z: float) -> float:
	var k := TAU / maxf(largo_ola, 0.001)
	var h := 0.0
	for i in DIRS.size():
		var d: Vector2 = (DIRS[i] as Vector2).normalized()
		var ki: float = k * K_MUL[i]
		var wi: float = velocidad * k * W_MUL[i]
		h += sin((x * d.x + z * d.y) * ki + _reloj * wi) * PESOS[i]
	return h * amplitud


## Y de la superficie del agua en ese punto: el reposo del plano mas la ola.
func superficie(x: float, z: float) -> float:
	return global_position.y + altura(x, z)


## Normal de la ola, por diferencias finitas de la misma altura(). Sirve para
## inclinar lo que flote encima, que es lo que hace que una chapa cabecee en
## vez de subir y bajar como un ascensor.
func normal(x: float, z: float) -> Vector3:
	var d := maxf(largo_ola, 0.001) * 0.08
	var hx := altura(x + d, z) - altura(x - d, z)
	var hz := altura(x, z + d) - altura(x, z - d)
	return Vector3(-hx, 2.0 * d, -hz).normalized()
