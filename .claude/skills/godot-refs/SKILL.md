---
name: godot-refs
description: Guias de referencia de Godot 4 sobre como se hacen las cosas -controlador 3D, patrones de juego, diseno de nivel, arte de entorno, audio, guardado, shaders, menus, estilo y arquitectura de GDScript-. Consultar la guia puntual al empezar una funcionalidad que el proyecto todavia no tiene. Son genericas: donde choquen con /godot-mecanicas, gana /godot-mecanicas.
---

# Guias de referencia

14 guias bajadas de `regiellis/godot-mcp-go` (el repo del addon MCP que este
proyecto usa), en `guias/`. Son buenas y estan verificadas contra el motor,
pero son **genericas para cualquier juego**.

## Regla de precedencia, importante

**Donde una guia choque con `/godot-mecanicas`, gana `/godot-mecanicas`.**
Esas conclusiones salieron de medir ESTE codigo, no de un consejo general.
El choque concreto que ya existe:

- `guias/character-3d.md` ensena `CharacterBody3D`. **Aca el piche es
  `RigidBody3D` y esta bien asi**: el juego es balistica real -drag, lift por
  spin, rebote, damping por zona- y `move_and_slide()` no trae nada de eso.
  No "arreglar" el nodo. De esa guia sirve el feel del salto (coyote time,
  buffer, corte), no la eleccion de cuerpo.
- `guias/game-patterns.md` tira a 2D en varios ejemplos (`CharacterBody2D`,
  `Area2D`). Los patrones valen; los nodos hay que traducirlos a 3D.
- Cualquier consejo de `Area3D` para disparadores: aca vale **solo para lo
  lento**. A 26 m/s el piche avanza 43 cm por tick y atraviesa una Area3D fina
  entera; para eso va geometria, como ya hace `jaula.gd`.

## Traduccion de comandos

Dos guias -`in-game-docs.md` y `level-design.md`- escriben los comandos como el
CLI de Go (`godot-mcp scene tree`). **Ese binario no esta instalado aca.**
Traducir a la herramienta MCP por HTTP: `scene tree` -> `scene_tree`,
`engine class-info` -> `engine_class_info`. Ver `/godot-mcp`.

## Cual leer

| Para | Guia |
|---|---|
| Salto, feel, rigs de camara en 3D | `character-3d.md` |
| Maquina de estados, pickups, HUD por señales, grupos, spawn | `game-patterns.md` |
| Diseno de nivel y metricas (la mas grande, 58 KB) | `level-design.md` |
| Componer el escenario, luz, niebla, props | `environment-art.md` |
| Audio -el proyecto hoy no tiene NADA- | `audio-music.md` |
| Guardar y progresion | `save-systems.md` |
| Menus, ajustes, pantallas | `menus-settings.md` |
| Particulas, shaders, VFX | `shaders-vfx.md` |
| Fauna que se mueve sola | `ai-steering.md` |
| Como escribir el GDScript | `gdscript-style.md`, `gdscript-architecture.md` |
| Donde va cada archivo | `project-structure.md` |
| Los `doc_gym` / `doc_zoo` / `doc_museum` del MCP | `in-game-docs.md` |
| Arrastre tactil, el `TIMON_TACTIL` de golpe.gd | `mobile-touch.md` |

No se bajaron las de 2D puro (platformer, topdown, tile, ui-polish,
lighting-2d), deckbuilder, event-deck, ritmo, run-based, multijugador, C#,
narrativa, tráilers, export ni unreal-cleanup. Si alguna hace falta, esta en
`skills/godot-mcp/` del mismo repo.
