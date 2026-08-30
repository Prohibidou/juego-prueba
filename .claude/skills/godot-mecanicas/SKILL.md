---
name: godot-mecanicas
description: Diagnostico de las mecanicas de este juego contra lo idiomatico de Godot 4 -fisica del piche, estados, camara, input, arquitectura- con la lista de que esta MAL, que esta BIEN y en que orden atacarlo. Leer antes de tocar el movimiento, el salto, las colisiones, la camara, los estados de juego o de partir juego.gd.
---

# Mecanicas: que esta mal y que no

Cuatro investigaciones contra la doc de Godot 4 y el codigo real. Los informes
completos estan en `informes/`. Esto es el resumen accionable.

**Lo primero: tres cosas que se creian mal y estan BIEN.** No las toques.

- **`RigidBody3D` para el piche es correcto.** El juego es balistica real
  -drag, lift por spin, rebote, damping por zona- y `move_and_slide()` no trae
  nada de eso. Migrar a `CharacterBody3D` seria reescribir la fisica a mano.
- **El salto y el timon aereo son idiomaticos.**
  `linear_velocity += UP * IMPULSO` y `apply_central_force()` desde
  `_physics_process` son exactamente el uso bueno de un RigidBody.
- **La camara a mano se justifica.** `_sin_pared()` es un `SpringArm3D` campo
  por campo, pero su resultado pasa por el `lerp` de `CAM_SUAVIZADO`, y el
  suavizado de la correccion por pared es justo lo que SpringArm3D NO sabe
  hacer: snapea al entrar y al salir, no tiene damping, y ni siquiera expone
  `is_colliding()` para hacerlo a mano. El `fov` por codigo tambien esta bien:
  es propiedad de `Camera3D`, no de `CameraAttributes`, y ningun nodo nativo lo
  abre con la velocidad.

## Los bugs reales, por gravedad

**1. La esfera del piche mide 4.26 cm y Jolt documenta [0.1, 10] m para cuerpos
dinamicos.** Esta 2.3x por debajo del piso soportado del motor. Es la causa
comun del tunelado, del colador de barrotes y del CCD raro: a 26 m/s y 60
ticks/s el cuerpo avanza 0.433 m por tick, diez diametros de si mismo.
Arreglo: subir el radio a ~0.10-0.15 m y dejar el modelo chico -que es lo que
ya se hace al reves con `VISTA_PANTALLA`-.

**2. `physics_ticks_per_second` esta en el default 60.** La doc recomienda 120+
justo para tunelado y alta velocidad. Una linea en `project.godot`. Ojo: los
`for i in 120: await physics_frame` de las pruebas pasan a medir la mitad de
tiempo real.

**3. `contact_monitor=true` + `max_contacts_reported=4` en `Piche.tscn` con
CERO `body_entered` conectados** en todo el repo: costo puro. Y el motivo por
el que se abandono esta mal diagnosticado -el comentario de `jaula.gd:141`
miente-: la doc dice que `get_colliding_bodies()` se actualiza ANTES del paso
de fisica, asi que sondearlo da datos viejos a 26 m/s Y a 2. No era la
velocidad. La solucion geometrica de la jaula es solida: no tocarla, corregir
el comentario.

**4. `_conducir()` es un `CharacterBody3D` hecho a mano, mal.** Fuerza
`linear_velocity` y togglea `freeze` cada tick, y en Jolt eso saca y mete el
cuerpo del broadphase. De ahi salen dos cosas que se vienen parcheando: no hay
nocion de suelo -`campo.altura_terreno()` como sustituto de `is_on_floor()` es
EL ORIGEN de tener que pelar capas y de la camioneta trepando follaje- y el
`bounce=0.5` se borra al andar. Arreglo: un `ShapeCast3D` hijo del piche como
unica fuente de "hay suelo", `FREEZE_MODE_KINEMATIC`, y dormir el cuerpo en
vez de congelarlo.

