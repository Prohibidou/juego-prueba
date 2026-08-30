# Arquitectura idiomatica de Godot 4 aplicada a Golfito/Piche

Investigacion + lectura del codigo real (`scripts/juego.gd` 894 lineas,
`scripts/campo.gd` 574, `scripts/golpe.gd` 380, `scripts/jaula.gd` 155,
`scripts/util.gd` 117). Nada modificado.

---

## 0. Diagnostico: donde estan las 894 lineas de juego.gd

Mapa por bloques (numeros de linea reales):

| bloque | lineas | de que va | ¿pertenece a "reglas y marcador"? |
|---|---|---|---|
| constantes | 1-92 | 30 constantes de calibracion | a medias (ver §2) |
| variables de estado | 94-139 | 25 vars, 8 de ellas banderas | no: es una FSM disfrazada |
| `_ready` / `_quitar_portada` | 141-173 | arranque + portada | portada no |
| `_preparar_bola` … `_escalar_vista` | 175-257 | **vista del piche: rodar, escalar, apoyar** | **no** |
| `_montar_jaula` | 259-281 | plantar la jaula | si (es el orquestador) |
| `_conectar_tactil` | 283-294 | botones de UI | **no** |
| `_ir_a_hoyo` / `_poner_bola` / `_aplicar_damp` | 296-331 | reset de nivel | si, pero es `enter()` de un estado |
| `_drop` / `_on_golpeado` | 333-359 | reglas | si |
| `_process` | 361-412 | 8 trabajos distintos por frame | a medias |
| `_physics_process` | 415-521 | vuelo, damp, timon, quieto, portazo | si (nucleo) |
| `_conducir` / `_saltar` / `_aterrizar` | 523-612 | locomocion | si |
| `_reventar_puerta` / `_cine_portazo` | 566-604 | **cinematica** | **no** |
| `_marca` / `_aviso` | 631-650 | decals + texto | **no** |
| `_embocar` | 653-675 | meta y marcador | si |
| **`_probar_jaula` + `_empujar` + `_tecla` + `_self_check`** | **678-894** | **codigo de test** | **no** |

**El 24% del monolito (217 lineas) es la bateria de pruebas.** Eso solo ya
es la mitad del problema de tamaño, y sacarlo tiene riesgo cero.

Otro ~10% (83 lineas, `_preparar_bola`..`_escalar_vista`) es como se DIBUJA el
piche, que no tiene nada que ver con las reglas y que ademas ya tiene su propia
escena donde vivir (`Piche.tscn`).

---

## 1. Maquinas de estado

### 1.1 Los tres tipos y para que sirve cada uno

Consenso de la doc y de las fuentes reconocidas (GDQuest, Shaggy Dev,
Godot Foundry, kidscancode):

- **Enum + `match`** — para 3-5 estados, en un solo script, que no se reusan
  entre escenas. "An enum with a match statement is perfectly fine for simple
  cases... less overhead and easier to reason about." Se queda corto cuando hay
  que **medir cuanto llevas en un estado**, **hacer setup al entrar** o
  **limpiar al salir** — ahi "the enum approach gets messy fast".
- **Nodo-estado** (`State extends Node` + `StateMachine extends Node`) — cuando
  cada estado tiene variables propias, o cuando los estados se reusan entre
  varias entidades (patrullar/perseguir/huir en tres enemigos distintos). Se
  ven y se depuran en el arbol, y se pueden `@export`ar transiciones.
- **`AnimationTree` StateMachine** — **solo animacion**. "You cannot put your
  movement code, your input handling, or your AI decision-making inside an
  AnimationTree node." La arquitectura correcta es la doble: FSM de codigo que
  decide QUE hace el personaje, y el AnimationTree decidiendo COMO se ve
  haciendolo, conducido por la primera.

La API canonica de GDQuest para el nodo-estado, por si se llega ahi:

```gdscript
class_name State extends Node
signal finished(next_state_path: String, data: Dictionary)
func enter(previous_state_path: String, data := {}) -> void: pass
func exit() -> void: pass
func update(_delta: float) -> void: pass
func physics_update(_delta: float) -> void: pass
```

y el `StateMachine` conecta `finished` de todos los hijos, y en
`_transition_to_next_state` hace `state.exit()` → cambia → `state.enter()`.

### 1.2 Que tiene ESTE proyecto hoy

Las banderas sueltas que codifican estado, repartidas entre tres scripts:

```
juego.gd:  listo, quieto, embocada, _en_aire, _empujando, _saltando,
           _golpe_volo, _pulso_salto, _v_pendiente != ZERO (¡bandera disfrazada!)
golpe.gd:  activo, cine, enjaulado, puede_saltar, tope, estabilidad
jaula.gd:  _rota, is_instance_valid(_tapa)
```

Y las derivadas que se recalculan **cada frame en `_process`**:

```gdscript
golpe.activo = quieto and not embocada                  # linea 364
golpe.enjaulado = _en_la_jaula()                        # linea 371
```

Los estados reales del juego, leidos del codigo, son cinco:

1. **CARGANDO** (`not listo`) — portada puesta, `_process` y `_physics_process`
   cortan con `return`.
2. **ANDANDO** (`quieto and not embocada`) — el jugador manda: `_conducir`,
   apuntar, cargar barra, saltar, drop.
3. **VOLANDO** (`not quieto`) — manda la fisica: damp por zona, timon, estela,
   deteccion de "quieta".
4. **PORTAZO** (`_empujando` + `golpe.cine` + `Engine.time_scale`) — manda el
   guion: la velocidad la escribe un tween, la camara esta cortada.
5. **META** (`embocada`) — marcador, cartel, cambio de hoyo.

`_saltando` NO es un estado: es un sub-estado de ANDANDO (el comentario de la
linea 553 lo dice explicito: "No toca `quieto`"). Esa bandera esta bien.

### 1.3 Por que esto YA les mordio (evidencia en los propios comentarios)

Tres bugs documentados en el codigo son, literalmente, bugs de FSM:

- **Linea 490-493**: *"`_empujando` se quedaba puesto y el siguiente golpe del
  jugador lo pisaba `_vel_portazo` viejo"*. Traduccion: el estado PORTAZO no
  tenia `exit()`, asi que su bandera sobrevivio a la transicion.
- **CLAUDE.md**: *"las banderas que se ponen en `_process` se quedan pegadas si
  algo corta antes con un `return`"*. `_process` corta en la linea 363
  (`if not listo: return`) y `_physics_process` en la 416
  (`if not listo or embocada: return`). Todo lo que se escribe DESPUES de esos
  returns (`estela.emitting`, `golpe.activo`, `barra.value`, `hud.text`) queda
  con el ultimo valor que tuvo. Con enter/exit por estado, el valor se escribe
  UNA vez al entrar, no cada frame con riesgo de que el frame no llegue.
- **`_poner_bola` (307-326)** es un reset a mano de nueve banderas
  (`quieto`, `_saltando`, `_vel_andar`, `_en_aire`, `_giro`, `_t_lento`,
  `_t_caida`, `_empujando`, `_portazo`, `_mira_rueda`). **Eso es exactamente
  el `enter()` del estado ANDANDO, escrito a mano.** El sintoma clasico: si un
  dia se agrega una decima bandera y no se acuerdan de añadirla ahi, vuelve el
  bug pegado.

### 1.4 Recomendacion concreta

**Enum, no nodo-estado.** Razones especificas de este proyecto:

- Hay UN piche, UN bucle de juego, CINCO estados. No hay reuso entre entidades,
  que es el argumento fuerte del nodo-estado.
- El proyecto tiene un CLAUDE.md con etica ponytail explicita; siete archivos
  nuevos de `State` para cinco estados es justo lo que ese documento prohibe.
