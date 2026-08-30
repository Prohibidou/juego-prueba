# Camara de tercera persona y game feel en Godot 4 — aterrizado a golfito

Investigacion sobre `scripts/golpe.gd` (camara a mano) y `escenas/Juego.tscn`.
Godot 4.6, renderer Mobile, Jolt Physics, personaje = `RigidBody3D` (`Piche`).

---

## 0. El hallazgo principal (y no es SpringArm3D)

`project.godot` **no tiene `physics/common/physics_interpolation=true`**. No aparece
la seccion. Y el proyecto reune, punto por punto, el caso canonico de jitter que la
doc de Godot describe:

- el personaje es un `RigidBody3D` (se mueve solo en el tick de fisica, 60 Hz por defecto),
- la camara es un nodo **suelto** (`Camara` es hermano de `Piche` en `Juego.tscn`, no hijo),
- la camara se posiciona en **`_process`** (`_mover_camara(dt)` desde `_process`),
- y lee **`_bola.global_position` crudo** (`objetivo_camara`, `_mirada_deseada`, `_sin_pared`).

A `VEL_MAX = 26.0` m/s el piche avanza **~43 cm por tick de fisica**. En un monitor de
144 Hz eso son ~2.4 frames de render mostrando la bola en el mismo sitio y despues un
salto de 43 cm. El `lerp` con `CAM_SUAVIZADO = 14.0` disimula parte del escalon en la
posicion de la camara, pero **no** en el `look_at` ni en el modelo.

Peor: `juego.gd:397` llama `_escalar_vista(...)` desde `_process`, y `_escalar_vista`
(`juego.gd:250`) hace `vista.global_transform = ... bola.global_position ...`. El nodo
`Vista` tiene `top_level = true` en `Piche.tscn`, o sea que **el piche que se ve en
pantalla se coloca a mano cada frame de render a partir de una posicion que solo cambia
a 60 Hz**. Ese es el que mas va a saltar.

### Que dice la doc oficial

Godot 4.4 devolvio la interpolacion de fisica en 3D. La guia rapida
(`physics_interpolation_quick_start_guide`) pide:
1. Project Settings > Physics > Common > Physics Interpolation = On.
2. Mover las cosas en `_physics_process`, no en `_process`.
3. `Node.reset_physics_interpolation()` despues de teletransportar.

Pero la pagina **avanzada** (`advanced_physics_interpolation`) tiene una seccion
dedicada a camaras, y dice exactamente lo contrario para ellas:

> Las camaras son "muy sensibles al movimiento de camara" y les conviene la
> interpolacion **manual** antes que la automatica.
> - Posicionar la camara en espacio global: nodo independiente, o `top_level = true`.
> - Usar `get_global_transform_interpolated()` sobre el nodo objetivo dentro de `_process`.
> - Desactivar la interpolacion automatica con `physics_interpolation_mode` para
>   controlarla a mano.

Y sobre por que no sirve `get_global_transform()`:

> te da el transform del tick de fisica actual, con lo que la camara pega saltos en
> cada tick a medida que el objetivo se mueve.

Ojo con el aviso: `get_global_transform_interpolated()` "solo deberia usarse una o dos
veces, para casos especiales como camaras", no repartido por todo el codigo.

### Traduccion a este proyecto

La arquitectura de `golpe.gd` **ya es la que la doc recomienda**: camara suelta,
movida en `_process`, en espacio global. Lo unico que falta es la fuente de datos.

- Activar `physics_interpolation` en `project.godot`.
- En `golpe.gd`, reemplazar los `_bola.global_position` de `objetivo_camara()`,
  `_mirada_deseada()` y `cortar_a()` por `_bola.get_global_transform_interpolated().origin`.
  Son 5-6 sitios; conviene cachearlo una vez por frame en `_mover_camara` y pasarlo,
  justo por el aviso de "una o dos veces".
