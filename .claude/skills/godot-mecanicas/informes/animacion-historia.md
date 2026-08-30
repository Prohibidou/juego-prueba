# Animacion de personaje y cinematicas en Godot 4 — que le falta a Golfito

Investigacion sobre doc oficial de Godot 4 + inspeccion directa de los assets y
del codigo del proyecto. Nada fue modificado.

---

## 0. HALLAZGO QUE CAMBIA LA PREGUNTA: el piche NO tiene esqueleto ni animaciones

Se parseo el chunk JSON de cada .glb del proyecto directamente (header glTF
binario: 12 bytes + chunk JSON). Resultado:

| archivo | animations | skins | nodes |
|---|---|---|---|
| `PGJ_Piche_FINAL.glb` | **0** | **0** | 3 (`GARRAS`, `ojos`, `PicheBody-LOW.001`) |
| `personajes_low_poly.glb` | 0 | **7** | 213 |
| `camioneta.glb` | 0 | 0 | 7 |
| `PGJ_JaulaBODY.glb` / `DOOR.glb` | 0 | 0 | 1 |
| `trash_and_debris.glb` | 0 | 0 | 208 |

El `.fbx` viejo (`PicheLowHighTest07.fbx`) SI trae animacion: 7 `AnimStack`,
16 `AnimCurveNode`. De ahi viene el comentario de `juego.gd:175-179` ("el .fbx
trae animaciones sueltas de Blender") y de ahi viene el `free()`.

### Consecuencias

1. **El piche que se usa hoy no tiene rig.** Tres `MeshInstance3D` sueltos, sin
   `Skeleton3D`. La trampa del CLAUDE.md sobre "el AABB de una malla con
   esqueleto miente" y el anclaje por hueso raiz **no aplica a este asset**
   (aplicaria a `personajes_low_poly.glb`, que si tiene 7 skins).

2. **`_preparar_bola()` (juego.gd:180-186) es codigo muerto hoy.** El importador
   de glTF no crea un `AnimationPlayer` si el archivo no trae clips, asi que
   `vista.get_node_or_null("AnimationPlayer")` devuelve `null` y el `free()`
   nunca corre. No "le borraron las animaciones al piche": el glb actual nunca
   las tuvo.

3. **Pero es una bomba de tiempo.** El dia que se re-exporte el piche CON
   animaciones, esa linea se las come en silencio. Es el bug real de este
   informe, aunque hoy no se note.

4. Los NPC (`personajes_low_poly.glb`) estan riggeados y sin un solo clip. Si
   alguna vez caminan, hace falta traer animaciones aparte (ver §1.4).

---

## 1. Animaciones que vienen en un glb: lo idiomatico

### 1.1 Donde quedan al importar
Godot 4 mete **todos** los clips del glTF en **un solo `AnimationPlayer`**,
hijo de la raiz de la escena importada. Los clips viven dentro de un recurso
`AnimationLibrary`. La libreria por defecto tiene clave `""`, y por eso se
llaman sin prefijo: `play("correr")`. Con libreria nombrada seria
`play("movimiento/correr")`. Godot agrega ademas una animacion **`RESET`**, que
guarda el estado inicial de las propiedades animadas.

Doc: [AnimationPlayer](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html)

### 1.2 Por que alguien borraria el AnimationPlayer, y como se hace bien
El motivo del proyecto es legitimo: **un nodo que viene dentro de una escena
importada no se puede borrar desde una instancia en el editor.** Por eso hay
DOS `free()` de este tipo en el codigo (`juego.gd:183` con el AnimationPlayer,
`campo.gd:107-109` con el marcador "jaula"). Es un sintoma, no un estilo.

Lo idiomatico, de mas barato a mas potente:

- **`animation/import = false`** en el `.import` (una casilla en el dock
  Import). Es exactamente el caso de "el fbx trae animaciones basura de
  Blender": se apagan en el import, no en runtime. Una linea de `.import` en vez
  de un `free()` en `_ready`.
- **Sufijos de nombre desde Blender**: `-noimp` en un nodo lo salta al importar;
  tambien existen `-col`, `-colonly`, `-vcol`, etc. Sirve para que el artista
  controle el import sin tocar Godot.
- **Advanced Import Settings** (doble clic en el archivo): permite por nodo
  "Skip Import" y por animacion elegir loop mode, cortar *slices*, y **"Save to
  File"** para sacar el `.res` de la animacion y editarla sin que el reimport la
  pise.
- **New Inherited Scene** del glb: ahi si se borra/reorganiza a mano y sobrevive
  al reimport. Es el camino cuando hay que agregar colisiones, huesos de
  attachment o scripts al modelo.
- **Filter scripts** (patrones con `*`/`?`) para incluir/excluir clips y tracks
  individuales.

Doc: [Import configuration](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html)

### 1.3 Un modelo SIN esqueleto igual se anima
Un `AnimationPlayer` anima cualquier propiedad de cualquier nodo, no solo
huesos. Con los tres `Node3D` que trae el piche (`GARRAS`, `ojos`, cuerpo) ya se
puede autorar en el editor un `quieto` con respiracion, un parpadeo, un
`aterrizar` con squash. No es lo mismo que un rig, pero es vida y no cuesta
volver a Blender.

### 1.4 Compartir clips: AnimationLibrary
Se puede importar un glTF **solo como animaciones**: cambiando el modo de
import, el archivo se importa como **`AnimationLibrary` en vez de
`PackedScene`**, y se le carga a cualquier `AnimationPlayer` con
`add_animation_library("nombre", lib)`. Es el camino si varios personajes
comparten rig — exactamente el caso de los 7 skins de
`personajes_low_poly.glb`.

---

## 2. AnimationTree + StateMachine vs AnimationPlayer pelado

**Hecho:** `AnimationTree` **no contiene animaciones**; usa las de un
`AnimationPlayer`. Con 0 clips en el proyecto, hoy vale exactamente cero.

La doc oficial lo dice sin vueltas: usar `AnimationPlayer` para cross-fades
simples y fijos; `AnimationTree` cuando hace falta blending complejo, logica de
estados o root motion.

### Recomendacion honesta para ESTE juego
**No metan AnimationTree todavia.** `AnimationPlayer.play("andar", 0.15)` (el
segundo argumento es el blend en segundos) cubre 3-4 clips sin ceremonia. El
umbral para que AnimationTree empiece a pagar:

- un blend **continuo** por parametro (un `BlendSpace1D` andar↔correr manejado
  por `_vel_andar`, que hoy va de 0 a `CONDUCE_MAX = 4.5`), o
- transiciones que dependen de "al terminar la anterior" (modo *At End*), o
- root motion (que aca no aplica, §3).

Con menos que eso, el arbol es una capa de indireccion que hay que abrir en el
editor para entender que pasa.

### Como conectarlo sin acoplar mal
El error tipico es que `juego.gd` llame `play("caer")` con nombres de clip
metidos en la logica de reglas. El patron sano, y que este proyecto **ya
practica** con `jaula.gd` (que emite `reventada` y no sabe quien escucha):

- `Piche.tscn` lleva su propio script y expone algo como
  `estado = "quieto"|"andar"|"volar"|"caer"`.
- Ese script traduce estado → clip. Los nombres de animacion viven ahi y en
  ningun otro lado.
- `juego.gd` setea el estado, igual que hoy setea `golpe.activo`,
  `golpe.tope`, `golpe.enjaulado`. Ya existe la disciplina; falta el nodo.

Doc: [AnimationTree](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html)

---

## 3. Root motion: para este proyecto, ESTORBA. Veredicto NO.

Como funciona: `root_motion_track` apunta a un track de transform de un hueso.
Godot **cancela** el movimiento visual de ese hueso (el personaje anima en el
sitio) y entrega el desplazamiento como delta por frame via
`get_root_motion_position()` / `_rotation()` / `_scale()`, para que **vos** lo
apliques al cuerpo. Hay variantes `_accumulator()` que devuelven el transform
acumulado y respetan los valores iniciales del clip, y `root_motion_local`.

Por que no sirve aca:

1. **No hay hueso raiz al que apuntar.** El glb no tiene skin (§0). El feature
   directamente no se puede configurar.
2. **Esta pensado para `CharacterBody3D`**, donde el script es la autoridad del
   movimiento (`velocity = ...; move_and_slide()`). El piche es un
   `RigidBody3D` movido por `apply_central_impulse`, `apply_central_force`,
   `linear_damp` por zona, `Util.fuerza_aire()`, CCD contra el casco del barco.
   La autoridad la tiene el solver, no el script.
3. Meterlo obligaria a escribir velocidad dentro de `_integrate_forces` para no
   pelear con el solver, y entraria en colision directa con las cuatro cosas que
   ya escriben `linear_velocity` a mano (`_conducir`, `_saltar`, el freno de
   aterrizaje, el guion del portazo).

**La direccion correcta es la inversa:** la fisica manda el desplazamiento y la
animacion se **elige en funcion** de la velocidad (`bola.linear_velocity`,
`_vel_andar`, `_en_aire`). Animacion decorativa, no locomotora.

Doc: [AnimationMixer](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html)

---

## 4. Cinematicas: AnimationPlayer vs Tweens a mano

### Lo que gana AnimationPlayer
- **Se autora en el editor con scrubbing.** Es literalmente la regla del
  CLAUDE.md ("las escenas se autoran en el editor") y la de "no verificar solo
  con asserts: hay que MIRAR". Una linea de tiempo se mira; un tween encadenado
  en tres archivos, no.
- **Call method tracks**: disparar sonido, particulas, un `_aviso()` o
  `abrir()` en el frame exacto, sincronizados con lo que se ve. Hoy eso son
  `tween_callback` y `create_timer` sueltos.
- Una sola linea de tiempo puede animar **la puerta, la velocidad del piche, la
  posicion de la camara, el fov y hasta `current` de dos camaras** a la vez.
- `animation_finished` en vez de un `create_timer(CINE_DURA)` con la duracion
  copiada a mano (hoy `CINE_DURA = 2.4` esta calculado a mano a partir de
  `PORTAZO_EMPUJE + PORTAZO_SUELTA` y `CINE_LENTO`; si alguien toca uno, el otro
  queda desfasado en silencio).
- `callback_mode_process` (PHYSICS / IDLE / MANUAL) permite decidir
  explicitamente en que reloj corre.

### Lo que NO gana (honestidad)
**`Engine.time_scale` tambien escala el `AnimationPlayer`.** Avanza con delta,
igual que el Tween. Cambiar Tween por AnimationPlayer **no cura** la
desincronizacion documentada en el CLAUDE.md. Lo que la cura es que las cosas
que tienen que ir juntas compartan **un solo reloj**.

Hoy el portazo esta partido en **tres relojes distintos**:
- `juego.gd:582-586` — tween de `_portazo` (reloj de juego, escalado)
- `jaula.gd:127-136` — tween de la bisagra (reloj de juego, escalado, con los
  tiempos pasados como argumento para intentar cuadrarlos)
- `juego.gd:602` — `create_timer(CINE_DURA, true, false, true)` (reloj REAL)

Que ese acoplamiento "se cuadre a mano" es exactamente la trampa que ya
costo caro. Un `AnimationPlayer` con las tres cosas en una sola linea de tiempo
elimina la clase entera de bug, no un caso.

### HALLAZGO CONCRETO Y BARATO: `Tween.set_ignore_time_scale(true)` existe
Hace que el tween "ignore `Engine.time_scale` y se actualice con tiempo real
transcurrido", **incluidos los delays de sus Tweeners**. Por defecto `false`.

El proyecto usa el truco equivalente de `create_timer` con el cuarto argumento
en tres lugares (`_aviso`, `_embocar`, `_cine_portazo`) precisamente porque
faltaba este. Ademas hay `set_process_mode()` (IDLE / PHYSICS) y
`set_pause_mode()`. Es una linea por tween y hace explicito en que reloj corre
cada uno, en vez de que se deduzca.

Doc: [Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html)

### El corte de camara
Godot **no** trae blending de camaras 3D nativo (`Camera2D` si tiene
smoothing; `Camera3D` no). Para un corte seco, que es lo que quiere el portazo,
no hace falta nada: **dos `Camera3D` y `make_current()`**.

Detalle util de la doc: si hay varias camaras en la escena, siempre habra una
`current`; poniendo `current = false` en la activa, la otra se activa sola. O
sea: `clear_current()` al terminar el plano y la camara de juego vuelve **sin
que nadie la mande**.

Hoy `cortar_a()` (golpe.gd) teletransporta la unica camara y prende un flag
`cine` que consultan `objetivo_camara()`, `_mirada_deseada()` y `_mover_camara()`.
Hay **tres** lugares que lo apagan (`_montar_jaula`, el `await` de
`_cine_portazo`, `fin_cine`). Si alguna rama sale antes, el flag queda pegado —
que es *palabra por palabra* la trampa documentada de "las banderas que se ponen
en `_process` se quedan pegadas si algo corta antes con un `return`".

Con dos camaras no hay flag que pueda quedarse pegado: el estado ES cual camara
es la current, y lo sabe el motor.

Si algun dia quieren transiciones suaves y no cortes, el plugin de referencia
del ecosistema es [Phantom Camera](https://github.com/ramokz/phantom-camera).

### Es defendible el Tween a mano aca?
**Si, parcialmente.** El portazo es UN plano de 2.4 s en todo el juego. Un
`CutsceneDirector` (patron `await accion(...)` encadenado) o una maquinaria de
timeline seria over-engineering para eso. El problema **no es el Tween**: es que
la cinematica esta repartida en tres archivos y tres relojes, y que la camara de
cine es un flag dentro del controlador de input.

El punto de inflexion: en cuanto haya una **segunda** cinematica (subirse a la
camioneta, un final), el costo de coordinar a mano se duplica y ahi si gana el
AnimationPlayer, o un nodo director con `await`.

Refs: [CutsceneDirector](https://manuelsanchezdev.com/blog/godot-cutscenes/),
[foro: best way to make cutscenes](https://forum.godotengine.org/t/whats-the-best-way-to-make-cutscenes/78096)

---

## 5. Disparadores de historia: Area3D vs distancia por tick

### Lo que hay hoy (todo poll por tick)
| que | donde | como |
|---|---|---|
| recoger basura | `campo.gd:489` `recoger()` | `for` sobre TODA la basura, cada `_process` |
| chocar animal | `campo.gd:504` `choque()` | `for` sobre todos los animales, cada `_physics_process` |
| llegar a la meta | `campo.gd:304` `embocada()` | AABB a mano + `MARGEN_META` + `ALTURA_CAJA` + `VEL_SUBIDO` |
| piche en la jaula | `juego.gd:624` `_en_la_jaula()` | distancia XZ `< 1.8` hardcodeada |
| zona (calle/rough/green) | `campo.gd:318` `zona()` | proyeccion sobre el segmento tee→bandera |
| portazo | `jaula.gd:150` | **cruce de plano en ejes locales** |

### Por que Area3D gana (para lo lento)
- El broadphase del motor lo resuelve; hoy hay un `for` sobre ~200 piezas de
  basura por frame.
- **La forma se autora en el editor**, que es la regla central del proyecto. Los
  numeros magicos (`1.8`, `1.2`, `MARGEN_META`, `ALTURA_CAJA`) dejan de ser
  constantes que hay que palpar y pasan a ser una `CollisionShape3D` que se
  arrastra — exactamente la misma migracion que ya hicieron con el tee de
  `Vector2(1020.0, 821.3)` a un `Marker3D`.
- Es **senal**, no poll: no hay flag que quede pegado, no hay que acordarse de
  llamarlo desde `_process`, y encaja con la regla de "senales hacia arriba".
- `body_entered` **y** `body_exited`: la salida, con distancia, hay que llevarla
  a mano y es donde suelen aparecer los bugs.
- Se puede poner UNA `Area3D` en el piche y que detecte las areas de basura
  (`area_entered`), en vez de una por pieza.

### PERO: donde Area3D es PEOR, y este proyecto ya lo descubrio
La doc de `Area3D` dice que **la lista de solapes se modifica una vez por paso
de fisica, no inmediatamente al moverse los objetos**. A 26 m/s el piche
recorre 43 cm por tick (el mismo numero que ya calcularon en `jaula.gd:145`).
Una `Area3D` fina se atraviesa sin disparar.

Ademas hay reportes de `body_exited` espurio con formas complejas
([issue #23026](https://github.com/godotengine/godot/issues/23026)), y consenso
de que para deteccion critica con objetos rapidos conviene raycast / shape query
del PhysicsServer antes que confiar en las senales de Area.

**La regla que sale de esto, y que este proyecto merece escribir en el CLAUDE.md:**

> Area3D para lo LENTO (andar hasta la camioneta, recoger basura, entrar en una
> zona, un disparador de dialogo). Geometria o rayo para lo RAPIDO (el portazo,
> el casco del barco).

Es decir: **el cruce de plano de `jaula.gd` esta BIEN y no hay que tocarlo.**
Cambiarlo por Area3D seria una regresion. La tercera opcion idiomatica para el
caso rapido, si algun dia hace falta algo mas generico, es `ShapeCast3D` /
`RayCast3D` desde el piche, que barren el trayecto entre frames.

Doc: [Area3D](https://docs.godotengine.org/en/stable/classes/class_area3d.html)

---

## 6. Quien manda la camara durante un corte

Dos patrones idiomaticos:

1. **Camara de cine propia** (un `Camera3D` mas, autorado en la escena) +
   `make_current()` al empezar, `clear_current()` al terminar. La camara de
   juego **no se entera**: no necesita ningun flag `cine`, ninguna rama en
   `objetivo_camara()`, ningun `fin_cine()` que alguien pueda olvidarse de
   llamar. El estado lo guarda el motor.

2. **Una sola camara con un dueno explicito**: un nodo `Cine` que toma el
   control (via `RemoteTransform3D` o escribiendo el transform) y lo devuelve,
   emitiendo `empezo` / `termino`. Vale si la camara de cine tiene que heredar
   calibracion de la de juego.

### El acoplamiento actual, concreto
`golpe.gd` se describe a si mismo como "apuntado, potencia, mando y camara" y
ademas lleva `cine`, `cine_offset`, `cortar_a()`, `fin_cine()`. `juego.gd`
prende y apaga `Engine.time_scale` alrededor. O sea: **la cinematica vive dentro
del controlador de input**, y quien la orquesta es el monolito de reglas.

Separacion sugerida (sin urgencia, es higiene):
- `golpe.gd` → apuntar y potencia. Es lo que dice su propio docstring.
- `Camara.tscn` + script → seguimiento, colision con paredes, fov por velocidad.
  Ya esta todo escrito y bien calibrado, solo hay que mudarlo.
- `Cine` (nodo o AnimationPlayer) → el plano, con su propia camara. Emite
  `termino`. Nadie mas toca `Engine.time_scale`.

Encaja con la nota del CLAUDE.md: "Lo que salga de aca deberia salir como
escena".

---

## 7. Que hacer, en orden

1. **Conseguir clips.** Sin animaciones no hay nada que discutir. Minimo tres
   para el piche: `quieto`, `andar`, `caer`. Si no hay rig todavia, un
   `AnimationPlayer` autorado en Godot sobre los tres `Node3D` del modelo
   (`GARRAS`, `ojos`, cuerpo) ya da vida sin volver a Blender.

2. **Sacar el `free()` del AnimationPlayer** (`juego.gd:181-183`). Hoy es codigo
   muerto; el dia que lleguen los clips se los come. Si vuelve un `.fbx` con
   animaciones basura, la solucion correcta es `animation/import = false` en el
   `.import`, no un `free()` en runtime. **Este es el unico bug real de codigo
   del informe.**

3. **Resolver el choque `_escalar_vista()` vs animacion.** `Vista` es
   `top_level = true` y `juego.gd:250-256` le reescribe el `global_transform`
   ENTERO cada `_process`. Cualquier animacion que toque el transform de la raiz
   del modelo se pisa. Hace falta un nivel intermedio:
   `Vista` (colocacion + escala, la manda el codigo) → `Modelo` (lo anima el
   AnimationPlayer). **Sin esto no entra ninguna animacion**, por buena que sea.

4. **Un solo reloj para el portazo.** Un `AnimationPlayer` en `Jaula.tscn` con
   la bisagra y el ritmo del empuje en una sola linea de tiempo. O, como paso
   intermedio de una linea: `set_ignore_time_scale()` explicito en cada tween,
   para que en que reloj corre cada uno este escrito y no deducido.

5. **Area3D para la meta y para la basura.** Empezar por la meta: es LA
   condicion de victoria y hoy son cuatro constantes magicas y un umbral de
   velocidad. Una `Area3D` sobre la caja de la camioneta + `body_entered` +
   comprobar velocidad al entrar. La basura despues (es rendimiento, no
   correccion).

6. **Camara de cine como nodo aparte + `make_current()`**, y sacar la camara de
   `golpe.gd`. Elimina el flag `cine` y sus tres apagados.

---

## 8. Que dejar quieto (defendible tal cual)

- **El cruce de plano de `jaula.gd`.** Correcto para 26 m/s. Area3D seria una
  regresion. Lo mismo el disparo por rayo contra el casco en `_self_check`.
- **Los Tweens de `_quitar_portada`, del fade y de `campo.gd:548`.** Un tween de
  una propiedad es exactamente para lo que sirve un Tween. No los toquen.
- **El Tween del portazo, en si mismo.** El problema no es el Tween: es que esta
  repartido en tres archivos y tres relojes. Se arregla juntandolo, no
  cambiando de herramienta.
- **AnimationTree.** No, hasta tener 4-5 clips o un blend continuo por
  velocidad. Hoy seria indireccion sin nada adentro.
- **Root motion.** No, nunca, mientras el piche sea `RigidBody3D`. Y ademas no
  hay hueso raiz.
- **`_rodar()`** (juego.gd:197). No es animacion de personaje: es orientacion
  procedural derivada de la velocidad, con tope de rad/s. Un AnimationPlayer no
  lo haria mejor y perderia la relacion con la fisica.
- **La camara de `golpe.gd`.** Funciona, esta calibrada y tiene el rayo
  anti-pared bien resuelto. Separarla es higiene, no urgencia.
- **`zona()` por geometria.** Ya esta marcado con `ponytail:` y es la decision
  correcta hasta que haga falta precision.
