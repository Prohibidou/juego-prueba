---
name: godot-escena
description: Autorar escenas 3D de Godot desde el editor con el MCP en vez de construir nodos en _ready. Usar al agregar, instanciar, colocar, orientar o encuadrar cualquier cosa que se ve (modelos, camaras, luces, UI, colisiones), y al sacar algo del monolito juego.gd a su propia escena.
---

# Autorar escenas con el MCP de Godot

Regla unica: **la composicion fija va en el .tscn, hecha con el MCP; en codigo
solo lo que depende de datos que no existen hasta correr** (altura del terreno,
posicion del tee, sembrado aleatorio). Si estas por escribir `.new()` para algo
que siempre esta ahi, pará: va como nodo en la escena.

## El ciclo

1. **Resolver** — `authoring_resolve` con el nombre aproximado. Da la ruta real
   del nodo/escena/recurso y avisa si hay ambiguedad. Nunca inventes rutas.
2. **Abrir** — `scene_open` + `scene_tree` para ver contra que estas trabajando.
3. **Checkpoint** — `authoring_checkpoint capture` antes de una tanda de
   movimientos. Al final, `diff` responde "que moví realmente".
4. **Crear** — `authoring_ensure` (get-or-create idempotente, se puede repetir
   sin duplicar) o `scene_instance` para meter una escena hija. Un modelo que se
   reusa es una escena propia, no un nodo suelto.
5. **Colocar** — anclar UNA pieza, leer sus bounds REALES (`node_get`
   global_position, `spatial_bounds`) y derivar las vecinas de ahi. Para asentar
   en el suelo `spatial_place_on` con `samples>=1` (rayos, necesita colliders);
   para orientar, `spatial_look_at`. No calcules alturas ni Euler a mano.
6. **Guardar y chequear** — `scene_save`, despues `editor_errors` y
   `scene_validate`.
7. **Mirar** — nada esta hecho hasta verlo: seguir con `/godot-verificar`.

## Trampas que ya costaron caro aca

- Los rayos paran en la PRIMERA colision: bajo un arbol es la copa, no el suelo.
  En codigo usar `campo.altura_suelo()`; con el MCP, `spatial_place_on` con
  samples y mirar el resultado.
- `Transform3D * AABB` REALINEA la caja: encadenar dos la infla (una jaula de
  2 m salia 3.13). Componer transformadas locales, una sola conversion.
- El AABB de una malla con esqueleto miente (aca, 160 m de alto). Anclar por el
  hueso raiz: `esqueleto.global_transform * esqueleto.get_bone_global_pose(0)`.
- `position` no lleva la escala del nodo: si recentras y despues escalas,
  multiplica el desplazamiento por la escala.
- Colision de barrotes = colador. Para encerrar algo de 4 cm hacen falta cajas
  macizas, no `create_trimesh_collision()`.

## Migrar un bloque de codigo a la escena

Sintoma de que hace falta: no podes tocar un numero (fov, energia del sol,
posicion del HUD) sin editar codigo y volver a correr. Eso es exactamente lo
que el editor resuelve gratis.

Como decidir: **si el nodo existe SIEMPRE y con las mismas propiedades, va al
.tscn.** Si depende de un dato que no existe hasta correr, va en codigo — pero
el MOLDE va como escena y el codigo solo la instancia y la coloca.

Receta, cuatro pasos, sin desviarse:

1. Con el MCP, recrear los nodos en la escena destino (`authoring_ensure` /
   `scene_instance`) copiando LITERAL las propiedades del bloque `.new()`, y
   nombrando cada nodo como la variable del script (`camara` -> `Camara`).
2. En el script: `var camara: Camera3D` pasa a
   `@onready var camara: Camera3D = $Camara`, y el bloque de construccion se
   borra. Nada mas: no aprovechar para refactorizar, o no vas a saber cual de
   los dos cambios rompio la captura.
3. `/godot-verificar`: si la captura sale igual que antes, la migracion esta bien.
4. Lo que quede en codigo por procedural, sacarle los numeros a `@export` /
   `@export_range`. Ahi el Inspector empieza a servir aunque el nodo lo cree
   el codigo.

Dos cosas mas que solo se pueden hacer en el editor:

- **Hornear lo caro una vez.** Colision generada en `_ready` (V-HACD,
  trimesh) se paga en CADA arranque. Generada en el editor y guardada en el
  .tscn, se paga una vez y ademas podes corregir a mano un casco que salio mal.
- **Reemplazar placeholders.** Una capsula hecha con `.new()` no se puede
  cambiar por el modelo bueno arrastrandolo; una `Placeholder.tscn` si.

Para tunear en caliente mientras corre: `runtime_set` sobre el nodo y
`debug_reload_scripts` para empujar el script editado a la corrida.

## Sacar algo del monolito

`escenas/Jaula.tscn` + `scripts/jaula.gd` es el modelo a copiar: se monta solo,
no hace `get_node("..")`, avisa con señales hacia arriba y recibe llamadas hacia
abajo. Mover primero los nodos al .tscn con el MCP, despues el script, y
reemplazar cada dependencia al padre por una señal.
