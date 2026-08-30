# Diagnostico: el piche como RigidBody3D en Godot 4.6

Investigacion sobre buenas practicas de controladores 3D en Godot 4, aterrizada
sobre el codigo real del proyecto. Solo lectura, no se toco nada.

Archivos leidos:
- `C:\Users\ivanu\OneDrive\Documentos\golfito\escenas\Piche.tscn`
- `C:\Users\ivanu\OneDrive\Documentos\golfito\scripts\juego.gd`
- `C:\Users\ivanu\OneDrive\Documentos\golfito\scripts\golpe.gd`
- `C:\Users\ivanu\OneDrive\Documentos\golfito\scripts\jaula.gd` (parcial)
- `C:\Users\ivanu\OneDrive\Documentos\golfito\scripts\campo.gd` (parcial)
- `C:\Users\ivanu\OneDrive\Documentos\golfito\scripts\util.gd` (constantes)
- `C:\Users\ivanu\OneDrive\Documentos\golfito\project.godot`

## Datos duros del proyecto

| Cosa | Valor | Donde |
|---|---|---|
| Motor de fisica | **Jolt Physics** | `project.godot` -> `[physics] 3d/physics_engine="Jolt Physics"` |
| Physics ticks/s | **60** (no esta puesto, es el default) | `project.godot`, no hay `physics/common/physics_ticks_per_second` |
| Radio de colision | **0.0213 m** (diametro 4.26 cm) | `Piche.tscn`, `SphereShape3D_w6coe` |
| Masa | 0.0459 kg | `Piche.tscn` |
| Velocidad maxima | 26 m/s | `golpe.gd`, `VEL_MAX` |
| `continuous_cd` | true | `Piche.tscn` |
| `contact_monitor` | true, `max_contacts_reported = 4` | `Piche.tscn` |
| `freeze` | true al arrancar, se togglea por guion | `Piche.tscn` + `juego.gd` |
| `body_entered` conectado | **en ningun lado** | grep en `scripts/` y `escenas/` |
| InputMap propio | **no existe** (no hay seccion `[input]`) | `project.godot` |

Numero clave: a 26 m/s y 60 Hz el piche avanza **0.433 m por tick de fisica**,
que son **10.2 veces su propio diametro**. Ese solo numero explica el tunelado,
el colador de barrotes y los contactos que no llegan.

---

## Veredicto corto

**RigidBody3D es DEFENDIBLE aca y no hay que reescribir a CharacterBody3D.**
El juego es literalmente balistica: LOFT, drag, lift por spin (`util.gd`),
rebote (`PhysicsMaterial bounce=0.5`), damping por zona, backspin al aterrizar.
Eso es una simulacion, no un controlador de personaje, y `move_and_slide()` no
hace nada de eso: CharacterBody3D no tiene gravedad, ni rebote, ni damping, ni
masa, ni torque. Migrar significaria reescribir a mano toda la aerodinamica y
perder el rebote gratis.

Lo que **si** esta mal no es el nodo elegido: es que el proyecto usa el
RigidBody en **dos modos incompatibles a la vez** (proyectil simulado y
personaje conducido a velocidad forzada) sin separarlos, y que el cuerpo tiene
un tamano que Jolt documenta como fuera de rango.

---

## Problemas, por gravedad

### 1. El cuerpo mide 4.26 cm: Jolt lo da por fuera de rango (BUG DE RAIZ)

La documentacion de Jolt (la que Godot enlaza, y la citada en el foro oficial)
dice que **los cuerpos dinamicos deben estar en el orden de [0.1, 10] metros** y
con velocidades en [0, 500] m/s. El piche mide 0.0426 m: **2.3x por debajo del
piso recomendado**, con la velocidad en el extremo alto del rango util.

Esto no es purismo. Es la causa comun de los tres sintomas que el proyecto ya
sufrio y documento en `CLAUDE.md`:

- "a 26 m/s la colision la resuelve el CCD y `get_colliding_bodies()` no reporta"
- "el personaje de 4 cm se cuela entre barrotes"
- "la colision de una malla de barrotes es un colador" (que obligo a `_murar()`
  con cajas macizas)

