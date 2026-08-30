# Golfito / Piche: La Gran Fuga

Juego de historia en Godot 4.6: un piche (armadillo) se escapa y hay que
llevarlo hasta un punto. NO es un juego de golf. Escenario real por
fotogrametria. Codigo y comentarios en castellano, sin tildes ni enies en el
codigo; los textos de pantalla si llevan.

**El pasado de golf ya se saco del codigo** (agosto 2026): no quedan par,
tarjeta, "Birdie", penalizaciones, copa, bandera, ni zonas calle/rough/green.
La meta es `mapa.llego()`: subirse a la caja de la camioneta. Los nombres son
los del juego real -`salida`, `meta`, `nivel`, `impulso`, `piche`-, no los de
golf. Lo que se conservo porque funciona: el impulso con barra, la dispersion,
el timon en el aire, el salto, la conduccion, la stamina, la basura, la jaula y
la intro.

**Lo que falta para que sea un juego esta en `AUDITORIA.md`**, en orden: el
segundo mapa (hoy hay uno solo y al llegar se reinicia), pantalla de llegada,
guardado, pausa, controles en pantalla, audio y la animacion del piche.

## Como verificar

Antes de decir que algo funciona, correr esto. Levanta el juego entero y ejecuta
`_self_check()` de `juego.gd`, que son ~15 asserts sobre el mapa, la jaula, el
piche y la intro:

```
"/c/Users/ivanu/Downloads/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe" \
  --headless --path . res://escenas/Juego.tscn --quit-after 4500
```

La escena principal del proyecto es `Menu.tscn`, que no carga nada: sin nombrar
`Juego.tscn` la corrida se queda en la portada y no ejecuta un solo assert.

Los asserts imprimen numeros (`el piche queda en x=0.81`), no solo pasan o fallan.
Si tocas algo que ya tiene assert, el numero tiene que seguir teniendo sentido.

Para probar un mapa sin jugarse los anteriores, `-- --mapa N` (0 es el primero):

```
"/c/Users/.../Godot_v4.6.3-stable_win64.exe"   --headless --path . res://escenas/Juego.tscn --quit-after 4000 -- --mapa 1
```

`_self_check()` es lo que NO depende del mapa. Lo de cada mapa esta en
`_check_mapa()`, que corre en CADA carga; las pruebas de la jaula fisica y del
casco del barco son del muelle y estan detras de `mapa.tiene_jaula()`.

**Un mapa nuevo es un glb con dos mallas por nombre: `CAMIONETA` (la meta) y,
si arranca encerrado, `jaula` (la salida, con su cara +X hacia donde tiene que
salir).** Sin jaula el piche arranca de pie en el `Marker3D` `Salida` y no hay
cinematica. Para ver que trae un glb antes de armarle la escena:
`--script res://herramientas/ver_glb.gd -- res://ruta.glb`.

Poder moverse despues de caer en una pendiente tiene su propio probador,
porque el self-check corre en el muelle y ahi no hay laderas:

```
... --headless --path . --script res://herramientas/probar_pendiente.gd
```

Da dos columnas y hay que leer las dos. SIN MANDO puede ser largo -es el rebote
del impulso, y esta bien que ruede-. CON MANDO tiene que ser decimas de
segundo: es lo que tarda en obedecer desde que apretas W. Si esa sube, el
jugador volvio a quedar esperando a que la fisica termine, que es el bug viejo
de golf.

Para animaciones, encuadres y colocacion hay que MIRAR, con el MCP de Godot
(`scene_play` + `runtime_screenshot`). Si algo es demasiado rapido para
capturarlo, bajar `Engine.time_scale` un rato: las proporciones entre lo que se
mueve no cambian.

## Reglas

**IMPORTANTE: no hacer `git commit` ni `git push` sin que el usuario lo pida.**
Terminar, verificar y parar. Ofrecerlo en una linea, no ejecutarlo.