**5. `physics_interpolation` esta apagado.** El proyecto junta punto por punto
el caso canonico de jitter que documenta Godot: `RigidBody3D` + camara suelta
movida en `_process` + `global_position` crudo. Y `_escalar_vista()`
(`juego.gd:250`) escribe el transform del piche visible cada frame de render
desde esa misma posicion de 60 Hz, asi que lo que mas salta es el bicho, no la
camara. Arreglo: activarla y leer con `get_global_transform_interpolated()`;
`physics_interpolation_mode = OFF` en los nodos que se escriben a mano, y
`reset_physics_interpolation()` en los cortes de camara.

**6. No hay seccion `[input]` en `project.godot`.** Todo cableado a
`KEY_G/W/A/S/D` y ejes crudos; el comentario confiesa "no hay accion en el
mapa". `Input.get_vector` e `is_action_just_pressed` hacen el flanco solos y
borran `_pulso_salto`, el parche de `FOCUS_OUT` y el hack `_tecla()` de las
pruebas.

**7. Los 5 estados reales -CARGANDO, ANDANDO, VOLANDO, PORTAZO, META- estan
codificados en 13 booleanos sueltos** (8 en juego.gd, 3 en golpe.gd, 2 en
jaula.gd). Tres bugs ya documentados en sus propios comentarios son bugs de
maquina de estados: `_empujando` pegado, las banderas que mueren tras el
`return` de `_process`, y `_poner_bola` que es un `enter(ANDANDO)` escrito a
mano reseteando nueve variables.

## Lo unico donde los informes chocan

El rayo de `_sin_pared()`. El de camara lo defiende por el suavizado; el de
fisica cita la doc, que desaconseja el fallback a rayo porque uno de grosor
cero pasa por la esquina de un galpon. **No se contradicen**: se queda el
suavizado propio y se cambia el rayo por una forma. No elegir bando sin medirlo.

## Como partir juego.gd (894 lineas -> ~460)

Enum + `match` con un unico `_cambiar()` que tenga salida y entrada. **NO nodo-
estado**: hay un piche, un bucle y 5 estados sin reuso entre entidades, seria
la ceremonia que CLAUDE.md prohibe. `AnimationTree` no aplica todavia
(`_preparar_bola` borra el AnimationPlayer); cuando llegue el modelo animado
se cuelga del estado, nunca al reves.

Orden, de mayor ganancia a menor:

1. Sacar la bateria de pruebas a `pruebas.gd` -217 lineas, el 24% del archivo,
   riesgo cero-.
2. Acciones de InputMap.
3. El enum con exit/enter.
4. `VistaPiche` a `Piche.tscn` (-83).
5. `UI.tscn` con señales: corta seis rutas `$UI/...`.
6. `Portazo` como nodo (-60).
7. `Animal.tscn` + grupos.
8. `const` -> `@export`.
9. Borrar el fallback de golf.
10. `Resource` de nivel SOLO cuando exista un segundo nivel.

**`@export_range`, no Resources.** El proyecto ya invento el patron correcto en
`golpe.gd`. `HOYOS` es un array de UN diccionario de dos campos: un Resource
seria ceremonia pura hasta que haya un segundo nivel. Y
`barra_stam.max_value = STAMINA_MAX  # el .tscn no puede leer la constante` es
exactamente el dolor que `@export` borra.

**Autoloads: ninguno.** Los dos que hay son del addon MCP. `Util` con
`class_name` + estaticos ya es la alternativa que recomienda la doc.

**Grupos: solo para `campo.basura`** -borra el `is_instance_valid` y el
`remove_at` hacia atras-. Para `animales` no alcanza: el `Array[Dictionary]`
con `dir/t/vivo` es estado del animal escrito fuera del animal, y
`Animal.tscn` ya existe.

## Codigo muerto encontrado

`_montar_copa` + `_punto` + `R_COPA`/`PROF_COPA`/`R_PLATAFORMA`/
`ALTO_PLATAFORMA` + la rama de copa en `embocada()` son ~80 lineas de campo.gd
que **nunca corren**: la meta es la camioneta y `_meta.size != Vector3.ZERO`
corta antes. Hay incluso un assert sobre codigo muerto en `juego.gd:760`. Es
el pasado de golf que CLAUDE.md manda ir sacando.

