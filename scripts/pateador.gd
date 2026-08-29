extends Node3D
class_name Pateador
## Una persona plantada en el campo que patea al piche cuando se le acerca, y
## lo manda volando. Es un trampolin con piernas: buscarlas conviene.
##
## La escena no depende de nada de fuera. Se monta sola en _ready y avisa con
## una senal; quien la use decide que hacer con el impulso. Se puede correr
## sola con F6: ahi no hay piche, asi que la K dispara la patada para verla.
##
## El glb trae seis personajes en fila, cada uno con su esqueleto de 26 huesos
## y NINGUNA animacion. Los huesos vienen medio sin nombrar -la pierna
## izquierda se llama "UpperLeg.R.001"-, asi que el retargeting por perfil
## humanoide de Godot no los reconoce y la patada se arma a mano, girando dos.

## El impulso que le pega al piche. Lo escucha quien haya instanciado la escena.
signal pateado(velocidad: Vector3)

const PERSONAJES := "res://modelos/personajes_low_poly.glb"
# Las piernas estan separadas en Z, o sea que Z es el eje lado a lado y el
# balanceo de la patada gira sobre el. Estos dos huesos son la pierna derecha.
const HUESO_MUSLO := 18        # UpperLeg.R_016
const HUESO_RODILLA := 19      # Bone.011_017
const MUSLO := 1.6             # rad que sube el muslo en el golpe
const RODILLA := -1.3          # y lo que estira la rodilla
const ALTO_MODELO := 10.8      # unidades que mide de alto tal cual viene

@export var personaje := 0     # cual de los seis
@export var estatura := 1.75   # metros
@export var alcance := 2.4     # a que distancia patea
@export var fuerza := 20.0     # m/s que le imprime
@export var alza := 0.45       # que fraccion de la fuerza va hacia arriba
@export var espera := 2.5      # segundos entre patadas, para que no ametralle

var _esqueleto: Skeleton3D
var _patada := 0.0             # -1 arma la pierna, 0 reposo, 1 impacto
var _resto := 0.0              # lo que le queda de espera


func _ready() -> void:
	_armar()
	_sensor()


## Saca un personaje del glb y tira los otros cinco. Cada uno cuelga de su
## propio Skeleton3D, asi que se libera el esqueleto entero. Vienen en fila
## sobre Z y con el origen a media altura: se recoloca para que los pies
## queden en el pivote y el cuerpo centrado sobre el.
func _armar() -> void:
	var esc := (load(PERSONAJES) as PackedScene).instantiate()
	add_child(esc)
	var mallas := esc.find_children("*", "MeshInstance3D", true, false)
	var mio: MeshInstance3D = mallas[clampi(personaje, 0, mallas.size() - 1)]
	for m in mallas:
		if m != mio:
			(m as Node3D).get_parent().queue_free()
	_esqueleto = mio.get_parent() as Skeleton3D

	# Se ancla por el HUESO raiz, no por la caja de la malla. La malla tiene
	# esqueleto: su AABB esta en bind pose -los seis personajes en fila, cada
	# uno a su metro- y ademas Godot lo infla, aqui a 160 m de alto. Los huesos
	# en cambio dan la posicion exacta de donde se dibuja el personaje.
	esc.scale = Vector3.ONE * (estatura / ALTO_MODELO)
	var raiz: Vector3 = (_esqueleto.global_transform \
		* _esqueleto.get_bone_global_pose(0)).origin
	esc.global_position += global_position - raiz


## El area que lo hace saltar. Un Area3D y no una comprobacion de distancia:
## asi no necesita que nadie le pase quien es el piche, que es lo que le
## permite a la escena valerse sola.
func _sensor() -> void:
	var forma := SphereShape3D.new()
	forma.radius = alcance
	var col := CollisionShape3D.new()
	col.shape = forma
	col.position = Vector3.UP * estatura * 0.4
	var area := Area3D.new()
	area.add_child(col)
	area.body_entered.connect(_al_entrar)
	add_child(area)


func _al_entrar(cuerpo: Node3D) -> void:
	# solo cuerpos rigidos: el area tambien ve el terreno, que es estatico
	if not (cuerpo is RigidBody3D) or _resto > 0.0:
		return
	patear()


## La patada. Sale en la direccion que mira el personaje, con algo de alza:
## de ahi que convenga plantarlos mirando a donde uno quiere ir.
func patear() -> void:
	_resto = espera
	var dir := global_basis.x
	dir.y = 0.0
	dir = dir.normalized()
	pateado.emit(dir * fuerza + Vector3.UP * fuerza * alza)

	# arma la pierna, golpea y vuelve. El resto del cuerpo se queda quieto:
	# para low poly a la distancia a la que anda la camara, se lee igual.
	var t := create_tween()
	t.tween_property(self, "_patada", -0.45, 0.12).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "_patada", 1.0, 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(self, "_patada", 0.0, 0.40) \
		.set_trans(Tween.TRANS_SINE).set_delay(0.1)


func _process(dt: float) -> void:
	_resto = maxf(0.0, _resto - dt)
	_esqueleto.set_bone_pose_rotation(HUESO_MUSLO,
		Quaternion(Vector3.BACK, _patada * MUSLO))
	_esqueleto.set_bone_pose_rotation(HUESO_RODILLA,
		Quaternion(Vector3.BACK, maxf(_patada, 0.0) * RODILLA))


## ponytail: para poder abrir la escena sola con F6 y mirar la patada sin
## montar el campo entero. En el juego la K no hace nada mas.
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and (e as InputEventKey).keycode == KEY_K:
		patear()
