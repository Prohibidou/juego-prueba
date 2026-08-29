---
name: godot-verificar
description: Verificar un cambio en el juego antes de decir que funciona: asserts en _self_check con la corrida headless, y captura de pantalla con scene_play + runtime_screenshot para lo que hay que MIRAR. Usar al terminar cualquier cambio de logica, animacion, encuadre o colocacion.
---

# Verificar

Dos pistas, ninguna reemplaza a la otra. Los asserts confirman que el codigo
CORRE; la captura, que se VE. En este proyecto pasaron los 15 asserts con la
pantalla entera roja y la camara dentro de un arbol.

## Pista A — que corre (siempre)

```
"/c/Users/ivanu/Downloads/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe" \
  --headless --path . res://escenas/Juego.tscn --quit-after 4500
```

Hay que nombrar la escena: la principal del proyecto es `Menu.tscn`, que no
carga nada, y sin eso la corrida no ejecuta un solo assert.

Levanta el juego y ejecuta `_self_check()` de `juego.gd`. Los asserts imprimen
numeros (`la bola queda en x=0.81`), no solo pasan o fallan: si tocaste algo con
assert, el numero tiene que seguir teniendo sentido.

Toda logica no trivial deja un assert nuevo ahi. Y el assert **tiene que poder
fallar**: si empujas la bola a mano mientras `_conducir()` la congela cada tick,
se queda en 0.00 y "no se sale" pasa por no moverse nunca. Conducir por el
camino real: poner `golpe.mira` y apretar la tecla con
`Input.parse_input_event`, nunca simular por atajos.

## Pista B — que se ve (animacion, encuadre, colocacion, materiales)

1. `scene_play` (`mode` = main, current, o una ruta res://).
2. `runtime_screenshot` y MIRAR la imagen. Tambien sirve headless.
3. Si algo pasa demasiado rapido, bajar `Engine.time_scale` con `runtime_eval`
   un rato: las proporciones entre lo que se mueve no cambian. Ojo que los
   tweens tambien se escalan, y los `create_timer` que deben durar en tiempo
   REAL necesitan `ignore_time_scale`.
4. `runtime_errors` + `editor_errors` antes de cerrar con `scene_stop`.
5. Para inspeccionar sin adivinar: `runtime_tree`, `runtime_get`,
   `runtime_batch_get`.

## Antes de decir "funciona"

- Corrio la pista A y los numeros tienen sentido.
- Si el cambio se ve, hay una captura mirada, no solo asserts verdes.
- Los atajos deliberados quedaron marcados con un comentario `ponytail:` que
  nombra el techo y por donde se sube.
- No commitear ni pushear: ofrecerlo en una linea y parar.
