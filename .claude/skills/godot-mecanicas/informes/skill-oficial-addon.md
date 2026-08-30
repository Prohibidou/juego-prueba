# El repo del addon y su agent skill oficial - hallazgo

## 1. El repositorio: ENCONTRADO

**https://github.com/regiellis/godot-mcp-go**

Descripcion del repo: "Give AI agents the complete Godot development loop:
discover, build, play, observe, debug, fix, and verify from a CLI or MCP client."
El `plugin.cfg` local dice "Give an AI agent the Godot workflow: build, play,
observe, debug, fix, and verify from the terminal or MCP" - misma frase.

### Como se confirmo que es ESTE y no otro de los muchos "godot mcp"

- El `LICENSE` del addon instalado dice `Copyright (c) 2026 Regi Ellis`. El campo
  `author="bynine"` del `plugin.cfg` es un alias; el usuario de GitHub `Bynine`
  (10 repos, Java y romhacks de Pokemon) NO es el autor de esto: no tiene ningun
  repo de Godot. El repo esta bajo la cuenta **regiellis**.
- Coinciden los numeros que lo identifican: **332 comandos**, **50 grupos** (la
  nuestra dice 49 familias), doble servidor **WS 9080-9095 + HTTP 9100-9115** con
  `POST /mcp`, y las familias raras `doc` / `wfc` / `pcg` / `scatter` /
  `authoring` / `spatial`.
- La version publicada mas nueva es **v0.9.1 (2026-08-27)**, exactamente la que
  tenemos instalada.
- El addon es GDScript pero el CLI es Go, de ahi el sufijo `-go` del repo. El
  nombre del repo no contiene "cli", por eso no aparecia buscando el nombre del
  plugin ni la descripcion.

Repo hermano del mismo autor: **https://github.com/regiellis/godot-reversi** -
"A complete Reversi game for Godot 4.7, built end to end by AI agents driving
godot-mcp against a live editor." Sirve como ejemplo de uso real.

