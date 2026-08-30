extends AnimatableBody3D
## Un tablon del muelle que FLOTA: sube, baja y cabecea siguiendo la misma ola
## que dibuja el mar, y ademas va y viene, para que el piche tenga que calcular
## el salto en vez de pisar suelo quieto.
##
## La geometria (malla y caja de colision, distintas en cada chapa) se autora
## en la instancia, en el .tscn del mapa; este script SOLO mueve.
##
## No busca el mar por su cuenta: se lo pasa mapa.gd con flotar_en(). Sin mar
## puesto sigue funcionando, solo que sin flotar -queda el vaiven de siempre-.
##
## AnimatableBody3D con sync_to_physics (su default) empuja al piche si se para
## encima con solo reescribirle la transformada.

@export var eje := Vector3.RIGHT        # direccion del vaiven, ejes LOCALES
@export_range(0.0, 6.0, 0.1) var amplitud := 1.5    # metros a cada lado del origen
@export_range(1.0, 20.0, 0.1) var periodo := 5.0    # segundos del ciclo completo
@export_range(0.0, 1.0, 0.05) var fase := 0.0       # desfasa contra los otros tablones
## Cuanto se deja llevar por la ola. 1 = flota pegada a la superficie; 0 = ni
## se entera. Por debajo de 1 se lee como una tabla pesada que no copia cada rizo.
@export_range(0.0, 1.0, 0.05) var flotabilidad := 1.0
## Cuanto se inclina con la pendiente de la ola. Muy alto y cabecea tanto que
## el piche se resbala; 0.55 se ve vivo y sigue siendo pisable.
@export_range(0.0, 1.0, 0.05) var cabeceo := 0.55

var _origen := Vector3.ZERO
var _escala := Vector3.ONE     # la del .tscn: reescribir `basis` se la lleva por delante
var _reloj := 0.0
var _mar: Mar = null
var _empuje := Vector3.ZERO    # cuanto se movio en MUNDO este tick, ver empuje()


func _ready() -> void:
	_origen = position
	_escala = scale
	add_to_group("plataformas")


## Llamada hacia abajo: mapa.gd le presenta el mar del que tiene que flotar.
func flotar_en(mar: Mar) -> void:
	_mar = mar


func _physics_process(delta: float) -> void:
	# el desplazamiento se mide en LOCAL (position, no global_position) y se
	# lleva a mundo multiplicando por la base del padre -que no se mueve-, en
	# vez de restar dos lecturas de global_position antes y despues de mover.
	# Con physics_interpolation prendido (ver project.godot) global_position
	# leida unas lineas despues de reescribir `position`, en el mismo tick, no
	# reflejaba el cambio todavia -quedaba pisada por el valor de ANTES de
	# mover, y con las dos lecturas iguales `empuje()` daba (0,0,0) siempre:
	# el piche no se despegaba de la jaula pero tampoco viajaba con la chapa
	# aunque el barrido (medido con `position` entre frames separados, no dos
	# lecturas seguidas) probara que la plataforma si se mueve.
	var previo := position
	_reloj += delta
	var ciclo := _reloj / periodo + fase
	var p := _origen + eje.normalized() * amplitud * sin(ciclo * TAU)

	if _mar != null:
		# La ola se pide en coordenadas de MUNDO -es donde vive- pero lo que se
		# escribe es la position LOCAL: el nodo del mapa esta desplazado, y
		# mezclar los dos espacios dejaba las chapas a veinte metros del agua.
		var padre := get_parent() as Node3D
		var mundo: Vector3 = padre.global_transform * p if padre != null else p
		p += Vector3.UP * _mar.altura(mundo.x, mundo.z) * flotabilidad
		# cabeceo: se alinea el eje Y del tablon con la normal de la ola,
		# interpolando desde la vertical para poder dosificarlo.
		var arriba := Vector3.UP.lerp(_mar.normal(mundo.x, mundo.z), cabeceo).normalized()
		var ang := Vector3.UP.angle_to(arriba)
		# `basis` se reescribe entera y NO lleva la escala del .tscn: hay que
		# volver a metersela o la chapa encoge a tamano 1 en el primer tick.
		basis = (Basis(Vector3.UP.cross(arriba).normalized(), ang) if ang > 0.0001
			else Basis()).scaled(_escala)

	position = p
	var padre_actual := get_parent() as Node3D
	var base_mundo := padre_actual.global_transform.basis if padre_actual != null else Basis()
	_empuje = base_mundo * (p - previo)


## Cuanto se movio ESTE tick, en mundo. Quien se para encima se lo suma a su
## propia posicion: no se confia en que la friccion de sync_to_physics arrastre
## un piche de 4 cm, y ademas _conducir() lo congela al soltar el mando.
func empuje() -> Vector3:
	return _empuje
