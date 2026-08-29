extends RefCounted
class_name Util
## Piezas compartidas: mallas provisionales y el modelo de vuelo de la bola.
##
## La aerodinamica vive aqui porque la usan dos sitios: juego.gd la aplica como
## fuerza sobre el cuerpo rigido, y golpe.gd la integra para dibujar el arco.
## Si estuviera duplicada, el arco acabaria mintiendo.

# medidas reales de una bola de golf
const RADIO := 0.0213      # 42,67 mm de diametro
const MASA := 0.0459       # 45,9 g
const AREA := PI * RADIO * RADIO
const CD := 0.25           # arrastre
const CL := 0.20           # sustentacion por efecto hacia atras
const K_DRAG := 0.5 * 1.225 * CD * AREA
const K_LIFT := 0.5 * 1.225 * CL * AREA
const VIDA_GIRO := 5.0     # segundos en que se apaga el efecto
const GRAVEDAD := 9.8


## Fuerza del aire sobre la bola. Sin la sustentacion el alcance maximo caeria
## en 45 grados y el juego premiaria el globo en vez del drive rasante.
static func fuerza_aire(vel: Vector3, viento: Vector3, giro: float) -> Vector3:
	var rel := vel - viento
	var s := rel.length()
	if s < 0.5:
		return Vector3.ZERO
	var dir := rel / s
	var f := -dir * K_DRAG * s * s
	var lado := dir.cross(Vector3.UP)
	if lado.length_squared() > 0.001:
		f += lado.normalized().cross(dir).normalized() * K_LIFT * s * s * giro
	return f


## Integra el vuelo hasta tocar el suelo. `suelo` recibe (x, z) y devuelve la
## altura. Es el mismo modelo que la fisica, no una aproximacion aparte.
static func trayectoria(pos: Vector3, vel: Vector3, giro: float, viento: Vector3,
		suelo: Callable, pasos := 220, dt := 0.05) -> PackedVector3Array:
	var puntos := PackedVector3Array()
	var p := pos
	var v := vel
	var g := giro
	for i in pasos:
		puntos.push_back(p)
		g = maxf(0.0, g - dt / VIDA_GIRO)
		var a: Vector3 = fuerza_aire(v, viento, g) / MASA + Vector3.DOWN * GRAVEDAD
		v += a * dt
		p += v * dt
		if p.y <= suelo.call(p.x, p.z) + RADIO:
			p.y = suelo.call(p.x, p.z) + RADIO
			puntos.push_back(p)
			break
	return puntos


static func mat(c: Color, vertex_color := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.vertex_color_use_as_albedo = vertex_color
	return m


static func fisica() -> PhysicsMaterial:
	var f := PhysicsMaterial.new()
	f.friction = 1.0
	f.bounce = 0.35
	return f


static func disco(r: float, alto: float, c: Color) -> MeshInstance3D:
	return cilindro(r, r, alto, c, 16)


static func cilindro(rt: float, rb: float, h: float, c: Color, segmentos := 7) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = rt
	cil.bottom_radius = rb
	cil.height = h
	cil.radial_segments = segmentos
	m.mesh = cil
	m.material_override = mat(c)
	return m


static func particulas(c: Color, vida: float, cantidad: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var m := SphereMesh.new()
	m.radius = 0.06
	m.height = 0.12
	m.radial_segments = 4
	m.rings = 2
	p.mesh = m
	p.material_override = mat(c)
	p.amount = cantidad
	p.lifetime = vida
	p.one_shot = true
	p.explosiveness = 0.9
	p.spread = 60.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	return p


static func reventar(padre: Node, pos: Vector3, c: Color, cantidad := 20) -> void:
	var p := particulas(c, 0.8, cantidad)
	padre.add_child(p)
	p.global_position = pos
	p.emitting = true
	padre.get_tree().create_timer(2.0).timeout.connect(p.queue_free)