- La ganancia real no es el enum: es tener **un solo `_cambiar(nuevo)`** con
  `match` de salida y `match` de entrada. Ahi entra `_poner_bola`, ahi se apaga
  `estela.emitting`, ahi se restaura `Engine.time_scale = 1.0`, ahi se pone
  `golpe.activo`. Un sitio, no ocho.

Forma minima:

```gdscript
enum E { CARGANDO, ANDANDO, VOLANDO, PORTAZO, META }
var estado := E.CARGANDO

func _cambiar(nuevo: E) -> void:
    if nuevo == estado: return
    match estado:                      # salir: apagar lo de este estado
        E.PORTAZO: _empujando = false; Engine.time_scale = 1.0; golpe.fin_cine()
        E.VOLANDO: estela.emitting = false
        ...
    estado = nuevo
    match estado:                      # entrar: encender lo del nuevo
        E.ANDANDO: golpe.activo = true; _vel_andar = 0.0; _t_lento = 0.0
        ...
```

Y `_physics_process` pasa de una escalera de `if` a `match estado:`. Con eso,
`quieto`, `embocada`, `_en_aire` y `_empujando` desaparecen como variables: se
preguntan como `estado == E.X`. **Regla que hay que respetar: una vez que hay
`estado`, ninguna otra variable puede duplicar esa informacion**, o vuelven las
dos fuentes de verdad que causaron el bug de `_empujando`.

`AnimationTree`: no aplica hoy (el piche no tiene animaciones; `_preparar_bola`
de hecho **borra** el `AnimationPlayer` del .fbx, linea 181-183). Cuando llegue
el modelo con animaciones de correr/saltar, el AnimationTree se cuelga del
estado, no al reves.

---

## 2. Custom Resources como datos de nivel

### 2.1 La regla

`class_name X extends Resource` + `@export` → editable en el Inspector,
guardable como `.tres`, anidable. La doc de `node_alternatives` lo pone en la
jerarquia: Object (manual) < RefCounted (automatico) < **Resource
(serializable + Inspector, sin el peso de Node)** < Node. Y la doc de autoloads
lo nombra como la alternativa recomendada "for shared data".

### 2.2 Aplicado a este proyecto: la respuesta es "todavia no", con matiz

`Campo.HOYOS` es hoy:

```gdscript
const HOYOS := [
    {"par": 4, "viento": Vector3(1.0, 0, -0.5)},
]
```

**Un array de un elemento con dos campos.** Convertirlo en
`class_name Hoyo extends Resource` con dos `@export` es ceremonia pura mientras
haya un solo nivel. YAGNI. Cuando haya un segundo y un tercero — y sobre todo
cuando cada nivel traiga su propio mapa, tee, bandera y meta — ahi si:
`@export var hoyos: Array[Hoyo]` en `Campo.tscn` y cada `.tres` arrastrable.

**Lo que SI esta maduro hoy es el `@export`, no el Resource.** El proyecto ya
descubrio ese patron solo y lo aplico bien en `golpe.gd` (lineas 13-60):
`@export_group("Fuerza")`, `@export_range(...) var VEL_MAX := 26.0`. Ese es el
molde. Y hay una prueba de que la constante duele, en `juego.gd` linea 146:

```gdscript
barra_stam.max_value = STAMINA_MAX   # el .tscn no puede leer la constante
```

Esa linea existe solo porque el dato es `const` en vez de `@export`. Con
`@export var STAMINA_MAX := 100.0` el `.tscn` lo guarda y la linea se borra.

Candidatas a pasar de `const` a `@export_range` (mismos numeros, mismo sitio,
solo cambia el annotator):

- `juego.gd`: `STAMINA_*`, `IMPULSO_SALTO`, `CONDUCE_ACEL/MAX`, `GIRO_MAX`,
  `AIRE_ACEL/TIEMPO`, `R_RECOGE`, `VISTA_PANTALLA/MAX`, `CINE_*`, `PORTAZO_*`,
  `PUNTOS_*`, `CARGA_MIN`.
