# Auditoría — lo que falta para que esto sea un juego

Estado: 30 de agosto de 2026, rama `feat-ivan`. Revisión de los 5 scripts, las
escenas, `project.godot` y los documentos.

**La limpieza de golf ya se hizo** y no está en esta lista: no quedan par,
golpes, puntos, tarjeta, "Birdie", penalizaciones, copa, bandera ni zonas
calle/rough/green, y los nombres del código son los del juego real. Ver el
resumen al final.

Lo de acá abajo está ordenado por qué tan lejos está de "ser un juego", no por
dificultad.

---

## 1. Bloqueantes: el juego que se describe no existe todavía

### El segundo mapa está enganchado, pero incompleto

Hecho: `juego.gd` tiene `@export var mapas: Array[PackedScene]` y un
`_cargar_mapa(i)` que libera el mapa anterior, instancia el siguiente, espera su
`preparar()` y recablea todo. `mapa.gd` perdió la tabla `NIVELES` (el viento es
`@export` por escena) y valida el contrato en voz alta. El self-check se partió
en `_self_check()` (lo que no depende del mapa) y `_check_mapa()` (cada carga).

Falta en el glb del mapa 2 (`Cerro`):

- **`CAMIONETA`**: sin ella no hay meta, no se siembra basura ni fauna, y el
  mapa no se puede terminar.
- **Dónde arranca el piche**: hoy la `Salida` está puesta a mano junto a los
  conos, provisional. Si arranca encerrado hace falta una malla `jaula` con su
  cara `+X` hacia la meta; si arranca a pie, mover el marcador a donde toque.

Y una cosa de diseño: el Cerro mide **2020 × 3166 m**, tres veces el muelle. A
4,5 m/s caminando son once minutos de punta a punta. Con 24.450 triángulos en 28
mallas es un blockout, no un escenario terminado: hay que decidir si se recorre
entero o si la meta está cerca de la salida.

### No hay final

`_llegar()` hace `indice = (indice + 1) % NIVELES.size()`: con un solo mapa,
vuelve a empezar el mismo. Sin pantalla de llegada, sin "el piche llegó a
casa", sin créditos. Un juego necesita un estado terminal.

### No hay progreso guardado

Cero `user://`, cero save. Un recorrido de varios mapas sin checkpoints: cerrar
el juego borra todo.

### No hay amenaza ni fracaso

Nada puede detener al piche. Caerse del mapa (`pos.y < -60`) lo teletransporta
gratis al punto anterior. Los únicos NPC son animales que huyen. Sin presión,
cruzar el mapa es un paseo largo, no una fuga.

Es el hueco de diseño más grande. Un juego sobre escaparse necesita algo de lo
que escaparse: un perro, una persona, agua, un derrumbe, lo que sea.

### Nadie sabe qué hacer

No hay tutorial, ni texto de objetivo, ni controles en pantalla. Las teclas
están clavadas en código (`KEY_G`, `KEY_SPACE`, `KEY_R`, `KEY_W`…) sin
`InputMap`: no se pueden reasignar, no hay pantalla de controles, y el jugador
tiene que leer el fuente para descubrir que el impulso es G.

### No se puede pausar ni salir

Escape no hace nada. Desde `Juego.tscn` no hay vuelta al menú. Alt+F4 es la
única salida.

### Cero audio

No hay un solo `.ogg`/`.wav` en el proyecto. Ni pasos, ni el portazo, ni
viento, ni música. Es la mitad del *feel* al 0%, y hoy el portazo —que es el
mejor momento del juego— es mudo.

### El piche no se anima

`_preparar_piche()` hace `reproductor.free()`: borra el `AnimationPlayer` del
modelo. El protagonista nunca camina, nunca corre, nunca se asusta; es una
malla que gira como rueda (`_rodar()`). Es la diferencia más visible entre
prototipo y juego.

---

## 2. El verbo central es un swing con otro nombre

Hay dos modos de movimiento que no conversan:

- **Caminar** (`_conducir`): pisa `linear_velocity` cada tick y **congela el
  cuerpo** al soltar el stick. No es física, es un `CharacterBody3D` metido
  adentro de un `RigidBody3D`. Consecuencia de juego: las pendientes no
  existen, la inercia no existe, nada puede empujar al piche, y el terreno del
  mapa es inerte mientras se camina. Tope 4,5 m/s.
- **El impulso**: cargar barra 2 s y salir a 26 m/s con dispersión aleatoria y
  ángulo de salida fijo de 22°. Sigue siendo, mecánicamente, un golpe de golf.

Para un bicho que se escapa, el salto largo cargado tiene sentido como
*recurso* (cruzar un hueco, subir a un techo), pero hoy es el **único** modo de
avanzar rápido. La pregunta de diseño sin contestar: ¿el piche corre, o el
piche se catapulta? Si corre, hace falta correr de verdad —`CharacterBody3D`
con `move_and_slide`, aceleración, inercia, pendientes— y el impulso pasa a ser
puntual.

### La stamina no aprieta

Solo la gasta el impulso (60 a barra llena). Caminar es gratis e infinito, y
hay 16 piezas de basura × 20 = 320 de recarga por mapa contra un tanque de 100.
Siempre alcanza. Como economía, hoy no toma ninguna decisión.

### La basura está sembrada sobre la línea recta

`_poblar_basura` siembra entre la salida y la meta, hasta `RADIO_BASURA` (22 m)
a los costados. O sea: premia ir derecho. Si la stamina tiene que obligar a
desviarse, la basura tiene que estar donde no se pasa por defecto.

### La cámara no mira

Altura fija, sin control vertical, sin mirar alrededor: solo gira cuando gira
el rumbo (mando de tanque). Para orientarse en un muelle grande buscando una
camioneta, eso es un problema serio de navegación, y lo único que guía es un
número de metros en texto.

---

## 3. Presentación

- **El HUD es una salida de debug.** Tres líneas de texto plano con m/s y
  `Timon ####`. Falta lo que sí importa: dónde está la camioneta (brújula o
  marcador en pantalla), qué tecla es qué, cuánto se lleva recorrido.
- **La carga es larga.** La colisión trimesh del mapa entero (60 mallas) se
  genera en cada arranque; por eso existe la portada con `CARGA_MIN` de 5 s. Es
  tiempo real de espera en cada reinicio. La salida ya está anotada como
  `ponytail:` en `mapa.gd`: pasar las formas al importador del glb
  (`_subresources/generate/physics`). Lo que no se puede mover ahí es el ajuste
  a mano del casco del barco.
- **El menú promete lo que no hay.** Tienda y Ajustes contestan "todavia no".
  Mejor sacarlos hasta que existan.
- **El portazo no se puede saltear** y se rearma en cada mapa. La primera vez
  es el mejor momento; la quinta es un peaje de 2,4 s.

---

## 4. Higiene que va a bloquear los mapas 2-4

- **`juego.gd` son ~880 líneas** mezclando reglas, cinemática, HUD, cámara y
  self-check. No se van a poder agregar mapas sin partirlo, porque
  `_ir_a_nivel` asume un solo `Mapa` ya instanciado en la escena.
- **`mapa.gd` y `juego.gd` siguen con ~50 números de *feel* en `const`**
  (damp, stamina, cámara lenta, freno de aterrizaje, tiempos del portazo),
  contra la regla del proyecto. Cada tuneo es editar el script y volver a
  correr. `impulso.gd` ya migró los suyos a `@export_range`.
- **Los autoloads del MCP** (`MCPGameInspector`, `MCPGameInput`) están en
  `project.godot`: se exportan con el juego. Herramienta de desarrollo dentro
  del build.
- **El plugin Terrain3D está habilitado y no se usa** (el escenario es
  fotogrametría), más la carpeta `demo/` entera de su ejemplo. Peso muerto en
  la carga del editor y en el export.
- **`grep.exe.stackdump`** está commiteado.

---

## 5. La escala física del piche

`Util.RADIO` son 2,13 cm de radio y `Util.MASA` 45,9 g: son las medidas de una
pelota de golf, y la esfera de colisión del piche sigue siendo esa. Un piche
real mide unos 40 cm y pesa 3 kg.