Todos son el mismo problema: **relacion tamano / velocidad / tick fuera de
rango**. En Jolt el radio interno del cuerpo gobierna el umbral de CCD, el
margen de colision (`Collision Margin Fraction` multiplica el eje menor del
AABB) y la tolerancia de penetracion. Con radio interno 0.0213 esas tres
tolerancias son del orden de milimetros, y la penetracion por paso es de
decimetros.

**Arreglo idiomatico (elegir uno):**

- **(a) Desacoplar colision de modelo.** La colision no tiene por que medir lo
  que mide el bicho: subir `SphereShape3D.radius` a ~0.10-0.15 m y dejar el
  modelo chico. Ya se hace exactamente esto al reves en lo visual
  (`_escalar_vista`, `VISTA_PANTALLA`, `VISTA_MAX`): es la misma idea, aplicada
  a la fisica. Es un cambio de una linea en `Piche.tscn`, sin tocar codigo.
- **(b) Escalar el mundo x10.** Correcto pero carisimo: hay que retocar
  `Util.RADIO`, `MASA`, `AREA`, la gravedad, `VEL_MAX`, la jaula, el campo
  entero. No vale la pena.

La (a) es la buena. El unico efecto de juego es que el piche "toca" las cosas
unos 8 cm antes, que a la escala de un muelle no se ve.

### 2. `contact_monitor` + `max_contacts_reported` estan puestos y no se usan

`Piche.tscn` declara `contact_monitor = true` y `max_contacts_reported = 4`, y
**no hay una sola conexion a `body_entered` / `body_exited` en todo el
proyecto** (grep limpio en `scripts/` y `escenas/`). Es coste puro: el motor
mantiene la lista de contactos en cada paso, para nada.

Y el motivo por el que se abandono el mecanismo es un malentendido documentado.
La causa de que `get_colliding_bodies()` "no reporte" no es la velocidad: la
doc de `RigidBody3D` lo dice literal:

> "The result of this test is not immediate after moving objects. For
> performance, list of collisions is updated once per frame and **before the
> physics step**. Consider using signals instead."

O sea: **sondear `get_colliding_bodies()` desde `_physics_process` siempre lee
datos de un paso viejo**, a 26 m/s o a 2 m/s. La senal `body_entered` si
dispara en el paso correcto.

La solucion geometrica de `jaula.gd` (cruce del plano de la puerta,
`_physics_process`, linea ~153) es **robusta y no hay que tocarla**: funciona,
es determinista y no depende del tick. Pero el comentario que la justifica
(`jaula.gd:141`) atribuye el fallo a la causa equivocada, y por esa explicacion
se descarto el mecanismo nativo en TODO el proyecto.

**Arreglo:** o se conecta `body_entered` y se usa, o se apagan
`contact_monitor` y `max_contacts_reported` en `Piche.tscn`. Hoy es config
muerta.

Nota Jolt: si algun dia se usa, el impulso de `get_contact_impulse()` en Jolt
esta **estimado por adelantado** y solo es fiable si el cuerpo no choca con
varias cosas a la vez.

### 3. 60 ticks/s es la mitad de lo que este juego necesita

`project.godot` no toca `physics/common/physics_ticks_per_second`, asi que corre
a 60. La doc oficial de troubleshooting recomienda subirlo a **"multiplos de 60
(120, 180 o 240)"** exactamente para: tunelado, objetos delgados que tiemblan y
simulacion a alta velocidad. Este proyecto tiene los tres.

A 120 Hz el paso maximo baja de 0.433 m a 0.217 m. Combinado con el arreglo
(1a), la penetracion por paso pasa de 10 diametros a ~1.5 diametros: dentro de
lo que el solver resuelve bien.

**Arreglo:** `physics/common/physics_ticks_per_second = 120` en `project.godot`.
Una linea.

**Ojo:** los asserts que cuentan ticks (`for i in 120: await physics_frame` en
`_probar_jaula()`) miden **la mitad de tiempo real** despues del cambio. Hay que
revisar `_self_check()` y los numeros que imprime.

### 4. `_conducir()` reimplementa a mano un CharacterBody3D, y mal

`juego.gd:524-551`. Cada tick, con el stick apretado, hace:

```gdscript
bola.freeze = false
bola.linear_velocity = recta * _vel_andar + Vector3.UP * bola.linear_velocity.y
```

y sin stick: `linear_velocity = 0; angular_velocity = 0; freeze = true`.