- En `juego.gd:250` `_escalar_vista()`, lo mismo para colocar `Vista`.
- Poner `physics_interpolation_mode = OFF` en `Camara` y en `Vista`: los dos se
  escriben a mano cada frame, y dejar que ademas el motor los interpole daria un
  frame de retraso encima.
- `cortar_a()` (`golpe.gd:346`) es un corte duro de camara: ahi va
  `reset_physics_interpolation()`. Igual en `encuadrar()` (`golpe.gd:362`), que
  tambien teletransporta.
- `_montar_jaula()` y cualquier reposicionamiento del piche entre hoyos: idem sobre `Piche`.

Bug conocido a tener presente: godot#103724, `get_global_transform_interpolated()`
devuelve el transform equivocado justo despues de `reset_physics_interpolation()`.
Y godot#94060, el primer uso puede dejar un "streak". O sea: probar el corte de cine.

Alternativa mas barata si esto se complica: subir
`physics/common/physics_ticks_per_second` de 60 a 120. No es la solucion correcta pero
reduce el escalon a la mitad por una linea, y Jolt lo aguanta de sobra con un solo
RigidBody activo.

---

## 1. SpringArm3D

### Que hace exactamente

Lanza, a lo largo de su **eje Z local**, un raycast (o un shapecast si tiene `shape`)
de longitud `spring_length`. Si pega, **reposiciona todos sus hijos directos** al punto
de impacto menos `margin`. Nada mas. No mueve ni rota nada por si mismo.

### Propiedades

| Propiedad | Default | Que hace |
|---|---|---|
| `spring_length` | 1.0 | largo maximo del brazo; distancia de camara |
| `margin` | 0.01 | cuanto se aparta del punto de impacto, para no clavar el lente |
| `collision_mask` | 1 | capas de fisica que lo bloquean |
| `shape` | null | si se pone, hace shapecast en vez de raycast |

Metodos: `add_excluded_object(RID)`, `remove_excluded_object(RID)`,
`clear_excluded_objects()`, `get_hit_length()`.

Detalle util del tutorial oficial (`tutorials/3d/spring_arm.html`): si dejas `shape`
vacio **y la Camera3D es hija directa del brazo**, el brazo usa la piramide del near
plane de la camara como forma de colision. Si la camara no es hija directa, cae al
raycast, que la doc llama poco fiable para camaras.

### Mapeo 1 a 1 con el codigo actual

`_sin_pared()` (`golpe.gd:303`) es literalmente un SpringArm3D a mano:

| `golpe.gd` | SpringArm3D |
|---|---|
| `PhysicsRayQueryParameters3D.create(desde, objetivo)` | el raycast interno |
| `CAM_ATRAS_TIRO` / `CAM_ATRAS_JAULA` / `lerp(MIN,MAX,t)` | `spring_length` |
| `CAM_COLISION_MARGEN = 0.25` | `margin` |
| `q.exclude = campo.excluir` | `add_excluded_object()` |
| `choque["position"] + normal * margen` | el reposicionado de hijos |

O sea: **si, SpringArm3D reemplaza el rayo hecho a mano.** Casi campo por campo.

### Las limitaciones reales (y aca esta el pero)

