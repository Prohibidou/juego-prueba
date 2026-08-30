---
name: godot-mcp
description: Mapa de los 332 comandos del MCP de Godot, por familia. Leer ANTES de escribir GDScript para cualquier cosa que se vea, se sienta o se coloque -animacion, fisica, material, particulas, navegacion, esqueleto, shader, UI, luces, audio, input- para comprobar si el editor ya lo hace. Usar tambien al no saber el nombre exacto de un comando.
---

# Que sabe hacer el MCP

El addon expone **332 comandos en 49 familias**. El habito de resolver todo en
GDScript viene de no conocerlos: casi todo lo que se estaba escribiendo a mano
-colocar, orientar, materiales, luces, colisiones, animacion, navegacion- ya es
un comando.

Nombre de la herramienta = `familia_comando`: la familia `spatial` con el
comando `place_on` es la herramienta `spatial_place_on`.

**Antes de escribir codigo, buscar aca.** Si hay comando, el cambio queda
guardado en el `.tscn` y se puede corregir a mano despues; si lo hace el codigo
en `_ready`, no.

## La regla de decision

| Lo que quiero | Donde va |
|---|---|
| Existe siempre, mismas propiedades | Comando MCP -> queda en el `.tscn` |
| Depende de un dato que no existe hasta correr | GDScript, pero el molde es escena |
| Un numero que voy a tunear | `@export_range`, nunca `const` |

## Las familias

**Autorar y colocar** — el nucleo del trabajo diario.
- `authoring`: resolve ensure checkpoint — `resolve` da la ruta real de un nodo por nombre aproximado (nunca inventar rutas), `ensure` es get-or-create idempotente, `checkpoint` captura y diffea "que movi realmente".
- `scene`: open save create close tree content instance delete validate play stop
- `node`: add get set call delete duplicate rename move connect disconnect add_resource find_in_group get_groups set_groups get_meta set_meta set_anchor set_editable_instance
- `spatial`: place_on look_at align snap distribute bounds raycast relate find_in_region lint — `place_on` asienta en el suelo por rayo, `bounds` da la caja REAL. No calcular alturas ni Euler a mano.
- `batch`: add_nodes set_property cross_scene_set_property find_nodes_by_type find_node_references find_signal_connections scene_dependencies — varios nodos de una.

**Armar cosas 3D** — antes de hacer una malla con `SurfaceTool`.
- `scene3d`: add_mesh add_body add_gridmap set_material setup_camera setup_lighting setup_environment
- `mesh`: info deform_lattice · `csg`: add combine set_operation bake
- `material`: create apply set info · `shader`: create create_visual edit read set_param get_params assign_material global_add global_set global_list global_remove
- `lighting`: add set_gi set_sdfgi bake add_2d canvas_modulate emissive_2d glow_2d normal_map_2d occluder_2d
- `particles`: create apply_preset set_material set_color_gradient get_info

**Fisica y colisiones** — `setup_collision` antes que `create_trimesh_collision()` a mano.
- `physics`: setup_body setup_collision add_joint add_raycast set_layers get_layers get_collision_info
- `navigation`: setup_region setup_agent bake_mesh query_path add_link set_layers get_info
- `path`: create add_point add_follow sample get_points

**Animacion y personajes** — no hace falta tween a mano para todo.
- `animation`: create list add_track set_keyframe get_info remove
- `anim_tree`: create add_state add_transition set_parameter set_blend_tree_node set_blend_point remove_state remove_transition remove_blend_point get_structure
- `skeleton`: list_bones get_pose set_pose reset_pose add_bone add_attachment create_2d set_rest_2d skin_2d — `add_attachment` cuelga algo de un hueso sin pelear con el AABB.

**Interfaz y entrada**
- `ui`: add_control add_container set_sizing · `theme`: create setup_control set_color set_font_size set_constant set_stylebox get_info
- `input`: key click tap move action sequence · `input_map`: get_actions set_action
- `camera`: make_current set_2d set_attributes · `audio`: add_player add_bus set_bus add_bus_effect get_bus_layout get_info