Esto es exactamente lo que la doc de `RigidBody3D` desaconseja:

> "Changing the 3D transform or linear_velocity of a RigidBody3D very often may
> lead to some unpredictable behaviors."

Consecuencias concretas y observables:

- **No hay concepto de suelo.** No hay `is_on_floor()`, ni `RayCast3D`, ni
  `ShapeCast3D`: "estoy en el suelo" se decide con un raycast de altura de
  terreno (`campo.altura_terreno`, `juego.gd:452`) y en `_aterrizar()`
  (`juego.gd:610`). Esa es la razon de fondo por la que hizo falta inventar
  `altura_suelo()` pelando capas, y por la que la camioneta trepaba follaje. Un
  `RayCast3D` o `ShapeCast3D` hijo del piche da el suelo REAL (la cubierta del
  barco, la caja de la camioneta, el techo de la jaula) sin pelar capas ni
  adivinar techos.
- **Sin manejo de pendientes ni escalones.** Al forzar la horizontal entera, una
  rampa se sube empujando contra ella hasta que el solver cede; no hay
  `floor_max_angle`, ni deslizamiento, ni snap al suelo.
- **`freeze` se togglea por tick.** En Jolt cambiar el motion type de un cuerpo
  implica sacarlo y volverlo a meter en el broadphase. Hacerlo en cada frame en
  que el jugador suelta y vuelve a apretar el stick es caro y es fuente de
  jitter.
- **`freeze_mode` esta en el default `FREEZE_MODE_STATIC`**, que la doc describe
  como "no collisions along its path" cuando se lo mueve. Para un cuerpo que se
  reposiciona por guion, el correcto es `FREEZE_MODE_KINEMATIC`.
- **El rebote se borra.** `PhysicsMaterial bounce = 0.5` esta activo, pero
  `_conducir()` sobreescribe la velocidad cada tick: chocar andando contra una
  pared no rebota, se queda pegado.

**Arreglo idiomatico, y barato (no migrar el nodo):**

- sustituir el `freeze = true` de reposo por `linear_damp` alto y dejar que el
  cuerpo se duerma solo (`sleeping` / `can_sleep`); como minimo, poner
  `freeze_mode = FREEZE_MODE_KINEMATIC` en `Piche.tscn`;
- meter un `ShapeCast3D` (o `RayCast3D`) hijo del piche como unica fuente de
  verdad de "hay suelo debajo y a que altura", en lugar de
  `campo.altura_terreno()`.

Si el modo "andar" alguna vez pasa a ser el 80% del juego, ENTONCES si vale la
pena partirlo en dos: `CharacterBody3D` para conducir y `RigidBody3D` para el
vuelo, intercambiando cual esta activo. Hoy no.

### 5. Salto y control aereo: estan bien

- **Salto** (`_saltar()`, `juego.gd:558`): `linear_velocity += UP * IMPULSO_SALTO`.
  Es lo idiomatico, incluso en `CharacterBody3D` (`velocity.y = JUMP_VELOCITY`).
  **No es un bug.** Suma en vez de asignar, lo cual es defendible (conserva el
  impulso horizontal) aunque permitiria apilar altura si se llamara dos veces;
  esta guardado por `_saltando`.
- **Falta la comprobacion de suelo real.** Se salta si `quieto and not
  _saltando`, no si "hay suelo debajo". El `ShapeCast3D` del punto 4 arregla
  esto tambien: se puede saltar desde el aire si el estado `quieto` mintio.
- **Control aereo** (`juego.gd:477-480`): `apply_central_force(lado * timon *
  AIRE_ACEL * MASA)`. Fuerza = m*a, correcto, aplicado desde `_physics_process`,
  que es donde Godot acumula fuerzas para el paso siguiente. **Idiomatico. No
  tocar.** Es la mejor parte del codigo de fisica del proyecto.
- **Falta coyote time** (~0.1 s de gracia despues de salir de un borde). No es
  bug, es pulido; es lo que separa un salto que "se siente bien" de uno que no.

### 6. `_integrate_forces` / `custom_integrator`: no hacen falta, pero hay sitios donde ayudarian

La doc dice que para cambiar propiedades fisicas "de forma segura y sincronizada
con el motor" se use el callback
`_integrate_forces(state: PhysicsDirectBodyState3D)`.