Descartados explicitamente (OTRO addon, no el nuestro): tugcantopaloglu/godot-mcp
(157 tools), IvanMurzak/Godot-MCP (C#), hybridindie/godot-mcp, youichi-uda/
godot-mcp-pro (162 tools, pago), Coding-Solo/godot-mcp, mkdevkit/godot-mcp,
ee0pdt/Godot-MCP, satelliteoflove/godot-mcp, hi-godot/godot-ai.

## 2. Los releases: la skill oficial EXISTE

Release **v0.9.1**, publicado 2026-08-27. Assets:

| Asset | Tamano | Que es |
|---|---|---|
| `godot-mcp-addon_0.9.1.zip` | 844.9 KB | el addon (lo que ya tenemos) |
| `godot-mcp-skill_0.9.1.zip` | **212.4 KB** | **la agent skill oficial** |
| `godot-mcp_0.9.1_windows_amd64.zip` | 8.8 MB | el CLI (Go) para Windows |
| + darwin/linux, amd64/arm64 | ~8 MB c/u | el CLI para el resto |

La skill tambien esta en el arbol del repo, legible sin bajar nada:
`https://github.com/regiellis/godot-mcp-go/tree/main/skills/godot-mcp`

**Instalacion**: descomprimir el zip del release (o copiar `skills/godot-mcp/`)
dentro de `.claude/skills/`. Ojo: el directorio se llama IGUAL que el nuestro
(`godot-mcp`), asi que copiarlo encima PISA nuestra skill escrita a mano.

**Version frente al addon instalado**: la misma, 0.9.1. No estamos atrasados.

### Que trae la skill (31 archivos)

- `SKILL.md` - 47.275 bytes (la nuestra: ~117 lineas, ~5 KB).
- 30 documentos de referencia, ~500 KB en total. Los mas grandes:
  `level-design.md` (58 KB), `game-patterns.md` (33 KB), `game-trailers.md`
  (29 KB), `shipping-export.md` (20 KB), `porting-godot-versions.md` (20 KB),
  `character-3d.md` (18 KB), `narrative-game-patterns.md` (18 KB),
  `multiplayer-patterns.md` (16 KB), `menus-settings.md` (16 KB),
  `audio-music.md` (15 KB), `shaders-vfx.md` (15 KB), `environment-art.md`
  (15 KB), `save-systems.md` (15 KB), `deckbuilder-patterns.md` (13 KB),
  `in-game-docs.md` (11 KB), `ai-steering.md` (11 KB), `tile-constraint.md`
  (10 KB), `gdscript-architecture.md` (10 KB), `platformer-2d.md` (9,6 KB),
  `unreal-import-cleanup.md` (9 KB), `topdown-2d.md` (8,8 KB),
  `ui-polish-2d.md` (8,6 KB), `project-structure.md` (7,8 KB),
  `csharp-godot.md` (7,8 KB), `mobile-touch.md` (7,4 KB),
  `gdscript-style.md` (7 KB), `run-based-games.md` (6,4 KB),
  `lighting-2d.md` (6,3 KB), `event-deck-games.md` (5,8 KB),
  `rhythm-games.md` (4,2 KB).

### El contenido del SKILL.md oficial, en resumen

- **Prerequisitos**: el editor tiene que estar ABIERTO con el addon activo;
  `godot-mcp status` da `running` / `starting` / `crashed` / `closed` y un
  `project_match` para no manejar el editor equivocado.
- **La regla de oro: descubrir y despues manejar.** Textual: "Your training may
  predate the engine you are driving. Do not guess whether a class, property, or
  method exists. Ask the live engine." Con `engine search`, `engine class-info`,
  `engine classes --inherits`, `engine defaults`, `engine docs`,
  `engine doc-search`. Y cierra: "When the running engine and this guidance
  disagree, the live engine wins."
- **La regla espacial: anclar, releer, verificar; nunca colocar a ciegas.**
  Textual: "You cannot reliably perceive 3D from one perspective screenshot, and
  you are bad at absolute-coordinate 3D math, so never position dependent objects
  with parallel absolute coordinates." Anclar a geometria ya realizada, encadenar
  lecturas de `spatial bounds`, asentar con `place_on` o `raycast`, orientar con
  `look_at`, y VERIFICAR releyendo bounds, no por captura. Recuerda las
  convenciones: +Y arriba, -Z adelante, metros; en 2D +Y abajo, pixeles.
- **Composicion, no monolitos**: una escena por "cosa", capacidades como nodos
  hijos, scripts chicos en el nodo que manda, desacoplar por senales, datos por
  inspector y no hardcodeados, `@export` en vez de `get_node("../../X")`.
- **Convenciones del CLI**: flags globales antes del grupo, kebab o snake
  indistinto, formatos de valor (`"Vector3(1, 2, 3)"`, `"#ff0000"`, arrays
  empaquetados como array JSON de literales), salida JSON, rutas de nodo
  relativas a la raiz de la escena.
- **Flujos**: explorar antes de cambiar; armar una escena 2D; scripts
  (`create` / `edit` / `validate` / `symbols` / `lint`, con 17 reglas de estilo);
  bucle de playtest (`scene play` -> `runtime tree` -> `input action` ->
  `runtime get` -> `runtime screenshot` -> `scene stop`); escenarios guionados
  con `test run-scenario` + `test report`.
- **Trampas**: preferir propiedades de inspector a codigo; nunca editar
  `project.godot` a mano (usar `project set-setting`); `editor reload` tras crear
  o editar scripts; en `runtime.eval` no anidar funciones y devolver con
  `emit(v)`; un juego frenado en un breakpoint NO responde y cada llamada
  `runtime.*` se come su timeout entero (leer con `debug state` y despues
  `debug resume`); preferir `input action` a `input key`; en `test run-scenario`
  mantener una accion apretada exige `"auto_release": false`, si no se suelta
  sola y el personaje se mueve una fraccion de lo esperado; `scene save` despues
  de editar; un nodo dentro de una escena instanciada es de solo lectura hasta
  `node set-editable-instance`.
- Verificacion en 5 pasos, con el paso 3 subrayado: **releer el resultado**.

## 3. Documentacion mas alla del README de 45 lineas: SI, y bastante

- El README del REPO (no el del addon) tiene **31.343 bytes**. Ahi esta el
  desglose de 332 comandos en 50 grupos, y el dato de que el modo typed del MCP
  gasta ~52.000 tokens de esquemas, colapsables a una sola herramienta generica
  de ~470 tokens con `--typed=false`.
- **`CHANGELOG.md`: 97.615 bytes.** Es la fuente mas detallada del proyecto.
- `INSTALL.md` (9,5 KB) y `SECURITY.md` (4,5 KB).
- Sitio de documentacion: **https://regiellis.github.io/godot-mcp-go/** con
  secciones Docs, Commands (referencia de comandos), Quickstart, Installation y
  Samples.
- `samples/` en el repo, y el juego completo `godot-reversi` como ejemplo.
- No hay wiki de GitHub; la doc vive en `website/` y en el sitio publicado.
- **Requisitos declarados: Godot 4.7+**, soportado 4.3-4.8 (4.3 en beta),
  Go 1.26+. Nuestra nota de que "anda igual en 4.6.3" sigue siendo un hallazgo
  nuestro, no algo que ellos prometan.
- Instalacion oficial del addon: `godot-mcp install --project <ruta> --enable`,
  o `godot-mcp create --path ./mygame --install --enable` para arrancar de cero.

## 4. Contra nuestra `.claude/skills/godot-mcp/SKILL.md`

### En que se diferencian

| | La nuestra (~117 lineas) | La oficial (47 KB + 30 refs) |
|---|---|---|
| Interfaz | herramientas MCP `familia_comando` (`spatial_place_on`) | CLI `godot-mcp <grupo> <comando> --flags` |
| Idioma y tono | castellano, para ESTE juego | ingles, generico |
| Que cubre | mapa de las 49 familias, una linea por familia | 5 reglas de trabajo + flujos + trampas + 30 guias |
| Puertos y version | verificado aca: 9100, 332 comandos, anda en 4.6.3 | 9080/9100 genericos, pide 4.7+ |
| Trampas | las nuestras (rayos que paran en la copa, AABB con esqueleto, jaula colador) | las del addon (breakpoint que come timeouts, `auto_release`, `editor reload`) |

Lo que la oficial tiene y nosotros NO: la regla de oro de descubrir contra el
motor vivo antes de escribir una firma de memoria; la regla espacial de anclar y
releer bounds en vez de confiar en una captura; el detalle de `auto_release` en
escenarios; el aviso del breakpoint; y sobre todo las 30 guias tematicas.

Lo que NOSOTROS tenemos y la oficial no: los nombres de herramienta MCP tal como
los ve el agente aca, el puerto real comprobado, el dato de que corre en 4.6.3,
y la tabla de decision "comando MCP vs GDScript" que es la regla central de
nuestro CLAUDE.md.

### Recomendacion: FUSIONAR, no reemplazar

Reemplazar seria un retroceso: la skill oficial esta escrita para el CLI de Go,
que aca NO esta instalado (usamos el endpoint HTTP directo). Un agente que la
lea al pie de la letra va a tipear `godot-mcp scene tree` en una terminal donde
ese binario no existe.

Plan sugerido:

1. Dejar `.claude/skills/godot-mcp/SKILL.md` como esta y agregarle las cuatro
   reglas transversales de la oficial, traducidas y pasadas a nombres de
   herramienta MCP: descubrir con `engine_search` / `engine_class_info` antes de
   escribir una firma de memoria; anclar y releer `spatial_bounds` en vez de
   confiar en la captura; `editor_reload` tras crear scripts; y que un breakpoint
   activo hace que cada `runtime_*` se coma su timeout.
2. Copiar SOLO las guias de referencia que sirven a este juego, en una carpeta
   aparte (por ejemplo `.claude/skills/godot-refs/`), sin pisar nuestro
   `SKILL.md`: `character-3d.md` (el piche), `ai-steering.md`, `level-design.md`,
   `environment-art.md`, `in-game-docs.md` (los `doc_gym` / `doc_zoo` /
   `doc_museum` que nuestra skill ya menciona sin saber usarlos),
   `gdscript-style.md`, `gdscript-architecture.md` y `project-structure.md`
   (estos dos para partir `juego.gd`). Ignorar las de deckbuilder, ritmo,
   narrativa, multijugador, C#, movil, trailers y export, que no aplican.
3. Instalar el CLI SOLO si se quiere manejar Godot desde la terminal; para lo que
   hacemos hoy el endpoint HTTP alcanza, y el README del addon lo dice.

## Fuentes

- https://github.com/regiellis/godot-mcp-go
- https://github.com/regiellis/godot-mcp-go/releases (v0.9.1, 2026-08-27)
- https://github.com/regiellis/godot-mcp-go/tree/main/skills/godot-mcp
- https://regiellis.github.io/godot-mcp-go/
- https://github.com/regiellis/godot-reversi