No se tocó a propósito: **toda la calibración del juego está hecha sobre esa
esfera** — las velocidades del impulso, el hueco de la jaula, los muros, el
damp, los asserts. Agrandarla es re-tunear el juego entero, no cambiar dos
constantes. Es una decisión de mecánica pendiente, no una limpieza.

---

## 6. Orden sugerido

1. **Un segundo mapa.** Desbloquea la progresión y revela todo lo que asume un
   solo `Mapa` instanciado a mano en `Juego.tscn`.
2. **Pantalla de llegada + guardado.** Terminar tiene que significar algo y
   sobrevivir a cerrar el juego.
3. **Pausa, controles en pantalla, `InputMap`.** Es un día de trabajo y es la
   diferencia entre "se puede jugar" y "no".
4. **Audio y la animación del piche.** Lo que más sube la sensación de juego
   por hora invertida.
5. **Decidir el verbo** (correr vs. catapultarse). De ahí sale si la stamina y
   el impulso quedan como están.
6. **Una amenaza.** Lo que convierte el paseo en una fuga.

---

## Apéndice — la limpieza de golf, ya aplicada

Hecho el 30/8/2026. El self-check headless pasa entero después del cambio.

**Funcionalidad quitada:**

- La copa de golf: `_montar_copa()`, `_punto()`, `R_COPA`, `PROF_COPA`,
  `R_PLATAFORMA`, `ALTO_PLATAFORMA`, `labio_copa()` y la plataforma levantada
  con su cazoleta. La meta es siempre la camioneta; un mapa sin malla
  `CAMIONETA` avisa por consola en vez de degradar a golf en silencio.
- La bandera: `escenas/piezas/Bandera.tscn` y el marcador `Bandera` de
  `escenas/mapas/Muelle.tscn`.
- El marcador: `golpes`, `total`, `tarjeta`, `PUNTOS_HOYO`, `PUNTOS_GOLPE`,
  `par` y el cartel "Birdie / Par / +N". Llegar dice "Llegaste a la camioneta".
- Las penalizaciones: `PENA_ANIMAL` (+2 por atropellar un bicho) y `PENA_DROP`
  (+1 por R). El animal sigue quedando aturdido; R sigue destrabando, gratis.
- Las zonas calle/rough/green: `zona()`, `factor_damp()`, `retiene_efecto()`,
  `es_peligro()`, `nombre_zona()`, `R_GREEN`, `ANCHO_CALLE` y los `ZONA_*`.
  Eran una franja invisible entre la salida y la meta que triplicaba el
  rozamiento y bajaba el control del impulso sin que el jugador pudiera verla.
  `damp_suelo()` es un valor único para todo el mapa, y `impulso.estabilidad`
  se fue con ellas.

**Nombres cambiados** (el código decía golf y hablaba de otro juego):

| Antes | Ahora |
|---|---|
| `golpe.gd`, nodo `Golpe`, `golpeado` | `impulso.gd`, nodo `Impulso`, `impulsado` |
| `bola` | `piche` |
| `hoyo`, `HOYOS` | `nivel`, `NIVELES` |
| `tee`, marcador `Tee` | `salida`, marcador `Salida` |
| `bandera`, `pos_bandera()` | `meta`, `pos_meta()` |
| `embocada()`, `_embocar()` | `llego()`, `_llegar()` |
| `_drop()` | `_destrabar()` |
| `campo.gd`, `class_name Campo`, `Campo.tscn` | `mapa.gd`, `class_name Mapa`, `escenas/mapas/Muelle.tscn` |
| nodo `Curso` (course) | nodo `Escenario` |

**Documentos:** `DISENO.md` describía cuatro hoyos de golf con putt, lava y par
16, y se declaraba con autoridad sobre el código — se reemplazó por el diseño
del juego real. `PRODUCCION.md` se recortó a lo que sigue siendo cierto
(hardware, renderer, fuentes de arte); su plan de esculpir cuatro hoyos en
Terrain3D no aplica a un escenario por fotogrametría.
