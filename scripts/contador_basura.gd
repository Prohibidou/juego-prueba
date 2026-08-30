extends Control
class_name ContadorBasura
## Contador de basura recogida en el mapa actual: icono + "recogidas/total",
## en una esquina del HUD. No sabe nada del piche ni del mapa: solo cuenta lo
## que le avisan por `reiniciar()` y `sumar()`, y hace un pulso corto cuando
## sube. Mismo patron que Pausa.tscn/pausa.gd: escena autocontenida, senales y
## llamadas hacia abajo, nada de `get_node("..")` al padre.
##
## Se muestra "recogidas/total" (no solo "recogidas") porque la basura no es
## obligatoria -solo repone stamina-, y sin el total el jugador no puede saber
## si le conviene desviarse a buscar la que falta o si ya no queda ninguna.

@export_range(1.0, 1.6, 0.01) var PULSO := 1.3       # cuanto crece al recoger
@export_range(0.05, 0.5, 0.01) var PULSO_SEG := 0.22

@onready var _cifra: Label = $Cifra

var _total := 0
var _recogidas := 0


func _ready() -> void:
	# el pivote ya viene centrado desde el .tscn (el tamano es fijo, en
	# offsets); esto es solo la red de seguridad si algun dia se redimensiona
	# desde el editor y alguien se olvida de correr pivot_offset a mano
	# (mismo patron que los botones de pausa.gd, ahi si dentro de un
	# contenedor que reparte el tamano recien en tiempo de ejecucion)
	resized.connect(func(): pivot_offset = size * 0.5)
	_actualizar()


## Se llama al cargar o reiniciar un mapa: `total` es cuanta basura quedo
## sembrada de verdad (mapa.basura.size(), no el @export_range que solo pide
## cuanta intentar sembrar: parte se puede perder si el sitio no era firme).
func reiniciar(total: int) -> void:
	_total = total
	_recogidas = 0
	_actualizar()


## Suma lo recogido en este frame (lo que devuelve mapa.recoger) y pulsa si
## de verdad subio algo. Con 0 no pasa nada: no hay pulso vacio en cada frame.
func sumar(cogidas: int) -> void:
	if cogidas <= 0:
		return
	_recogidas += cogidas
	_actualizar()
	_pulsar()


## Cuanto lleva recogido. Publico para que _self_check() pueda comprobar que
## de verdad subio, sin andar leyendo el Label a mano desde afuera.
func recogidas() -> int:
	return _recogidas


## El texto tal cual esta en pantalla, para que _self_check() compruebe que
## SE VE el numero nuevo y no solo que la variable interna cambio.
func texto() -> String:
	return _cifra.text


func _actualizar() -> void:
	_cifra.text = "%d/%d" % [_recogidas, _total]


func _pulsar() -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE * PULSO, PULSO_SEG * 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, PULSO_SEG * 0.65) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