1. **No tiene suavizado ninguno.** El brazo *snapea* a la primera colision y *snapea*
   de vuelta al soltarla. No hay damping, no hay ease. Es la queja numero uno en el
   foro y en las propuestas (godot-proposals#12098: "siempre castea, siempre snapea a
   la primera colision entre origen y final, lo que causa un monton de snaps
   innecesarios que incomodan al jugador").
2. **No podes saber si esta colisionando.** No hay `is_colliding()`
   (godot-proposals#8691). Solo `get_hit_length()`, que devuelve `spring_length` cuando
   no pega — indistinguible de pegar justo al final. Por eso es tan dificil hacerle
   un retorno suave a mano.
3. **Corre en el tick de fisica, no en el de render** (godot-proposals#11770 pide
   justamente una opcion para actualizarlo cada frame renderizado). Con fisica a 60 y
   render a 144, el brazo introduce su propio escalon.
4. **Los hijos van un frame de fisica atrasados** (godot#108509).
5. **Puede tunelar** con el backend de Godot Physics (godot#47093).

### Veredicto honesto para golfito

**`_sin_pared()` es defendible tal como esta**, por una razon concreta y no por dogma:

el resultado de `_sin_pared()` no se aplica directo — vuelve como `objetivo_camara()`
y **pasa por el `lerp` de `CAM_SUAVIZADO`** en `_mover_camara` (`golpe.gd:377`). Es
decir, la correccion por pared **esta suavizada**, que es exactamente lo que
SpringArm3D no sabe hacer y lo que la gente termina reimplementando encima.

Ademas hay dos cosas que un SpringArm3D no cubre sin trabajo extra:

- **El modo cine** (`golpe.gd:284`) usa un offset **arbitrario** relativo a la bola
  (`lado * CINE_LADO - fuera * CINE_FRENTE + Vector3.UP * CINE_ALTO`), no una
  distancia sobre el eje Z de un brazo. Con un brazo habria que rotarlo para que su
  -Z apunte ahi y recalcular `spring_length` como la longitud del offset. Se puede,
  pero es mas codigo, no menos.
- **La lista `exclude` compartida.** `q.exclude = campo.excluir` reusa exactamente la
  misma lista que `campo.altura_terreno()`, y el comentario del codigo documenta por
  que (los barrotes de la jaula). Con SpringArm3D habria que sincronizar esa lista a
  mano via `add_excluded_object` cada vez que `campo.excluir` cambia — y `excluir`
  cambia cuando se remonta la jaula (`_montar_jaula`). Es una fuente de bugs nueva.

**Una asimetria que si vale la pena mirar** (independiente de SpringArm3D): hoy la
camara tarda lo mismo en *entrar* que en *salir* de la pared, ~1/14 s en ambos casos.
Lo que hacen los juegos comerciales es **snapear hacia adentro al instante** (para no
ver a traves de la pared ni un frame) y **volver despacio**. Serian dos lineas: si el
objetivo esta mas cerca que la posicion actual, usar paso 1.0; si esta mas lejos, el
`_paso(CAM_SUAVIZADO, dt)` de siempre.

---

## 2. El rig de nodos (pivote / brazo / camara)

Jerarquia idiomatica segun la doc y la practica comun:

```
Player (CharacterBody3D / RigidBody3D)
└── CameraPivot (Node3D)      <- rota (yaw/pitch); a la altura del pecho, no del piso
    └── SpringArm3D           <- spring_length = distancia
        └── Camera3D          <- transform en cero
```

Por que se prefiere sobre calcular la posicion por codigo:

- La composicion (altura, distancia, ladeo) se **arrastra en el editor** en vez de
  vivir en constantes. Esto es literalmente la regla del `CLAUDE.md` de este proyecto.
- La trigonometria de orbitar sale gratis: rotar el pivote **es** mover la camara.
  `_dir_camara`, `_girar_hacia()` y los `sin(mira)/cos(mira)` desaparecen o se
  reducen a `pivote.rotation.y`.
- La colision sale gratis (con las salvedades de arriba).

**Pero este rig asume que la camara es hija del jugador**, y ahi hay un choque directo
con el punto 0: si la camara cuelga del `RigidBody3D`, hereda su cadencia de 60 Hz y
**hay que confiar en la interpolacion automatica**, que la doc avanzada desaconseja
justo para camaras. La camara suelta de `golpe.gd` es la configuracion que la doc
recomienda.

**Donde si conviene el rig aca:** un `Node3D` "PivoteCamara" **suelto** (no hijo del
piche), colocado en el editor, al que `golpe.gd` solo le escribe `global_position` y
`rotation.y`, con la `Camera3D` de hija a una distancia autorada. Eso saca
`CAM_ALTO`, `CAM_ATRAS_TIRO`, `CAM_ALTO_JAULA` y `CAM_ATRAS_JAULA` del codigo y los
convierte en cosas que se arrastran, sin renunciar a la camara en espacio global.
Es un cambio de mediano tamano y de beneficio real pero moderado.

Nota sobre el mando: el esquema de `golfito` es de tanque (`mira` es a la vez rumbo y
angulo de camara), no orbita libre con mouse. Casi todo el material de SpringArm3D de
internet asume orbita con mouse capturado. El rig igual mapea (`pivote.rotation.y = mira`),
pero mucho de lo que se lee no aplica tal cual.

---

## 3. Camera3D, fov y CameraAttributes

- **`fov` es propiedad de `Camera3D`**, no de `CameraAttributes`. Grados, solo en
  proyeccion perspectiva.
- **`CameraAttributesPractical`** controla **exposicion automatica y desenfoque
  (DOF)**: `dof_blur_near_enabled`, `dof_blur_far_enabled`, `dof_blur_amount`,
  `auto_exposure_min/max_sensitivity`. **No toca el fov.**
- **`CameraAttributesPhysical`** es el hermano fotografico (apertura, obturador,
  ISO) y ese si tiene `frustum_focal_length`, que **sobreescribe el `fov` de la
  Camera3D** cuando el recurso esta asignado. Es una trampa a conocer, no algo que
  convenga usar aca.

**Conclusion: tocar `fov` por codigo es lo correcto.** No hay nodo nativo que abra el
fov con la velocidad. `_mover_camara` (`golpe.gd:383-384`) ya lo hace bien: valor
objetivo + `lerp` exponencial independiente de fps, con `CAM_FOV_SUAVIZADO = 4.0`
deliberadamente mas lento que la posicion. No hay nada que reemplazar.

Lo que si es nativo y esta sin usar: **`h_offset` / `v_offset`** de `Camera3D`. Doc:
"El desplazamiento horizontal (X) / vertical (Y) del *viewport* de la camara". Desplazan
el **frustum**, no el nodo. Para screen shake eso es oro: sacude sin mover el nodo,
o sea sin invalidar el `look_at`, sin ensuciar el `lerp` de posicion y sin meterse en
el rayo de `_sin_pared()`. Ver punto 5.

---

## 4. Addons: PhantomCamera

El unico serio para Godot 4. MIT, muy bien documentado (phantom-camera.dev), inspirado
en Cinemachine de Unity. Minimo Godot 4.3. Se instala desde AssetLib (bajar, marcar
solo `phantom_camera/`, activarlo en Project Settings > Plugins).

Modelo: **no reemplaza la `Camera3D`, la maneja.** Se ponen nodos `PhantomCamera3D` en
la escena, cada uno con una `priority`, y un `PhantomCameraHost` mueve la `Camera3D`
real hacia la de mayor prioridad, con tween. Trae:

- Follow modes, entre ellos **Third Person**, que por dentro **es un `SpringArm3D`** y
  expone `spring_length`, `margin`, `collision_mask`, `shape`, `follow_offset`,
  `follow_damping` + `damping_value` (Vector3, por eje), y offsets de rotacion
  vertical/horizontal. **Ese `follow_damping` es justamente el suavizado que le falta
  al SpringArm3D pelado.**
- Look At: Mimic / Simple / Group.
- **`PhantomCameraNoise3D`**: nodo de ruido para screen shake, resuelto.
- `PhantomCameraTweenDirector`: animar entre camaras.
- En su FAQ recomiendan explicitamente activar Physics Interpolation en 4.4+ para
  el jitter con cuerpos de fisica — o sea, ni siquiera el addon te evita el punto 0.

Limitaciones declaradas por los propios autores: "etapas tempranas", features sujetas
a cambio, escrito en GDScript (hay planes de pasarlo a GDExtension por rendimiento).
Algunas releases marcadas como inestables.

**Veredicto para golfito: no vale la pena.** Y no por calidad del addon, que es bueno.

- El valor grande de PhantomCamera es el **sistema de prioridades y blending entre
  muchas camaras**. Aca hay **cuatro estados** (activo, vuelo, enjaulado, cine) que ya
  estan resueltos con dos `if` en `objetivo_camara()` y `_mirada_deseada()`.
- **No arregla el problema real** (jitter de interpolacion), lo delega en la misma
  config de proyecto.
- Lo unico que aporta de verdad es `follow_damping` + `PhantomCameraNoise3D`, y las
  dos son ~20 lineas propias.
- Meter una dependencia GDScript en la ruta caliente de camara para reimplementar lo
  que ya funciona, en un proyecto que ademas tiene reglas explicitas contra el
  sobre-diseno, no se paga.

Si algun dia hacen falta muchos planos de cine encadenados con blends, se reevalua.

---

## 5. Game feel

### Screen shake

Consenso (kidscancode Godot 4 Recipes, Shaggy Dev, Musa Haydar): **sistema de trauma
con ruido**, no offsets aleatorios.

- `trauma` 0..1; cada impacto suma; decae una cantidad fija por frame.
- La magnitud es `trauma * trauma` (o `^3`): decae no-lineal, y golpes seguidos
  escalan feo a proposito.
- El desplazamiento sale de **`FastNoiseLite`** muestreado avanzando en el tiempo, no
  de `randf()`. El random puro "rompe la conexion con la camara porque se mueve
  instantaneamente, y el movimiento queda chocante". El ruido da una sacudida
  continua, que se lee como camara en mano.

**Como meterlo aca sin pelearse con el motor:** al final de `_mover_camara()`, despues
del `look_at`, escribir `_camara.h_offset` y `_camara.v_offset` desde el ruido. Nunca
sumarlo a `global_position`: eso lo comeria el `lerp` del frame siguiente y ademas
movería el origen del rayo de `_sin_pared()`. Con `h/v_offset` el nodo no se mueve, se
mueve el frustum. Es el enganche mas limpio y es nativo.

Disparadores naturales que ya existen: el portazo de la jaula (`_cine_portazo`), el
aterrizaje (`_aterrizar`), el impulso a `VEL_MAX`.

### Hitstop

Es un `Engine.time_scale` bajo por muy poco tiempo (0.05–0.15 s) y vuelta a 1.0.
El proyecto **ya tiene la infraestructura y ya se comio las trampas**: `_cine_portazo`
(`juego.gd:601`) hace exactamente eso, y `CLAUDE.md` documenta las dos que muerden —
los `Tween` se escalan con `time_scale`, y los `create_timer` que deben durar en tiempo
real necesitan el flag `ignore_time_scale` (el codigo ya usa `create_timer(CINE_DURA, true, false, true)`).
Y `_montar_jaula` resetea `Engine.time_scale = 1.0` defensivamente.

Recomendacion de la practica comun: **no empaquetar** hitstop + flash + shake en un
solo efecto rigido; exponerlos como flags de una sola llamada, tipo
`impacto(intensidad, sacude := true, congela := false)`.

Aviso concreto para este proyecto: un hitstop global con `Engine.time_scale` **congela
tambien la camara**, porque `_mover_camara` usa `_paso(k, dt)` y `dt` viene escalado.
Eso normalmente es lo que se quiere. Pero el shake tiene que seguir corriendo durante
el congelamiento, o sea que el avance del ruido debe usar tiempo real
(`Time.get_ticks_msec()`) y no acumular `dt`.

### Squash and stretch

Aplastar al aterrizar y estirar al despegar. Dos formas:

- **`Tween` one-shot** sobre `scale`, con `TRANS_BACK`+`EASE_OUT` (sobrepaso corto y
  asentado) o `TRANS_ELASTIC`+`EASE_OUT` (rebote).
- **Muelle amortiguado** por frame, que sobrepasa del aplastado al estirado y se
  asienta solo. Mejor para algo que aterriza muchas veces seguidas.

**Trampa especifica de golfito:** `_escalar_vista()` (`juego.gd:250`) **reescribe
`vista.global_transform` entero cada frame de `_process`**. Un `Tween` sobre
`vista.scale` se lo comeria el siguiente frame. Hay que meter un
`var _squash := Vector3.ONE` que `_escalar_vista` multiplique dentro de su `base`, y
tweenear **esa variable**, no la propiedad del nodo. Y como el nodo se escribe a mano,
tampoco sirve `AnimationPlayer` sobre su transform.

Segunda trampa: el aplastado tiene que ir en ejes **de mundo** (achatar en Y, ensanchar
en XZ), y `_escalar_vista` ya construye `base` desde `_rodar()`, que es la rotacion de
rodadura de la bola. Aplicar el squash *dentro* de `base` lo aplastaria en ejes de la
bola rodante — exactamente el bug que el comentario de `_escalar_vista` dice que ya
ocurrio una vez ("antes el levante iba en ejes de la bola y al rodar apuntaba hacia
abajo: por eso se hundia en el mapa"). El squash va **por fuera**, en mundo.

`_aterrizar()` (`juego.gd:608`) es el gancho listo para el aplastado.

---

## 6. Resumen de acciones, ordenadas por relacion valor/riesgo

1. **Activar `physics_interpolation` + `get_global_transform_interpolated()`** en
   camara y en `Vista`, con `physics_interpolation_mode = OFF` en los dos y
   `reset_physics_interpolation()` en `cortar_a`/`encuadrar`/remonte de jaula.
   Es el unico problema *real* y no resuelto. Barato: subir `physics_ticks_per_second`
   a 120 mitiga por una linea.
2. **Screen shake con trauma + FastNoiseLite sobre `h_offset`/`v_offset`.** ~20 lineas,
   nativo, no toca la ruta de posicion ni el rayo.
3. **Snap-in / ease-out asimetrico en `_sin_pared`.** Dos lineas.
4. **Squash and stretch** via multiplicador dentro de `_escalar_vista`, aplicado en
   mundo, disparado desde `_aterrizar()`.
5. **Rig `PivoteCamara` + `SpringArm3D` suelto** (opcional): saca 4 constantes al
   editor. Beneficio real pero moderado, y hay que resolver el modo cine y la
   sincronizacion de `campo.excluir`.
6. **PhantomCamera**: no.

Lo que **no** hay que tocar: el `fov` por codigo (es lo correcto, no hay nativo), el
`_paso()` exponencial independiente de fps (esta bien hecho), `_girar_hacia()` con
tope de giro (no existe nativo), y la camara como nodo suelto en espacio global
(es literalmente lo que recomienda la doc avanzada).

---

## Fuentes

- https://docs.godotengine.org/en/stable/classes/class_springarm3d.html
- https://docs.godotengine.org/en/stable/tutorials/3d/spring_arm.html
- https://docs.godotengine.org/en/stable/classes/class_camera3d.html
- https://docs.godotengine.org/en/stable/classes/class_cameraattributespractical.html
- https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_quick_start_guide.html
- https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html
- https://github.com/godotengine/godot-proposals/issues/12098 (SpringArm3D snapea siempre)
- https://github.com/godotengine/godot-proposals/issues/8691 (sin `is_colliding()`)
- https://github.com/godotengine/godot-proposals/issues/11770 (corre en tick de fisica)
- https://github.com/godotengine/godot/issues/108509 (hijos un frame atrasados)
- https://github.com/godotengine/godot/issues/47093 (tunelado)
- https://github.com/godotengine/godot/issues/103724 (bug de `reset_physics_interpolation`)
- https://bugnet.io/blog/fix-godot-physics-interpolation-jitter-on-camera-follow
- https://phantom-camera.dev/ , /overview/what-is-this , /follow-modes/third-person , /support/faq
- https://kidscancode.org/godot_recipes/4.x/2d/screen_shake/
- https://shaggydev.com/2022/02/23/screen-shake-godot/
- https://www.musah.net/posts/godot-4-screenshake.html
- https://codingquests.io/blog/godot-4-tween-tutorial-juice
