# Bugs del playtest (lado codigo) — Plan de implementacion

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cerrar los 7 bugs de codigo del playtest (PDF "Error 1"): jaula que deja pasar al piche, caidas entre las maderas del muelle y abajo del barco, falta el texto de la G, basura sembrada dentro del barco, basura plana con flickering, y la "patty" que confunde.

**Architecture:** Tres arreglos de datos/escena (sellar esquinas de la jaula en `Jaula.tscn`, rectangulos de colision del muelle en `Campo.tscn`) mas dos de logica (`campo.gd`: siembra y nivel de rescate; `juego.gd`: red de rescate, texto de ayuda, marca de aterrizaje y asserts nuevos). Las escenas se tocan como `.tscn` autorados, no en `_ready`.

**Tech Stack:** Godot 4.6 (GDScript), fisica Jolt. Verificacion: `_self_check()` headless.

**Spec:** El PDF del playtest (`C:\Users\veram\Downloads\Error 1.pdf`) + los datos medidos por sonda que estan copiados abajo. Este plan ES la spec operativa; los numeros ya estan medidos.

## Global Constraints

- Codigo y comentarios en castellano SIN tildes ni enies; los textos que se VEN en pantalla SI llevan tildes.
- NO hacer `git commit` ni `git push`. Nunca.
- NO correr Godot ni el juego (ni headless): la verificacion la corre el orquestador. Excepcion: solo si tu tarea dice lo contrario.
- Las escenas se autoran editando el `.tscn` a mano (formato texto), no construyendo nodos en `_ready`.
- No tocar archivos `*.import` ni `.godot/`.
- Atajos deliberados se marcan con comentario `ponytail:`.
- Estilo: seguir el tono de comentarios del archivo que tocas (explican el PORQUE, no el que).

## Datos medidos (sonda sobre PGJ_MAPA_MUELLE_v1.glb, coordenadas de mundo del juego)

- Mar: colisiona; su superficie esta en y=164.74 (constante en toda el agua).
- Muelle de maderas: tablones a y=166.46, huecos entre tablones caen al mar.
  Huella util medida: tramo ancho x∈[970.0, 982.3], z∈[710.8, 722.8]; tramo
  angosto x∈[970.0, 976.1], z∈[722.8, 734.0]. En z∈[703,710] ya es tierra (168.49).
- Plataformas del mar: bloques sueltos con tope en y=165.2 a 165.5, agua entre ellos.
- Tierra firme: y=168.49. Cubierta del barco (zona jugable): ~171.5.
- Tee (marcador): (1020, 165, 821.3), sobre el barco. Sobre el tee hay una meseta
  a y=180.30: `altura_terreno` (primera colision) da 180.30 ahi, y es DONDE DE
  VERDAD arranca la bola (`_poner_bola` usa altura_terreno). En cambio
  `altura_suelo` pela capas por los huecos del casco y devuelve 164.74 (el mar).
- Bandera/meta (caja de la camioneta): tope y=171.26.
- Moldes de basura (trash_and_debris.glb): 25 de ~100 tienen lado minimo < 0.05
  (papeles, calcos, latas aplastadas planas, vidrios): son los del flickering.
- La jaula (Jaula.tscn): muros laterales de 2 m centrados que NO llegan a las
  esquinas: en cada esquina queda un hueco diagonal de 0.3 x 0.3 m (de y=-0.5 a
  y=1.65). El piche mide 4 cm.

---

### Task 1: Sellar las esquinas de la jaula

**Files:**
- Modify: `escenas/Jaula.tscn`

**Interfaces:**
- Consumes: nada.
- Produces: la misma escena; `scripts/jaula.gd` no cambia (solo lee la caja de `Tapa`, que no se toca).

El bug: los muros `Izq` (x=-1.15, caja 0.3 x 2.1498 x 2), `Fondo` (z=-1.15, caja 2 x 2.1498 x 0.3) y `Frente` (z=+1.15, caja 2 x 2.1498 x 0.3) cubren solo el tramo central: en las 4 esquinas (p. ej. x∈[-1.3,-1.0] con z∈[-1.3,-1.0]) no hay caja de nadie y queda un tunel diagonal de 30 x 30 cm por el que un piche de 4 cm sale caminando. Las jambas (`JambaA` z∈[-1.0,-0.4482], `JambaB` z∈[0.4482,1.0]) dejan los mismos huecos en las esquinas del lado de la puerta.