**Correr, mirar y depurar** — la pista B de `/godot-verificar`.
- `runtime`: screenshot eval get set call tree batch_get errors find_by_script find_nearby find_ui click_text move_to navigate wait_for await_signal watch_signals monitor autoload capture_frames start_recording stop_recording replay
- `editor`: screenshot compare_screenshots errors log activity selection get_camera set_camera run_script reload reload_plugin clear_output signals
- `debug`: state frame pause resume step set_breakpoint remove_breakpoint breakpoints clear_breakpoints reload_scripts
- `test`: run_scenario assert_node_state assert_screen_text run_stress_test report
- `profiling`: monitors editor_performance · `stats`: snapshot reset

**Proyecto y recursos**
- `project`: info tree settings set_setting remove_setting search grep add_autoload remove_autoload plugins enable_plugin disable_plugin path_to_uid uid_to_path
- `script`: create attach edit read list list_open symbols validate lint
- `resource`: create read edit find info preview · `fs`: copy move delete mkdir
- `engine`: version classes class_info docs doc_search search singletons defaults script_classes commands — `engine_commands` lista los 332 en vivo; `engine_doc_search` es la doc de Godot sin salir de aca.
- `analysis`: scene_complexity script_references signal_flow circular_dependencies unused_resources project_statistics
- `import`: info set reimport · `export`: project list_presets info · `cleanup`: strip_junk fix_imports unreal_lights unreal_env

**Generacion** — sembrado y mapas, en vez de bucles de dado a mano.
- `scatter`: populate clear info · `pcg`: scatter sample relax
- `wfc`: solve_dual collapse rules_from_example match_pattern case_table set_corner stalberg_grid
- `gridmap`: create set_cell get_cell fill clear get_used_cells list_items meshlibrary_from_scene set_cell_variant
- `tilemap`: create set_cell get_cell fill_rect clear add_atlas_source add_scenes_source set_terrain get_used_cells get_info

**Menos usadas aca:** `scene2d` `multiplayer` `localization` `csharp` `android` `doc`.

## El MCP corre DENTRO del editor

Es HTTP en `127.0.0.1:9100/mcp`, servido por el addon. **Si Godot no esta abierto
con el proyecto, no conecta.** Un `ConnectionRefused` significa "abri el editor",
no "esto no se puede", y no es motivo para resolver en codigo lo que va en la
escena: es motivo para pedir que lo abran.

Comprobado en este proyecto (corrida `--headless --editor --quit`):

```
[MCP-HTTP] MCP endpoint listening on http://127.0.0.1:9100/mcp
[MCP] Server listening on ws://127.0.0.1:9080
[MCP] Registered 332 commands
```

- **El addon anda en Godot 4.6.3** aunque su README pida 4.7 o mas. No perder
  tiempo persiguiendo un problema de version: no lo hay.
- El puerto es el primero libre entre 9100 y 9115, y `.mcp.json` tiene clavado
  el 9100. Coinciden hoy. Si algun dia no conecta con el editor ABIERTO, el
  puerto real esta en `.godot/godot-mcp.json`, que solo existe mientras corre.
- **Toda mutacion del editor pasa por `UndoRedo`**: Ctrl+Z deshace lo que hizo
  el MCP. Autorar por MCP es reversible, no hace falta tenerle miedo.

## Extras del addon que valen la pena

- `doc_gym` arma un nivel de metricas -huecos para saltar, alturas de escalon,
  pendientes- para medir de verdad un controlador de personaje. Para un bicho
  de 4 cm que salta y se cuela entre barrotes, es exactamente la herramienta
  que faltaba: hoy eso se mide con asserts que imprimen numeros, y un gym se
  MIRA.
- `doc_note` deja notas espaciales (todo/bug/art) como `Marker3D` con metadata
  dentro de la escena; `doc_zoo` desparrama una carpeta de assets en una grilla
  etiquetada con referencias de escala; `doc_museum` arma pads de exhibicion.
- El repo del addon publica ademas un CLI y una **agent skill oficial** como
  descargas aparte de los releases. Vale buscarla antes de escribir skills a mano.