Donde el proyecto **si** deberia usarlo: los sitios que asignan
`linear_velocity` a mano dentro del paso de fisica.

- `juego.gd:461` — `bola.linear_velocity *= FRENO_ATERRIZAJE`
- `juego.gd:469` — `bola.linear_velocity = _vel_portazo * _portazo`
- `juego.gd:506` — parada en seco
- `juego.gd:551` — `_conducir()`

Ahi `state.linear_velocity` es la escritura correcta; asignar la propiedad del
nodo puede quedar un paso desfasada respecto del solver.

Donde **no** hace falta: los `apply_central_force` / `apply_central_impulse` ya
estan bien donde estan.

`custom_integrator` **no** conviene: apagaria la gravedad y el damping, que es
justo lo que el juego quiere que el motor haga por el.

Prioridad: **baja**. Es correccion de estilo, no un bug observable, salvo que
aparezcan jitters de un frame en el portazo o en el aterrizaje.

### 7. `apply_central_impulse(_v_pendiente * Util.MASA)` es correcto pero fragil

`juego.gd:425`. Impulso = masa * velocidad_deseada: correcto **si el cuerpo esta
en reposo**. Como el impulso SUMA a lo que ya lleve, si alguna vez se disparara
sin estar quieto, la velocidad de salida no seria `_v_pendiente` y el golpe
saldria mas fuerte o mas debil de lo que dice el HUD. Hoy esta protegido porque
`_v_pendiente` solo se pone tras `soltar()` con el piche quieto y congelado.

**Arreglo idiomatico si se quiere velocidad exacta:** `linear_velocity =
_v_pendiente` directo. Una asignacion esporadica es exactamente el caso que la
doc permite: "Set linear_velocity sporadically if needed, **never per-frame**".
La forma actual es defendible; solo hay que saber que expresa "empujon", no
"velocidad de salida".

### 8. La camara reimplementa SpringArm3D, y con un rayo

`golpe.gd:_sin_pared()` (linea 303) lanza un `intersect_ray` desde el piche
hasta el punto ideal de camara y trae la camara adelante con
`CAM_COLISION_MARGEN`. Eso es, literalmente, lo que hace el nodo nativo
**`SpringArm3D`**, que ademas:

- barre una **forma**, no un rayo. La doc oficial avisa: "if no shape is
  provided ... the spring arm will fall back to using a ray cast which is
  **inaccurate for camera collisions and not recommended**". El codigo actual
  esta exactamente en el caso desaconsejado: un rayo de grosor cero pasa por la
  esquina de un galpon y la camara se clava en la pared igual;
- respeta `collision_mask`, mas limpio que ir arrastrando la lista
  `campo.excluir` de `campo.gd` hasta `golpe.gd`;
- se autora en el editor, que es la regla numero uno de `CLAUDE.md`.

Contra: el codigo actual encuadra desde varios modos (cine, jaula, vuelo) con
suavizado propio; `SpringArm3D` reemplazaria solo `_sin_pared()`, no el resto.

**Prioridad: media-baja.** Es reemplazar codigo propio por nodo nativo, en la
direccion que el proyecto ya declaro querer.

### 9. Sin InputMap: teclas cableadas por codigo

No hay seccion `[input]` en `project.godot`. `golpe.gd` sondea `KEY_G`, `KEY_W`,
`KEY_A`, `KEY_S`, `KEY_D`, `KEY_LEFT` / `KEY_RIGHT`, `JOY_BUTTON_A` y ejes de
joystick crudos con zona muerta propia (`_stick()`); `juego.gd` sondea el
espacio y `KEY_R`.

Lo idiomatico: acciones en el InputMap.
`Input.get_vector("izq","der","ade","atr")` ya devuelve el vector con zona
muerta resuelta por el motor, e `Input.is_action_just_pressed("saltar")` ya da
el flanco que `_pulso_salto` calcula a mano. Beneficios: teclado y mando
unificados sin dos ramas, remapeo, zona muerta del motor.

**Es estilo, no bug.** Pero es mucho codigo que el motor ya trae, y el parche de
`NOTIFICATION_APPLICATION_FOCUS_OUT` (`golpe.gd:158`) existe justamente porque
la carga se sondea por tecla en vez de por accion.