- [ ] **Step 1: Alargar las tres cajas de muro para que crucen las esquinas**

En `escenas/Jaula.tscn`, cambiar SOLO los `size` de estos sub_resources:

```
[sub_resource type="BoxShape3D" id="B_izq"]
size = Vector3(0.3, 2.1498, 2.6)

[sub_resource type="BoxShape3D" id="B_fondo"]
size = Vector3(2.6, 2.1498, 0.3)

[sub_resource type="BoxShape3D" id="B_frente"]
size = Vector3(2.6, 2.1498, 0.3)
```

(antes eran 2.0 en ese eje: con 2.6 llegan de -1.3 a +1.3 y se solapan con el muro perpendicular, que esta centrado en ±1.15 con espesor 0.3.)

- [ ] **Step 2: Alargar las jambas hasta la esquina**

Las jambas cubren z∈[-1.0,-0.4482] y z∈[0.4482,1.0]; tienen que llegar a ±1.3. Cambiar tamano Y posicion (el borde interior, el que define el hueco de la puerta en ±0.4482, NO se mueve):

```
[sub_resource type="BoxShape3D" id="B_jambaA"]
size = Vector3(0.3, 2.1498, 0.8518)

[sub_resource type="BoxShape3D" id="B_jambaB"]
size = Vector3(0.3, 2.1498, 0.8518)
```

y en los nodos:

```
[node name="JambaA" type="StaticBody3D" parent="Muros"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.15, 0.5749, -0.8741)

[node name="JambaB" type="StaticBody3D" parent="Muros"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.15, 0.5749, 0.8741)
```

(centro -0.8741 con mitad 0.4259 → z∈[-1.3, -0.4482]; el espejo para B.)

- [ ] **Step 3: Dejar una nota en el propio tscn... NO.** Los `.tscn` no llevan comentarios; el porque queda en el docstring de `scripts/jaula.gd`, que ya explica que los muros son macizos. No agregar nada mas.

- [ ] **Step 4: Revision propia**

Releer el diff: no debe cambiar nada mas que esos 4 `size` y esas 2 posiciones. `Tapa`, `Dintel`, `Techo`, `Bisagra` y `Cuerpo` quedan intactos (jaula.gd deriva `_frente`, `_ancho` y `_dintel` de la Tapa).

### Task 2: Rectangulos de colision para el muelle de maderas

**Files:**
- Modify: `escenas/Campo.tscn`

**Interfaces:**
- Consumes: nada.
- Produces: dos `StaticBody3D` nuevos bajo un `Node3D` llamado `ColisionMuelle`, hijos del nodo raiz `Campo`. `campo.gd` no cambia: los rayos de altura los veran como suelo (top plano a nivel de tablon) y `cuerpos()` de la jaula no los toca.

El bug: el muelle esta modelado tablon por tablon y la colision trimesh copia los huecos; el piche (4 cm) se cae al mar entre las maderas. El pedido del playtest es literal: "poner un rectangulo que funcione como colision". El tope va a 166.46 (el mismo nivel del tablon, medido): asi no hay escalon que frene al piche ni piso invisible que lo haga flotar.

- [ ] **Step 1: Agregar los sub_resources de las dos cajas**

En `escenas/Campo.tscn`, despues del bloque de `ext_resource` (y antes del nodo raiz), agregar:

```
[sub_resource type="BoxShape3D" id="B_muelle_ancho"]
size = Vector3(12.3, 1.0, 12.0)

[sub_resource type="BoxShape3D" id="B_muelle_angosto"]
size = Vector3(6.1, 1.0, 11.2)
```

Y en la cabecera `[gd_scene ...]` sumar 2 al `load_steps` si el archivo lo declara (hoy la escena no declara `load_steps`: en ese caso no agregar nada).

- [ ] **Step 2: Agregar los nodos al final del archivo**