- `campo.gd`: `BASURAS`, `R_GREEN`, `ANCHO_CALLE`, `MARGEN_META`,
  `ALTURA_CAJA`, `VEL_SUBIDO`, `HUNDIDO`.

Las que deben quedarse `const`: las derivadas (`QUIETA_GIRO`, `STAMINA_MIN`,
que se calculan de otras) y las que son identidad y no calibracion
(`META := "CAMIONETA"`, las rutas `res://`, `ZONA_*`).

**Cuidado**: `Campo.HOYOS.size()` se usa desde `juego.gd` (lineas 407 y 670).
Eso es `juego` leyendo una constante de la clase `Campo`, no de la instancia.
Si `HOYOS` pasa a `@export`, hay que pasarlo a `campo.cantidad_hoyos()`.
Es un acoplamiento pequeño pero real.

---

## 3. Composicion por escenas y señales

### 3.1 La regla oficial

De `scene_organization.html`: **"you should design scenes to have no
dependencies"**; comunicacion en dos sentidos, **señales hacia arriba
(nombres en pasado: `entered`, `item_collected`), llamadas hacia abajo**; nunca
`get_node("..")`; el padre inyecta las dependencias del hijo (por señal, por
llamada, por `Callable`, por referencia o por `NodePath`).

### 3.2 Lo que este proyecto ya hace BIEN (no tocar)

**`jaula.gd` + `Jaula.tscn` es un ejemplo de manual y hay que dejarlo quieto.**
Su propio docstring lo dice: "No depende de nada de fuera". Concretamente:

- Señal hacia arriba: `signal reventada(fuera: Vector3)`.
- Llamadas hacia abajo: `vigilar(cuerpo)`, `cuerpos()`, `abrir()`,
  `tirar_puerta(empuje, suelta)`, `colision(activa)`, `frente()`, `cerrada()`.
- No sabe que es un "impulso": lo deduce de `MINIMA := 10.0` m/s (comentario
  en la linea 27). Eso es desacople de verdad, no de nombre.
- La geometria vive en el `.tscn`, no en `_ready`.