**IMPORTANTE: un numero que se tunea va en `@export`, no en `const`.**
Si para probar otro valor hay que editar el script y volver a correr, ese numero
esta en el lugar equivocado: `@export_range(min, max, paso)` lo pone en el
Inspector, con deslizador y en caliente mientras corre. `const` queda solo para
lo que NO se tunea: rutas `res://`, nombres de malla, tablas de datos. El proyecto
tenia 2158 lineas de GDScript y cero `@export`; `impulso.gd` ya migro sus 27
numeros de feel, `mapa.gd` y `juego.gd` todavia no.

**IMPORTANTE: las escenas se autoran en el editor, no se construyen en `_ready`.**
Lo que va en el editor: composicion fija (camara, luz, entorno, UI, modelos
colocados unos sobre otros). Lo que va en codigo: solo lo procedural, que
depende de datos que no existen hasta correr (altura del terreno, sembrado
aleatorio). Costo aprendido: colocar la jaula en la caja de la camioneta fueron
cuatro rondas de constante -> correr -> captura -> corregir; en el editor eran
diez segundos. Y la salida estuvo clavada como `Vector2(1020.0, 821.3)` con ocho
lineas de comentario explicando como se palpo a rayos: hoy es un `Marker3D` que
se arrastra.

El proyecto ya paso por esa migracion: camara, sol, entorno, UI, portada, el
piche y el mapa estan en `.tscn`. Los `.new()` que quedan son legitimos
(`SurfaceTool`, `ImmediateMesh`, materiales, particulas, `InputEventKey`). Si
vuelve a aparecer un `.new()` de un nodo que existe siempre, esta mal.

Cuatro skills, en orden de uso: `/godot-mcp` (que sabe hacer el editor: 332
comandos, leerlo ANTES de escribir GDScript para algo que se ve o se siente),
`/godot-mecanicas` (que esta mal y que no en la fisica, los estados y la
camara de ESTE juego), `/godot-escena` (autorar), `/godot-verificar`
(comprobar) y `/godot-refs` (14 guias genericas de Godot para funcionalidad
que el proyecto todavia no tiene; donde choquen, gana `/godot-mecanicas`).

No verificar solo con asserts. Los asserts confirman que el codigo CORRE, no que
se VEA. Ya pasaron todos mientras la pantalla estaba entera roja y la camara
dentro de un arbol.

Una escena no depende de nada de fuera: se monta sola y avisa con senales. Nada
de `get_node("..")` al padre. Senales hacia arriba, llamadas hacia abajo.
(Ver `escenas/Jaula.tscn` + `scripts/jaula.gd`.)

Toda logica no trivial deja un assert en `_self_check()`. Y el assert tiene que
poder fallar: si empujas el piche a mano mientras `_conducir()` lo congela cada
tick, se queda en 0.00 y el assert de "no se sale" pasa por no moverse nunca.
Conducir por el camino real (poner `impulso.mira` y apretar la tecla con
`Input.parse_input_event`), no simular por atajos.

Marcar los atajos deliberados con un comentario `ponytail:` que nombre el techo
y por donde se sube.

## Trampas de este proyecto que ya costaron caro

**Los rayos de altura paran en la PRIMERA colision, que bajo un arbol es la copa
y no el suelo.** Costo el area pintada convertida en un telon rojo delante de la
camara y la camioneta trepando follaje. Usar `mapa.altura_suelo()`, que pela capas hasta el suelo, o
`mapa.altura_terreno(x, z, techo)` con el techo justo encima de lo que buscas.

**`Transform3D * AABB` REALINEA la caja con los ejes.** Encadenar dos (ir a
mundo y volver) la infla. Con la jaula girada hacia la meta, una jaula de 2 m
salia de 3.13 y una puerta de 12 cm salia de 63: los muros quedaban lejos y el
hueco era un porton. Componer transformadas locales, una sola conversion.