```
[node name="ColisionMuelle" type="Node3D" parent="."]

[node name="TramoAncho" type="StaticBody3D" parent="ColisionMuelle"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 976.15, 165.96, 716.8)

[node name="Forma" type="CollisionShape3D" parent="ColisionMuelle/TramoAncho"]
shape = SubResource("B_muelle_ancho")

[node name="TramoAngosto" type="StaticBody3D" parent="ColisionMuelle"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 973.05, 165.96, 728.4)

[node name="Forma" type="CollisionShape3D" parent="ColisionMuelle/TramoAngosto"]
shape = SubResource("B_muelle_angosto")
```

(TramoAncho: x∈[970.0, 982.3], z∈[710.8, 722.8], tope y=166.46. TramoAngosto: x∈[970.0, 976.1], z∈[722.8, 734.0], tope y=166.46. Los dos con 1 m de espesor hacia abajo, para que un rebote no los tunelee.)

- [ ] **Step 3: Revision propia**

Verificar en el diff: los marcadores `Tee` y `Bandera` y el nodo `Curso` intactos; el `parent` de los cuerpos es `ColisionMuelle`; los ids de sub_resource no chocan con ninguno existente (hoy la escena no tiene sub_resources).

### Task 3: Siembra que no cae al barco ni al mar, sin moldes planos, y nivel de perdida

**Files:**
- Modify: `scripts/campo.gd`

**Interfaces:**
- Consumes: nada nuevo.
- Produces (lo usa la Task 4):
  - `const NIVEL_PERDIDO := 165.0`
  - `func perdida(pos: Vector3) -> bool` — true si esa posicion ya es "al agua" (mar en 164.74; lo caminable mas bajo, las plataformas, esta en 165.2).
  - `const MOLDE_MIN := 0.05` y el filtro de moldes planos en `preparar()`.

Los bugs (tres, todos en este archivo):

1. **Basura adentro del barco / fauna en la bodega.** `_poblar_basura()` y `_poblar_fauna()` VALIDAN el punto con `_altura_sembrable` (primera colision: la cubierta) pero luego COLOCAN con `altura_suelo()`, que pela capas: en este mapa el pelado cruza la cubierta por los huecos del casco y termina en la bodega o el mar. (El pelado era para las copas de los arboles de la fotogrametria vieja; este mapa no tiene arboles sobre el pasillo.)
2. **La red de HUNDIDO no filtra nada** porque `_tee.y` sale 164.74: `ir_a()` usa `altura_suelo` para el tee y el pelado tambien ahi cruza hasta el mar. La bola de verdad arranca en la meseta de y=180.30 (que es lo que da `altura_terreno`, y lo que ya usa `_poner_bola`).
3. **Basura plana con flickering.** 25 de los ~100 moldes de `trash_and_debris.glb` son laminas de espesor ~0 (papeles, calcos, latas pisadas): sembradas a ras de piso hacen z-fighting.

- [ ] **Step 1: `NIVEL_PERDIDO` y `perdida()`**

Junto a las otras constantes del mapa (cerca de `HUNDIDO`):

```gdscript
# Por debajo de esto ya es el mar (su superficie esta en 164.74) o la bodega
# baja del barco: no hay vuelta caminando. Lo caminable mas bajo son las
# plataformas del mar, con el tope en 165.2.
const NIVEL_PERDIDO := 165.0
```

Y como funcion publica (cerca de `embocada`):

```gdscript
## Ya no hay vuelta: el agua y la bodega quedan por debajo de todo lo caminable.
## Quien la use decide que hacer (reponer, penalizar); el campo solo sabe donde
## termina lo jugable.
func perdida(pos: Vector3) -> bool:
	return pos.y < NIVEL_PERDIDO
```

- [ ] **Step 2: el tee a la altura donde arranca la bola de verdad**

En `ir_a()`, cambiar la linea del tee:

```gdscript
	_tee = Vector3(t.x, altura_terreno(t.x, t.z), t.z)
```

con este comentario encima (reemplaza el parrafo actual solo si habla de la altura; el resto del comentario del tee se conserva):