`golpe.gd` tambien: `signal golpeado(velocidad)` y recibe sus dependencias por
inyeccion (`preparar(bola, camara)`, `golpe.campo = campo`,
`golpe.suelo = Callable(campo, "altura_terreno")` — esta ultima es exactamente
la tecnica #3 de la doc, "callable properties").

Verificado con grep: **cero `get_node("..")` en todo el proyecto**. La regla
esta entendida.

### 3.3 Lo que falta: solo hay DOS señales en 2158 lineas

`juego.gd` no es un monolito por acoplarse mal hacia arriba, sino por **hacer
demasiadas cosas el mismo**. Los cortes, por relacion beneficio/riesgo:

**A. `Pruebas` (217 lineas, riesgo casi nulo).**
`_self_check`, `_probar_jaula`, `_empujar`, `_tecla` → `scripts/pruebas.gd`,
colgado como nodo `Pruebas` en `Juego.tscn`. `juego.gd` queda con
`await $Pruebas.correr(self)`. Caveat honesto: las pruebas tocan privados
(`_v_pendiente`, `_jaula`, `_saltando`, `campo._meta`); GDScript no tiene
`friend`, pero el `_` es convencion, no barrera, asi que funciona sin cambios.
Bonus: si el nodo `Pruebas` se saca del `.tscn` en release, el codigo de test
no viaja.

**B. `VistaPiche` (83 lineas + 7 variables, riesgo bajo, ya tiene asserts).**
`_preparar_bola`, `_rodar`, `_preparar_modelo`, `_escalar_vista` +
`_diam_bola`, `_caja_bola`, `_angulo_rueda`, `_eje_rueda`, `_dir_rueda`,
`_mira_rueda` → script sobre el nodo `Vista` dentro de `Piche.tscn`.
Interfaz hacia abajo: `func actualizar(dist: float, dt: float, mira: float,
manda_el_jugador: bool)`. Es todo lo que necesita: hoy lee `bola.linear_velocity`
(el padre), `camara.fov` (hermano) y `golpe.mira`/`golpe.activo` (primo) — tres
dependencias externas que se convierten en tres argumentos. Los asserts de
tamaño/apoyo/rodadura (lineas 762-786) se mudan con el.

**C. `Hud` (≈50 lineas, riesgo bajo).**
`juego.gd` alcanza SEIS rutas dentro de la UI: `$UI/Hud`, `$UI/Msg`,
`$UI/Barra`, `$UI/BarraStam`, `$UI/Pegar`, `$UI/Drop`. Eso es el script de
reglas conociendo los internos de la pantalla. Un `UI.tscn` con
`func mostrar(d: Dictionary)` / `func aviso(txt, seg)` hacia abajo y
`signal drop_pedido` / `signal pegar_apretado` / `signal pegar_soltado` hacia
arriba borra `_conectar_tactil` entero y saca de `_process` la cadena de
formato de 10 lineas (404-412).

**D. `Portazo` (≈60 lineas + 8 constantes, riesgo medio, el mas valioso).**
`_reventar_puerta` + `_cine_portazo` + `_empujando` + `_portazo` +
`_vel_portazo` + `PORTAZO_*` + `CINE_*`. Es el unico bloque que toca a la vez
piche, jaula, camara y `Engine.time_scale`, y es el que produjo el bug de la
bandera pegada. Como nodo `Portazo` que recibe `(piche, jaula, golpe)` y emite
`termino`, el `enter/exit` es automatico: el nodo se activa y se apaga.
Es el candidato natural a nodo-estado aunque el resto sea enum.

**E. `Marcas` (≈15 lineas, gratis).** `_marca`, `MAX_MARCAS`, `_marcas`, y ya
hace `campo.add_child(m)`: vive en el campo, dejalo vivir ahi.

**F. `Portada` (≈10 lineas, marginal).** `_quitar_portada` + `CARGA_MIN` →
script del propio `CanvasLayer` con `func esperar(desde_ms)`.

Suma de A+B+C+D+E+F: **≈435 de 894 lineas**. `juego.gd` quedaria en ~460:
reglas, marcador, la FSM y la locomocion. Eso ya es un script, no un monolito.

**G. `Animal.tscn` con cerebro propio (campo.gd).** `campo.animales` es un
`Array[Dictionary]` con `{nodo, dir, t, vivo, color}` y `mover_animales(dt,
pos_bola, peligro)` recorre el array a mano. Pero `Animal.tscn` **ya existe**
(`escenas/piezas/Animal.tscn`). Ese diccionario es el estado de un animal
escrito fuera del animal. Moverlo a un script de esa escena convierte
`mover_animales` en el `_process` de cada bicho, `_aturdir` en su propio
metodo, y `choque()` en una señal `atropellado` hacia arriba.

---

## 4. Autoloads / singletons

### 4.1 La regla oficial

De `autoloads_versus_internal_nodes.html`, los tres problemas: **estado
global** (un objeto responsable de los datos de todos), **acceso global**
("any code anywhere could pass wrong data... the domain to explore to fix the
bug spans the entire project") y **asignacion global de recursos**.

Cuando SI: *"systems with a wide scope. If the autoload is managing its own
information and not invading the data of other objects... a quest or a dialogue
system."*

Alternativas que la doc nombra explicitamente: (a) tipo de Node propio con
`class_name`, (b) Resource propio para datos compartidos, (c) **`static func` /
`static var`** para librerias de funciones sin instanciar.

Y la frase que aplica directo aqui: *"Other engines can encourage the use of
creating manager classes, singletons that organize a lot of functionality into
a globally accessible object. Godot offers many ways to avoid global state
thanks to the node tree and signals."*

### 4.2 Aplicado: NO agregar ninguno

`project.godot` tiene dos autoloads y **los dos son del addon MCP**
(`MCPGameInspector`, `MCPGameInput`), no del juego. Bien.

- Un `GameState` o un `Signals` autoload seria exactamente el antipatron de
  "manager" que la doc nombra: todo el juego vive en una escena con un piche.
- `util.gd` **ya es la forma correcta de lo "global"** en Godot: `class_name`
  con constantes y funciones estaticas (`Util.RADIO`, `Util.MASA`,
  `Util.fuerza_aire`, `Util.disco`). Es literalmente la alternativa (c) de la
  doc. No convertirlo en autoload.
- El unico candidato legitimo a futuro: persistencia entre `Menu.tscn` y
  `Juego.tscn` (mejor marca, ajustes). Y aun ese caso se resuelve mejor con un
  Resource guardado en `user://` que con un autoload.

---

## 5. Grupos (`add_to_group`)

### 5.1 La regla

Etiquetas sobre nodos: `add_to_group`, `get_tree().get_nodes_in_group(...)`,
`get_tree().call_group("guards", "enter_alert_mode")`. La doc los recomienda
"for organizing large scenes and decouple code" en vez de rutas de nodo.
Convencion: `snake_case`.

### 5.2 Aplicado: uso puntual, no general

Verificado: **cero grupos en el proyecto hoy**. No estan causando bugs; lo que
harian es borrar contabilidad manual.

- **`campo.basura`** — hoy es un `Array` con `is_instance_valid` + `remove_at`
  recorrido hacia atras en `recoger()` (lineas 490-505). Un grupo `"basura"`
  hace eso solo: `get_nodes_in_group` nunca devuelve nodos liberados y
  `queue_free()` quita la membresia. Simplificacion real, bajo riesgo.
- **`campo.animales`** — el grupo por si solo NO alcanza, porque el array
  carga estado (`dir`, `t`, `vivo`). El arreglo correcto es §3.3-G (el estado
  se va dentro de `Animal.tscn`) y el grupo queda como el buscador.
- **Los cuerpos de la jaula** (`jaula.cuerpos()`, que hace
  `find_children("*", "StaticBody3D", true, false)` en dos sitios) — podrian
  ser un grupo, pero `find_children` ya funciona y esta encapsulado dentro de
  la jaula, que es donde debe estar. **Dejar quieto.**

Grupos NO sirven aqui como sustituto de señales: la comunicacion
piche↔jaula↔campo es de uno a uno, no de uno a muchos.

---

## 6. Patrones de otros motores que hacen daño en Godot

### 6.1 El "GameManager" de Unity → `juego.gd` ES uno

En Unity un `MonoBehaviour` gigante que lo posee todo es casi obligatorio
porque los scripts no se hablan facil. En Godot el arbol + las señales lo hacen
innecesario. Este es el diagnostico central: `juego.gd` no tiene un problema de
acoplamiento, tiene un problema de **centralizacion heredada**.

### 6.2 Herencia profunda en vez de composicion

"In Unity, you could attach multiple scripts to one node... In Godot, a node
can only extend one script." **Aqui NO es problema**: todos los scripts
extienden `Node3D` directamente, cero jerarquia. Bien.

### 6.3 Construir la escena en codigo (`Instantiate()` en `Awake()` / `SpawnActor`)

El proyecto ya peleo esto y gano; CLAUDE.md lo documenta. Los `.new()` que
quedan, verificados uno por uno, son legitimos salvo un caso:

- Legitimos: `SurfaceTool`, `MeshInstance3D`/`StaticBody3D`/`CollisionShape3D`
  de la copa (geometria que se adapta a la altura del terreno),
  `Node3D` envoltorio de cada pieza de basura (posicion procedural),
  `InputEventKey`, materiales y particulas.
- **A revisar**: `_montar_copa` (campo.gd 355-410, ~55 lineas) + `_punto` +
  `R_COPA` + `PROF_COPA` + `R_PLATAFORMA` + `ALTO_PLATAFORMA` + la rama de copa
  en `embocada()` es **el pasado de golf y hoy es codigo muerto**: la meta es
  la camioneta y `if _meta.size != Vector3.ZERO` corta antes. Son ~80 lineas de
  campo.gd que nunca corren. Hay incluso un assert sobre codigo muerto
  (`juego.gd:760`, `assert(campo.R_COPA > Util.RADIO * 1.5)`).

### 6.4 `Update()` polleando input en vez de acciones — el que si duele

En `_process` (378-382):

```gdscript
# espacio (o X del mando) salta. Flanco a mano: no hay accion en el mapa.
var salta := Input.is_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0, JOY_BUTTON_X)
if salta and not _pulso_salto: _saltar()
_pulso_salto = salta
```

y en la 388, `if golpe.activo and Input.is_key_pressed(KEY_R): _drop()`.

El comentario lo confiesa: *"no hay accion en el mapa"*. Con una accion
`saltar` en el InputMap (tecla + boton de mando en la misma accion),
`Input.is_action_just_pressed("saltar")` **hace el flanco solo** y desaparece
`_pulso_salto`. Y el arnes de pruebas deja de necesitar `_tecla()` con
`InputEventKey.new()` (juego.gd 747-751): `Input.action_press("avanzar")` /
`action_release`. Es un cambio pequeño que borra dos hacks y no toca fisica.

### 6.5 El "tick" unico de Unreal

`_process` hace hoy ocho trabajos sin relacion: banderas de `golpe`, recoger
basura, input de salto, barra de stamina, drop, mover animales, escalar la
vista, y formatear el HUD. Con §1.4 y §3.3 cada uno se va a su sitio o queda
bajo un `match estado`.

---

## 7. Que dejar QUIETO (importante)

1. **`jaula.gd` + `Jaula.tscn`.** Es el modelo a imitar, no a refactorizar.
2. **Los `@export_range` de `golpe.gd`.** Es el patron que hay que copiar a
   `juego.gd` y `campo.gd`, no cambiar.
3. **Las constantes de calibracion fisica y sus comentarios** (`FRENO_ATERRIZAJE`,
   `CAIDA_MAX`, `QUIETA`, `PORTAZO_LENTO`, `CINE_LENTO`…). Son numeros ganados
   a sesiones de prueba. Cambiar el `const` por `@export` conserva el valor;
   **mover el numero, no.** Y CLAUDE.md ya avisa que el assert del primer
   impulso oscila entre 1.6 y 18.7 con el mismo codigo: no sirve de red.
4. **La maquinaria de rayos de `campo.gd`** (`_rayo`, `altura_suelo`,
   `_altura_cruda`, `_altura_sembrable`, el `hit_back_faces = false`, el
   `_techo` medido de la caja). Es densa pero cohesiva y cada linea rara tiene
   su comentario de por que. No es problema de monolito.
5. **Las decisiones de fisica ya cerradas**: trimesh + `backface_collision`,
   el CCD del piche, la tapa hundida de la jaula, los muros macizos.
6. **`_conducir`, `_saltar`, `_aterrizar`.** Pequeñas y cohesivas; se mudaran
   bajo el `match` de la FSM pero no hay que reescribirlas.
7. **`Util` como `class_name` estatico.** No convertir a autoload.
8. **`HOYOS` como constante** hasta que haya un segundo nivel de verdad.

---

## 8. Orden de ataque propuesto

| # | Movimiento | Lineas | Riesgo | Por que ahora |
|---|---|---|---|---|
| 1 | Sacar `_self_check`/`_probar_jaula`/`_empujar`/`_tecla` a `scripts/pruebas.gd` (nodo en `Juego.tscn`) | −217 | nulo | 24% del monolito, sin tocar comportamiento; y deja el arnes listo para el resto |
| 2 | Acciones de InputMap (`saltar`, `avanzar`, `drop`) en vez de `is_key_pressed` + `_pulso_salto` + `_tecla` | −15 | bajo | borra dos hacks, y las pruebas del paso 1 quedan mas limpias |
| 3 | `enum E` + `_cambiar()` con exit/enter; `_poner_bola` pasa a ser `enter(ANDANDO)` | ±0 | **medio** | **arregla la clase de bug de banderas pegadas de raiz**; hacerlo con las pruebas ya extraidas y corriendo |
| 4 | `VistaPiche` dentro de `Piche.tscn` (rodar + escalar + apoyar) | −83 | bajo | bloque grande, sin relacion con reglas, y sus asserts se mudan con el |
| 5 | `UI.tscn` con `mostrar()`/`aviso()` y señales `drop_pedido`/`pegar_*` | −50 | bajo | corta seis rutas `$UI/...` desde el script de reglas |
| 6 | `Portazo` como nodo propio (recibe piche+jaula+golpe, emite `termino`) | −60 | medio | el bloque que causo el bug de `_empujando`; con el paso 3 hecho, el enter/exit es gratis |
| 7 | `Animal.tscn` con su propio script + grupos `animales`/`basura` en `campo.gd` | −40 en campo | bajo | borra el `Array[Dictionary]` y la contabilidad de `is_instance_valid` |
| 8 | `const` → `@export_range` en `juego.gd` y `campo.gd` (copiando `golpe.gd`) | ±0 | bajo | permite tunear sin recompilar y borra el apaño de `barra_stam.max_value` |
| 9 | Borrar el fallback de golf (`_montar_copa`, `_punto`, `R_COPA`…, rama de copa en `embocada`) | −80 en campo | bajo | codigo muerto; lo pide CLAUDE.md ("ir sacando el pasado de golf") |
| 10 | `class_name Hoyo extends Resource` para `HOYOS` | +20 | bajo | **solo cuando exista el segundo nivel.** Antes, no. |

Resultado esperado: `juego.gd` de 894 → ~460 lineas, `campo.gd` de 574 → ~450,
y los estados en una sola variable con un solo sitio donde se encienden y se
apagan las banderas.

**Verificar despues de cada paso** con la corrida headless de CLAUDE.md
(`--headless --path . res://escenas/Juego.tscn --quit-after 4500`), y mirar con
el MCP despues de los pasos 4, 5 y 6, que son los que cambian lo que se VE.
Recordar que el numero del primer impulso oscila: correr dos o tres veces antes
de dar una regresion por buena.

---

## Fuentes

- [Scene organization — Godot docs](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html)
- [Autoloads versus regular nodes — Godot docs 4.5](https://docs.godotengine.org/en/4.5/tutorials/best_practices/autoloads_versus_internal_nodes.html)
- [When to use Node vs Object/RefCounted/Resource — Godot docs](https://docs.godotengine.org/en/4.6/tutorials/best_practices/node_alternatives.html)
- [Groups — Godot docs](https://docs.godotengine.org/en/stable/tutorials/scripting/groups.html)
- [Make a Finite State Machine in Godot 4 — GDQuest](https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/)
- [Node-Based State Machine in Godot 4 — Godot Foundry](https://godotfoundry.com/blog/godot-4-state-machine-tutorial)
- [Starter state machines in Godot 4 — The Shaggy Dev](https://shaggydev.com//2023/10/08/godot-4-state-machines/)
- [Using the AnimationTree StateMachine — Godot 4 Recipes (kidscancode)](https://kidscancode.org/godot_recipes/4.x/animation/using_animation_sm/index.html)
- [Godot 4 State Machine Tutorial — Godot Learning](https://godotlearning.com/blog/godot-4-state-machine-tutorial)
- [A brief look at custom resources in Godot 4 — The Shaggy Dev](https://shaggydev.com/2026/04/08/godot-custom-resources/)
- [Why You Should Use Godot's Custom Resources — Mina Pêcheux](https://medium.com/codex/why-you-should-use-godots-custom-resources-ae3087e05acf)
- [Singletons and Autoloads with Godot — JetBrains Guide](https://www.jetbrains.com/guide/gamedev/tutorials/singletons-autoloads-godot-csharp/)