## Dejar quieto

`jaula.gd` + `Jaula.tscn` (es el modelo a imitar: señal arriba, llamadas abajo,
cero deps). Los `@export` de golpe.gd. Los numeros de calibracion fisica.
La maquinaria de rayos de campo.gd. Las decisiones de trimesh, CCD y muros.
Y no hay un solo `get_node("..")` en el repo: esa regla ya esta entendida.

## Animacion e historia

**El piche NO tiene esqueleto ni animaciones.** Parseando el JSON de los `.glb`:
`PGJ_Piche_FINAL.glb` tiene 0 clips y 0 skins, son 3 mallas sueltas (`GARRAS`,
`ojos`, `PicheBody-LOW.001`) sin `Skeleton3D`. El `.fbx` viejo si tenia 7
AnimStack, y de ahi viene el `free()` del AnimationPlayer. No le borraron las
animaciones al piche: nunca las tuvo. (La trampa del AABB con esqueleto del
CLAUDE.md viene de `personajes_low_poly.glb`, que si tiene 7 skins.)

Entonces `_preparar_bola()` (juego.gd:181-183) es **codigo muerto hoy** -sin
clips el importador de glTF no crea AnimationPlayer y `get_node_or_null` da
null- pero es una bomba: el dia que se re-exporte el modelo con clips, esa
linea se los come en silencio. Sacarlo es el unico bug de codigo real de este
frente. Lo idiomatico para no importar la basura del `.fbx` es
`animation/import=false` en el `.import`, no un `free()` en runtime.

**Bloqueador estructural antes de cualquier animacion:** `Vista` es
`top_level=true` y `_escalar_vista()` le reescribe el `global_transform` ENTERO
cada `_process`, asi que pisa cualquier animacion de transform de la raiz.
Hace falta partirlo en `Vista` (colocacion, la manda el codigo) -> `Modelo` (lo
anima el AnimationPlayer). Sin ese nodo intermedio no entra ninguna animacion.

Con 0 clips, el minimo util es `quieto` / `andar` / `caer`. Sin rig igual sirve:
un AnimationPlayer autorado en Godot sobre los 3 Node3D del modelo.

**`Tween.set_ignore_time_scale(true)` existe.** El proyecto usa el truco del
cuarto argumento de `create_timer` en tres lugares porque faltaba este dato.
Y ojo: **AnimationPlayer tambien se escala con `Engine.time_scale`**, asi que
cambiar de herramienta no cura la desincronizacion del portazo. Lo que la cura
es que haya UN reloj: hoy hay tres (el tween de `_portazo`, el tween de la
bisagra en `jaula.gd`, y un `create_timer` real).

**Camara de cine como nodo aparte** con `make_current()`/`clear_current()`
borra el flag `cine` y sus tres apagados sueltos: es literal la trampa de
"banderas que quedan pegadas" del CLAUDE.md. Godot no tiene blending 3D nativo,
pero para un corte seco no hace falta.

**`Area3D` para la meta**, en vez de 4 constantes magicas mas un umbral de
velocidad: la forma se arrastra en el editor, igual que se hizo con el tee.

### Regla nueva: Area3D para lo lento, geometria para lo rapido

El cruce de plano de `jaula.gd` **esta bien y cambiarlo seria una regresion**.
La doc dice que `Area3D` actualiza solapes una vez por paso de fisica: a 26 m/s
son 43 cm por tick y una Area3D fina se atraviesa entera. Area3D sirve para la
meta -donde se llega andando- y no para detectar un impulso a toda velocidad.

**No usar todavia:** `AnimationTree` (no contiene animaciones, usa las de un
AnimationPlayer: con 0 clips vale cero; recien desde 4-5 clips o un blend
continuo por velocidad). **Root motion: nunca** mientras el piche sea
`RigidBody3D` -esta pensado para `CharacterBody3D`, donde el script es la
autoridad del movimiento, y aca manda el solver; ademas no hay hueso raiz al
que apuntar-.