```gdscript
	# altura_terreno (primera colision), NO altura_suelo: la bola arranca sobre
	# la meseta del barco (y=180.3), que es lo primero que pega el rayo y donde
	# la pone _poner_bola. El pelado de altura_suelo cruza la cubierta por los
	# huecos del casco y devolvia el MAR (164.74): el tee quedaba 15 m abajo del
	# arranque real y la red de HUNDIDO de la siembra no filtraba nada.
```

- [ ] **Step 3: sembrar EN el punto validado, no en el pelado**

En `_poblar_basura()`, la pieza se coloca hoy con `altura_suelo(p.x, p.y)`; usar la `y` que ya devolvio `_altura_sembrable`:

```gdscript
		pieza.position = Vector3(p.x, y + caja.size.y * 0.5, p.y)
```

En `_poblar_fauna()`, lo mismo:

```gdscript
		nodo.position = Vector3(p.x, y, p.y)
```

y borrar (o reescribir) el comentario que justificaba `altura_suelo` por las copas de los arboles: en este mapa el pelado no atraviesa follaje, atraviesa la cubierta.

- [ ] **Step 4: `_altura_sembrable` rechaza mar, hondo y bajo techo**

Primero, un rayo crudo que devuelva el resultado entero (reemplaza el cuerpo de `_rayo` para que lo use):

```gdscript
## Rayo hacia abajo, en crudo, resultado entero (posicion + rid del cuerpo).
## Diccionario vacio si no pega en nada.
func _rayo_crudo(x: float, z: float, desde: float) -> Dictionary:
	var esp := get_world_3d().direct_space_state
	if esp == null:
		return {}
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, desde, z), Vector3(x, SUELO, z))
	q.exclude = excluir
	# (conservar aca el comentario existente de hit_back_faces de _rayo)
	q.hit_back_faces = false
	return esp.intersect_ray(q)


func _rayo(x: float, z: float, desde: float) -> float:
	var golpe := _rayo_crudo(x, z, desde)
	return golpe["position"].y if golpe else INF
```

Despues, en `preparar()`, dentro del bucle de mallas y despues de `create_trimesh_collision()`, juntar los cuerpos del mar:

```gdscript
		if m.name == "Mar":
			for cuerpo in m.get_children():
				if cuerpo is StaticBody3D:
					_rids_mar.append((cuerpo as StaticBody3D).get_rid())
```

con la variable declarada junto a `excluir`:

```gdscript
var _rids_mar: Array[RID] = []   # los cuerpos del agua: ahi no se siembra
```

Y `_altura_sembrable` queda:

```gdscript
## Altura para SEMBRAR: ademas de exigir que el rayo pegue en algo, tira los
## sitios donde una pieza no se puede recoger andando: el mar (que colisiona y
## el rayo lo ve como piso), lo que este por debajo de todo lo caminable, lo
## que se hundio mucho respecto del pasillo tee-bandera, y lo que quedo BAJO
## TECHO -un rayo que se colo por un hueco del casco pega en la bodega, y esa
## botella se ve por el agujero pero no hay como agarrarla-. Devuelve NAN si
## el sitio no vale.
func _altura_sembrable(x: float, z: float) -> float:
	var g := _rayo_crudo(x, z, _techo)
	if g.is_empty():
		return NAN
	var y: float = g["position"].y
	if y < minf(_tee.y, _bandera.y) - HUNDIDO or y < NIVEL_PERDIDO + 0.1:
		return NAN
	if _rids_mar.has(g["rid"]):
		return NAN
	# cielo abierto: si a menos de 2 m por encima hay geometria, esto es la
	# bodega (o un entrepiso): se ve, no se alcanza. hit_back_faces en true
	# porque la cara de la cubierta mira hacia arriba y desde abajo es trasera.
	var esp := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(x, y + 0.4, z), Vector3(x, y + 2.5, z))
	q.exclude = excluir
	q.hit_back_faces = true
	if esp.intersect_ray(q):
		return NAN
	return y
```

- [ ] **Step 5: filtrar los moldes planos**

Constante junto a `BASURAS`:

```gdscript
# Un cuarto de los moldes del escaparate son laminas de espesor casi cero
# (papeles, calcos, latas pisadas): a ras del piso hacen z-fighting con el
# suelo (el flickering del playtest). Solo se siembran piezas con volumen.
const MOLDE_MIN := 0.05        # metros del lado mas fino que se acepta
```

Y en `preparar()`, el bucle que llena `_moldes` pasa a:

```gdscript
	for m in escaparate.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var s: Vector3 = (Transform3D(mi.global_transform.basis, Vector3.ZERO)
			* mi.mesh.get_aabb()).size.abs()
		if minf(s.x, minf(s.y, s.z)) < MOLDE_MIN:
			continue
		_moldes.append(mi)
```

- [ ] **Step 6: Revision propia**

Releer el diff completo contra estos puntos: (a) nadie mas llamaba `_altura_sembrable` que la siembra; (b) `altura_suelo` sigue existiendo y lo siguen usando `ir_a` NO (ya no), `_montar_copa`/`_punto` (solo si no hay meta) y nada mas critico; (c) `_rayo` conserva el contrato (INF si no pega); (d) sin tildes en comentarios.

### Task 4: Red de rescate, texto de la G, marca discreta y asserts de todo lo anterior

**Files:**
- Modify: `scripts/juego.gd`
- Modify: `escenas/Juego.tscn`

**Interfaces:**
- Consumes: `campo.perdida(pos)` y `campo.NIVEL_PERDIDO` (Task 3); los rectangulos del muelle (Task 2) y la jaula sellada (Task 1) para los asserts.
- Produces: nada que consuma otra task.

Esta task puede correr Godot para verificar (es la unica; las demas no):
`"/c/Users/veram/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://escenas/Juego.tscn --quit-after 4500`
Al terminar TODAS las corridas: `git checkout -- "*.import"` (el binario 4.7.2 les mete metadatos).

- [ ] **Step 1: Label de ayuda en `Juego.tscn`**

Bajo el nodo `UI` (CanvasLayer), despues de `BarraStam`, agregar:

```
[node name="Ayuda" type="Label" parent="UI" unique_id=1077121290]
anchors_preset = 7
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_left = -2.0
offset_top = -116.0
offset_right = 2.0
offset_bottom = -96.0
theme_override_font_sizes/font_size = 24
horizontal_alignment = 1
```

(centrado abajo, justo encima de la barra de stamina.)

- [ ] **Step 2: el texto de la G mientras esta enjaulado**

En `juego.gd`: `@onready var ayuda: Label = $UI/Ayuda` junto a los otros onready. En `_process`, despues del bloque de `golpe.enjaulado = _en_la_jaula()`:

```gdscript
	# el playtest se quedo encerrado sin saber que tecla era: el impulso es G y
	# no se dice en ningun lado. Solo mientras la puerta siga puesta.
	ayuda.text = "Mantené apretado G y soltá: el impulso tira la puerta" \
		if _enjaulado() and quieto and not embocada else ""
```

(Texto de pantalla: CON tildes. El resto del codigo, sin.)

- [ ] **Step 3: red de rescate al agua**

Estado nuevo junto a `_desde`:

```gdscript
var _firme := Vector3.ZERO    # ultimo sitio donde estuvo parada en suelo jugable
```

En `_poner_bola()`, al final: `_firme = bola.global_position`.

En `_physics_process`, en la rama `if quieto:` (andando), antes de `_conducir(dt)`:

```gdscript
		# la red de rescate: entre las maderas del muelle o por un hueco del
		# casco se cae al MAR, que colisiona -se queda uno caminando sobre el
		# agua sin vuelta-. Andando no hay pena: caerse por una rendija es
		# culpa del mapa, no del jugador.
		if campo.perdida(bola.global_position):
			_aviso("¡Al agua!", 1.2)
			_poner_bola(_firme)
			return
		# _firme solo se toma APOYADO en suelo jugable: durante la caida por un
		# hueco la bola sigue "quieta" (andando) y sin este resguardo _firme
		# quedaba en el aire sobre el propio hueco -reponer ahi la devolvia al
		# mar y era un rebote infinito de rescates
		if not _saltando and (bola.freeze or absf(bola.linear_velocity.y) < 0.1):
			var alt := campo.altura_terreno(bola.global_position.x, bola.global_position.z)
			if bola.global_position.y - Util.RADIO < alt + 0.05 and alt > Campo.NIVEL_PERDIDO:
				_firme = bola.global_position
```

