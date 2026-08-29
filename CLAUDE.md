# Golfito / Piche: La Gran Fuga

Juego de historia en Godot 4.6: un piche (armadillo) se escapa y hay que
llevarlo hasta un punto. NO es un juego de golf. Escenario real por
fotogrametria. Codigo y comentarios en castellano, sin tildes ni enies en el
codigo; los textos de pantalla si llevan.

**Arrastra un pasado de golf y hay que ir sacandolo.** El proyecto empezo siendo
golf, asi que quedan par, tarjeta, "Birdie", penalizaciones por drop, y sobre
todo una copa de 5.4 cm de radio como meta -`campo.embocada()`-, que para
"llegar a un punto" es injugable. Lo que SI sirve tal cual: el impulso con
barra, la dispersion, el timon en el aire, el salto, la conduccion, la stamina,
la basura, los pateadores, la jaula y la intro. Lo que se llama "hoyo" en el
codigo es un nivel; lo que se llama "golpe", un impulso.

## Como verificar

Antes de decir que algo funciona, correr esto. Levanta el juego entero y ejecuta
`_self_check()` de `juego.gd`, que son ~15 asserts sobre el campo, la jaula, el
piche y la intro:

```
"/c/Users/ivanu/Downloads/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe" \
  --headless --path . --quit-after 4500
```

Los asserts imprimen numeros (`la bola queda en x=0.81`), no solo pasan o fallan.
Si tocas algo que ya tiene assert, el numero tiene que seguir teniendo sentido.

Para animaciones, encuadres y colocacion hay que MIRAR, con el MCP de Godot
(`scene_play` + `runtime_screenshot`). Si algo es demasiado rapido para
capturarlo, bajar `Engine.time_scale` un rato: las proporciones entre lo que se
mueve no cambian.

## Reglas

**IMPORTANTE: no hacer `git commit` ni `git push` sin que el usuario lo pida.**
Terminar, verificar y parar. Ofrecerlo en una linea, no ejecutarlo.

**IMPORTANTE: las escenas se autoran en el editor, no se construyen en `_ready`.**
Este proyecto arrastra el error contrario: 47 nodos creados con `.new()` y tres
`.tscn` que son cascaras vacias de un `Node3D` con un script. Eso cuesta caro:
no se puede arrastrar nada en el editor, el Inspector no sirve, los `@export` no
se pueden editar porque las instancias las crea el codigo, y F6 sobre una escena
no muestra nada. Colocar la jaula en la caja de la camioneta fueron cuatro
rondas de constante -> correr -> captura -> corregir; en el editor eran diez
segundos. Lo que va en el editor: composicion fija (camara, luz, entorno, UI,
modelos colocados unos sobre otros). Lo que va en codigo: solo lo procedural,
que depende de datos que no existen hasta correr (altura del terreno, posicion
del tee, sembrado aleatorio).

No verificar solo con asserts. Los asserts confirman que el codigo CORRE, no que
se VEA. En esta sesion pasaron todos mientras la pantalla estaba entera roja, la
camara dentro de un arbol y el pateador a 500 m de su propia area de deteccion.

Una escena no depende de nada de fuera: se monta sola y avisa con senales. Nada
de `get_node("..")` al padre. Senales hacia arriba, llamadas hacia abajo.
(Ver `scripts/pateador.gd`, que es el unico que ya lo cumple.)

Toda logica no trivial deja un assert en `_self_check()`. Y el assert tiene que
poder fallar: si empujas la bola a mano mientras `_conducir()` la congela cada
tick, se queda en 0.00 y el assert de "no se sale" pasa por no moverse nunca.
Conducir por el camino real (poner `golpe.mira` y apretar la tecla con
`Input.parse_input_event`), no simular por atajos.

Marcar los atajos deliberados con un comentario `ponytail:` que nombre el techo
y por donde se sube.

## Trampas de este proyecto que ya costaron caro

**Los rayos de altura paran en la PRIMERA colision, que bajo un arbol es la copa
y no el suelo.** Costo el area pintada convertida en un telon rojo delante de la
camara, la camioneta trepando follaje y los pateadores plantados a 15 m en el
aire. Usar `campo.altura_suelo()`, que pela capas hasta el suelo, o
`campo.altura_terreno(x, z, techo)` con el techo justo encima de lo que buscas.

**`Transform3D * AABB` REALINEA la caja con los ejes.** Encadenar dos (ir a
mundo y volver) la infla. Con la jaula girada hacia la bandera, una jaula de 2 m
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

**Las banderas que se ponen en `_process` se quedan pegadas si algo corta antes
con un `return`.** El area quedo blanca tapando la camioneta y la linea de mira
cruzando el encuadre, las dos por eso.

## Mapa del codigo

- `scripts/juego.gd` — reglas, marcador, intro, jaula, cinematica, area. Es el
  monolito: ~1400 lineas. Lo que salga de aca deberia salir como escena.
- `scripts/campo.gd` — el campo, alturas por rayo, zonas, y el sembrado de
  fauna, basura y pateadores.
- `scripts/golpe.gd` — apuntado, potencia, mando y camara.
- `scripts/util.gd` — aerodinamica y mallas provisionales.
- `scripts/pateador.gd` + `escenas/Pateador.tscn` — el unico modulo con escena
  propia y sin dependencias.