### 10. Detalles menores

- `campo.choque()` (`campo.gd:504`) detecta animales por **distancia puntual por
  tick**, sin barrido. Con radio 1.3 m y 0.433 m por tick funciona hoy, pero es
  el mismo patron que ya fallo con la puerta y falla en cuanto se suba `VEL_MAX`
  o se achique el radio. Un `Area3D` en el animal con `body_entered` es nativo y
  no depende del tick.
- `bola.angular_damp = 0.6` se pone por codigo en `_poner_bola()`
  (`juego.gd:313`). Es un valor fijo, no procedural: pertenece a `Piche.tscn`,
  no a `juego.gd` (regla de `CLAUDE.md`).
- `Vista` con `top_level = true` y transform pisado a mano cada frame
  (`juego.gd:255`) desacopla el modelo del cuerpo. Funciona, pero implica que el
  modelo puede dibujarse donde no esta la colision, que es justo lo que hace
  confusos de diagnosticar los bugs de "se colo".
- `continuous_cd = true` esta bien puesto y ayuda, pero en Jolt el CCD hace un
  **linear cast**: frena el cuerpo antes de atravesar, no resuelve un rebote
  correcto. No sustituye a tener un tamano de cuerpo sano (punto 1).

---

## Resumen ejecutivo

| # | Problema | Bug o estilo | Arreglo en una linea |
|---|---|---|---|
| 1 | Cuerpo de 4.26 cm, fuera del rango [0.1, 10] m de Jolt | **BUG de raiz** | subir el radio de `SphereShape3D` a ~0.10-0.15 m y dejar el modelo chico |
| 2 | `contact_monitor` + `max_contacts_reported` sin ningun `body_entered` | **BUG (config muerta)** | usar `body_entered` o apagar las dos propiedades |
| 3 | 60 physics ticks/s con 26 m/s | **BUG latente** | `physics_ticks_per_second = 120`, y revisar los asserts que cuentan ticks |
| 4 | `_conducir()` fuerza `linear_velocity` y togglea `freeze` por tick, sin suelo real | **BUG de diseno** | `ShapeCast3D` como fuente de suelo + `FREEZE_MODE_KINEMATIC` + dormir en vez de congelar |
| 5 | Salto y timon aereo | **correcto** | anadir coyote time (puro pulido) |
| 6 | `linear_velocity` asignada fuera de `_integrate_forces` | estilo | mover esas 4 asignaciones a `_integrate_forces` si aparece jitter |
| 7 | `apply_central_impulse` en vez de fijar la velocidad de salida | estilo | ok tal cual; asignar `linear_velocity` si se quiere exactitud |
| 8 | `_sin_pared()` = SpringArm3D a mano, y con rayo (desaconsejado) | estilo+ | `SpringArm3D` con forma y `collision_mask` |
| 9 | Sin InputMap, teclas cableadas | estilo | acciones + `Input.get_vector` / `is_action_just_pressed` |
| 10 | Rebote borrado por `_conducir`, `angular_damp` en codigo, `choque()` por distancia | menor | varios, ninguno urgente |

**Lo que NO hay que hacer:** migrar el piche a `CharacterBody3D`. Se perderia la
aerodinamica, el rebote, el damping por zona y el spin, que son la mitad del
juego, a cambio de un `is_on_floor()` que un `ShapeCast3D` da igual de bien.

**Orden sugerido:** 1 -> 3 -> 2 -> 4. Los tres primeros son ediciones de una
linea y probablemente hagan desaparecer solos varios de los parches historicos
(`_murar()` con cajas macizas, `MARGEN` en la jaula, `altura_suelo()` pelando
capas). El 4 es trabajo de verdad.

## Fuentes

- https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html
- https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html
- https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html
- https://docs.godotengine.org/en/stable/tutorials/physics/troubleshooting_physics_issues.html
- https://docs.godotengine.org/en/4.6/tutorials/physics/using_jolt_physics.html
- https://docs.godotengine.org/en/stable/tutorials/3d/spring_arm.html
- https://forum.godotengine.org/t/godot-jolt-physics-and-small-objects-cm-mm/45274
- https://www.gdquest.com/library/glossary/continuous_collision_detection/
- https://kidscancode.org/godot_recipes/4.x/3d/characterbody3d_examples/index.html