**El AABB de una malla con esqueleto no dice donde se dibuja.** Esta en bind
pose y Godot lo infla (aqui, 160 m de alto). Para colocar un personaje, anclar
por el hueso raiz: `esqueleto.global_transform * esqueleto.get_bone_global_pose(0)`.

**`position` no lleva la escala del nodo.** Si recentras con un desplazamiento y
despues escalas, el desplazamiento queda sin escalar. Multiplicar por la escala.

**La colision de una malla de barrotes es un colador.** El piche mide 4 cm y se
cuela entre los barrotes o por debajo de una puerta que arranca a 19 cm del
suelo. Para encerrar de verdad hacen falta cajas macizas (`_murar()`), no
`create_trimesh_collision()`.

**A 26 m/s la colision la resuelve el CCD y `get_colliding_bodies()` no la
reporta.** Para detectar impactos rapidos, geometria (cruce de un plano), no
contactos.

**Los tweens corren en tiempo de juego y `Engine.time_scale` los escala.** Dos
cosas en camara lenta pueden seguir estando desincronizadas entre si: la puerta
tardaba 0.5 s mientras el piche recorria 13 m. Y los `create_timer` que tienen
que durar en tiempo REAL necesitan `ignore_time_scale`.

**Al forzar la velocidad de un cuerpo por guion, forzar el vector ENTERO.**
Forzando solo la horizontal, la gravedad se come el ascenso: el impulso pasaba
de 26 m a 6.

**No todo numero que imprime un assert sirve como senal de regresion.** El del
primer impulso (`el piche sale a X m de la jaula`) oscila entre 1.6 y 18.7 con el
mismo codigo: la dispersion decide si el piche cruza el hueco de la puerta o
rebota en el marco. Antes de perseguir una regresion por un numero, correr la
misma version dos o tres veces.

**Las banderas que se ponen en `_process` se quedan pegadas si algo corta antes
con un `return`.** El area quedo blanca tapando la camioneta y la linea de mira
cruzando el encuadre, las dos por eso.

## Mapa del codigo

- `escenas/Juego.tscn` — la escena del juego: `Camara`, `Sol`, `Entorno`, `UI`,
  `Portada`, `Impulso`, y las instancias `Mapa` y `Piche`. Aca se tunea lo visual.
- `escenas/mapas/Muelle.tscn` — el glb del muelle ya recentrado, mas el `Marker3D`
  `Salida`. La meta no es un marcador: es la malla `CAMIONETA` del propio glb.
- `escenas/Piche.tscn` — el cuerpo rigido, su esfera de colision, el modelo y la
  estela.
- `escenas/piezas/` — `Animal.tscn`, placeholder pensado para cambiarse por el
  modelo bueno arrastrandolo encima.
- `escenas/Menu.tscn` + `scripts/menu.gd` — la portada. JUGAR y TIENDA cambian
  de escena; AJUSTES todavia avisa que no.
- `escenas/Tienda.tscn` + `scripts/tienda.gd` — la tienda de skins. Las ocho
  cartas son `AtlasTexture` recortando `ui/skins_lamina.png` (4x2 de 384x512):
  cambiar el arte es reemplazar UN png, y mover una carta es tocar su `region`.
  Comprar todavia no hace nada.
- `herramientas/ver_ui.gd` — abre una pantalla con render y guarda captura, para
  mirar UI sin el MCP.
- `scripts/juego.gd` — reglas, intro, jaula, cinematica. Es el monolito:
  ~880 lineas. Lo que salga de aca deberia salir como escena.
- `scripts/mapa.gd` — el mapa, alturas por rayo, la meta y el sembrado de
  fauna y basura.
- `scripts/impulso.gd` — apuntado, potencia, mando y camara.
- `scripts/util.gd` — aerodinamica y mallas provisionales.
- `scripts/jaula.gd` + `escenas/Jaula.tscn` — la jaula de salida, con su puerta.