Y en la rama de vuelo (despues del check de `pos.y < -60.0`, que se conserva de paracaidas):

```gdscript
	# un golpe que termina en el agua es un drop clasico: pena y a repetir
	# desde donde se pego. Sin esto la bola aterrizaba EN el mar (colisiona)
	# y se seguia jugando desde el agua.
	if campo.perdida(pos) and not _empujando:
		golpes += PENA_DROP
		_aviso("Al agua  +%d" % PENA_DROP, 1.4)
		_poner_bola(_desde)
		return
```

OJO: `_poner_bola` coloca con `altura_terreno(x,z)`: reponer en `_firme`/`_desde` recoloca a la altura del suelo de ese punto, que es lo que se quiere. Y `_firme` no se actualiza saltando ni en el agua (el `return` corta antes).

- [ ] **Step 4: la marca de aterrizaje no parece comida**

El playtest confundio el disco marron de `_marca()` con un item ("la patty"). En `_marca()`:

```gdscript
	var r := clampf(v * 0.005, 0.05, 0.2)
	var m := Util.disco(r, 0.02, Color(0.22, 0.19, 0.13))
```

(antes tope 0.35 y color 0.30/0.24/0.14: mas chica y mas apagada sigue contando el aterrizaje sin leerse como una hamburguesa. El comentario de la funcion no existe; no hace falta agregar uno.)

- [ ] **Step 5: asserts nuevos**

En `_probar_jaula()`, despues del punto 2 (barrotes), agregar el punto de las esquinas y el del impulso a full contra un muro ciego:

```gdscript
	# 2b. ni por las esquinas: los muros de 2 m dejaban un tunel diagonal de
	# 30x30 cm en cada una (el piche mide 4 cm y salia caminando)
	for esquina in [Vector3(1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(-1, 0, -1)]:
		_poner_bola(campo.pos_tee())
		var e := await _empujar((_jaula.global_basis * esquina).normalized())
		print("jaula: contra la esquina %s queda en (%.2f, %.2f)" % [str(esquina), e.x, e.z])
		assert(absf(e.x) < 1.05 and absf(e.z) < 1.05, "la bola se escapa por una esquina")
```

y antes del punto 4 (que ya tira la puerta), el impulso a full contra el fondo:

```gdscript
	# 3b. un impulso a full contra un muro ciego tampoco lo tunelea: el
	# playtest reportaba al piche "traspasando los barrotes", y a 26 m/s eso
	# es cosa del CCD, no de andar
	_poner_bola(campo.pos_tee())
	golpe.mira = atan2(a_barrotes.x, a_barrotes.z)
	golpe.activo = true
	golpe.cargar()
	golpe.fuerza = 1.0
	golpe.soltar()
	golpe.mira = atan2(a_puerta.x, a_puerta.z)   # que la dispersion no la mande a la puerta: mira al fondo igual
	for i in 120:
		await get_tree().physics_frame
	var tunel := _jaula.global_transform.affine_inverse() * bola.global_position
	print("jaula: impulso a full contra el fondo, queda en z=%.2f" % tunel.z)
	assert(absf(tunel.z) < 1.3, "el impulso a full tunelea el muro")
	assert(_jaula.puerta_entera(), "el impulso contra el fondo tiro la puerta")
	stamina = STAMINA_MAX
```

OJO con ese bloque: `golpe.mira` se fija ANTES de `soltar()` (la dispersion sortea sobre la mira del momento) y la segunda asignacion es para que la prueba no dependa del estado que quede. Si al integrarlo la dispersion (hasta ±3 grados) igual puede pegar en la jamba, vale: la condicion es no SALIR (|z| < 1.3), no donde rebota.

En `_self_check()`, antes del bloque headless, agregar:

```gdscript
	# el tee y el arranque real de la bola son la misma altura: si difieren,
	# altura_suelo volvio a pelar la cubierta hasta el mar (o el tee quedo
	# colgado) y la red de HUNDIDO de la siembra no filtra nada
	assert(absf(campo.pos_tee().y - (bola.global_position.y - Util.RADIO)) < 0.5,
		"el tee no esta a la altura donde arranca la bola")
	# la basura se siembra donde se puede ir a buscar: sobre el nivel del agua
	# y a cielo abierto (no en la bodega, vista por un hueco pero inalcanzable)
	for pieza in campo.basura:
		assert(pieza.global_position.y > Campo.NIVEL_PERDIDO,
			"hay basura sembrada en el mar o la bodega")
	# y ningun molde plano: eran el flickering del playtest
	for molde in campo._moldes:
		var s: Vector3 = (Transform3D(molde.global_transform.basis, Vector3.ZERO)
			* molde.mesh.get_aabb()).size.abs()
		assert(minf(s.x, minf(s.y, s.z)) >= Campo.MOLDE_MIN,
			"quedo un molde plano en el mazo de basura")
	# el rectangulo del muelle: por el pasillo central ya no se cae al mar
	for punto in [Vector2(976, 712), Vector2(976, 716), Vector2(976, 720),
			Vector2(972, 724), Vector2(972, 728), Vector2(972, 732)]:
		var h := campo.altura_terreno(punto.x, punto.y, 170.0)
		assert(h > 166.3, "el muelle sigue teniendo huecos en (%s): h=%.2f" % [str(punto), h])
	# el texto de la G: enjaulado se ve, y es texto de pantalla (con tilde).
	# El texto lo pone _process: hay que dejar pasar un frame para que corra
	# (listo ya esta en true), si no el assert lee el Label recien nacido.
	await get_tree().process_frame
	assert(ayuda.text != "", "no hay texto de ayuda dentro de la jaula")
```

Y en el bloque headless (dentro del `if DisplayServer.get_name() == "headless":`), al final, la red de rescate:

```gdscript
	# la red de rescate: parada en el agua, vuelve sola al ultimo suelo firme
	var firme_antes := _firme
	bola.global_position = Vector3(900.0, Campo.NIVEL_PERDIDO - 0.1, 750.0)
	bola.freeze = false
	quieto = true
	for i in 10:
		await get_tree().physics_frame
	print("rescate: desde el agua vuelve a %s" % str(bola.global_position.round()))
	assert(bola.global_position.distance_to(firme_antes) < 2.0,
		"la bola no vuelve del agua")
```

- [ ] **Step 6: correr la verificacion entera**

```
"/c/Users/veram/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://escenas/Juego.tscn --quit-after 4500
```

Esperado: `self-check OK`, los prints de jaula (puerta, barrotes, esquinas, tunel), muelle, rescate y el primer impulso, sin ningun assert reventado. El numero del primer impulso oscila entre 1.6 y 18.7 con el mismo codigo (dispersion): si un assert de distancia falla, correr 2-3 veces antes de tocar nada. Si la corrida queda muda mas de 3 minutos: `taskkill //F //PID <pid> //T` y reintentar (ver seccion de trampas de CLAUDE.md).

- [ ] **Step 7: limpiar**

`git checkout -- "*.import"` y revisar `git status` (solo deben quedar tocados: `escenas/Jaula.tscn`, `escenas/Campo.tscn`, `escenas/Juego.tscn`, `scripts/campo.gd`, `scripts/juego.gd`, y los docs del plan).

---

## Fuera de alcance (decidido, no olvidado)

- **Reja perimetral mal exportada, yuyos, textura del galpon y de la puerta de la camioneta:** son del glb de la maqueta; los arregla quien exporta el modelo.
- **Skip del muelle saltando con barra a full (bug 11):** no es bug. El impulso a full ES la mecanica central (26 m/s); saltear plataformas con un buen tiro es la parte "skill shot" del SBG. Si el diseno despues quiere obligar el camino, es una decision de diseno, no un arreglo.
- **Basura sembrada SOBRE el mar** quedaba tecnicamente posible antes; la cierra el mismo filtro de `_rids_mar` de la Task 3.
