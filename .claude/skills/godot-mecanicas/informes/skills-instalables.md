# Skills / plugins instalables para Claude Code — gamedev y Godot

Investigacion web, agosto 2026. Todas las URLs se verificaron con fetch real
(200 y contenido leido). Lo que no pude verificar esta marcado como tal.

## Estado del ecosistema (honesto)

- **No hay NADA de gamedev en los marketplaces oficiales de Anthropic.**
  `anthropics/claude-plugins-official` (33 plugins propios + 68 de partners) y
  `anthropics/claude-plugins-community` no contienen ni un plugin de Godot,
  Unity o Unreal. Busque el `marketplace.json` del community y no hay match para
  godot / unity / unreal / game. Todo lo de abajo es de terceros, sin revision
  de Anthropic.
- **El ecosistema Godot para Claude Code SI es rico**, pero de calidad muy
  desigual: hay 4-5 repos serios (600+ estrellas) y una cola larga de repos de
  0-15 estrellas que son SKILL.md generados en masa. Los directorios
  (claudepluginhub.com, claudemarketplaces.com, claudeskills.info, mcpmarket.com,
  skillsmp.com, awesomeskill.ai) son agregadores SEO no afiliados: sirven para
  descubrir, no como fuente. No instalar desde ahi sin ir al repo.
- **La mayoria de esas skills asumen un proyecto Godot 2D empezando de cero**
  (tilemaps, CharacterBody2D, plataformas). Este proyecto es 3D, RigidBody3D,
  con fotogrametria, ya tiene su propio MCP de 332 comandos y skills propias
  (`godot-escena`, `godot-mcp`, `godot-verificar`). El solapamiento es alto y el
  aporte marginal de casi todo el catalogo es bajo.
- **No existe ninguna skill de "QA de juegos" generica y buena.** Lo que se
  vende como tal son wrappers de GdUnit4/PlayGodot. La verificacion por
  screenshot que ya hace este proyecto con el MCP es equivalente o mejor.

---

## 1. Lo que SI vale la pena para este proyecto

### awesome-gamedev-agent-skills (gamedev-skills)
- **URL:** https://github.com/gamedev-skills/awesome-gamedev-agent-skills
- **Metricas:** 746 estrellas, 57 forks, Apache-2.0, activo.
- **Que es:** 67 skills en formato SKILL.md portable (Claude Code, Cursor,
  Codex, Gemini CLI...), con un *router* que carga la skill correcta segun motor
  y tarea. Marketplace de Claude Code valido (verifique el
  `.claude-plugin/marketplace.json` a mano).
- **Plugins reales dentro** (nombres verbatim del marketplace.json):
  `gamedev` (todo), `router`, `godot`, `unity`, `unreal`, `web-engines`,
  `other-engines`, `disciplines`, `genres`, `workflows`.
- **Instalacion:**
  ```
  claude plugin marketplace add gamedev-skills/awesome-gamedev-agent-skills
  claude plugin install disciplines@awesome-gamedev-agent-skills
  ```
  (alternativa universal: `npx skills add gamedev-skills/awesome-gamedev-agent-skills --list`)
- **Aplica a este proyecto:** SI, pero **solo el plugin `disciplines`**, y de
  ahi realmente importan: `game-feel`, `level-design`, `camera-systems`,
  `input-systems`, `physics-tuning`, `performance-optimization`. Son
  conocimiento de diseno agnostico del motor — justo el hueco que este proyecto
  tiene (arrastra estructura de golf y hay que rediseniar el nivel y el feel).
  Contenido completo de `disciplines`: create-game-assets, game-ai,
  procedural-gen, dialogue-systems, save-systems, audio-design,
  shader-programming, physics-tuning, level-design, input-systems, game-feel,
  game-ui-ux, camera-systems, performance-optimization,
  ai-behavior-trees-utility-ai.
- **NO instalar el plugin `godot`** de aca (15 skills: godot-gdscript,
  godot-nodes-scenes, godot-2d-movement, godot-tilemap, godot-physics,
  godot-ui-control, godot-animation, godot-shaders, godot-3d-essentials,
  godot-resources, godot-audio, godot-multiplayer, godot-export, godot-csharp,
  godot-signals-groups): es material introductorio de Godot 4.7 con sesgo 2D. No
  aporta sobre lo que ya sabe el agente + el MCP + CLAUDE.md.
- **Tampoco `genres`**: platformer/roguelike/rpg/fps/... ninguno encaja con
  "llevar un piche a un punto".

### GodotPrompter (jame581)
- **URL:** https://github.com/jame581/GodotPrompter
- **Metricas:** 641 estrellas, MIT, v1.12.0, activo, Godot 4.3+ (cubre 4.5/4.6/4.7).
- **Que es:** 55 skills de dominio Godot + agentes especializados (arquitectura,
  code review, shaders, profiling de rendimiento). Es el repo Godot mejor
  mantenido que encontre.
- **Instalacion:**
  ```
  claude plugins marketplace add jame581/skillsmith
  claude plugins install godot-prompter@skillsmith
  ```
  (ojo: el marketplace se llama `skillsmith`, no `GodotPrompter`)
- **Aplica:** PARCIALMENTE. Lo util concreto: la skill de **state machine**
  (FSM basada en enum / en nodo / en resource, con los trade-offs de cada una) —
  relevante porque `juego.gd` es un monolito de ~840 lineas con estados de
  intro/jaula/conduccion/cinematica mezclados. Tambien tiene skills de camara,
  tween/animacion, particulas y audio (game feel). Riesgo: 55 skills es mucha
  superficie de contexto y varias van a chocar con las reglas de CLAUDE.md
  (autorar en editor, nada de `.new()`); habria que instalarlo y revisar cuales
  desactivar. NO tiene skill de level design.

### gd-agentic-skills (thedivergentai)
- **URL:** https://github.com/thedivergentai/gd-agentic-skills
- **Metricas:** 625 estrellas, LGPLv3, ultima release v0.0.11 (agosto 2026,
  "Agent Eyes/Vision Update"), Godot 4.7+.
- **Que es:** 99 skills con una skill orquestadora `godot-master`. Incluye
  bloques 3D reales (lighting, materials, navigation, physics, raycasting,
  world-building, procedural-gen), foundation (state machines, signals,
  composition, autoload, debugging) y 27 blueprints de genero.
- **Instalacion (NO es marketplace de Claude Code, es `npx skills`):**
  ```
  npx skills add thedivergentai/gd-agentic-skills/skills/godot-master -g -a claude-code -y
  ```
  o una sola: `npx skills add thedivergentai/gd-agentic-skills/skills/<nombre> -g -a claude-code -y`
- **Aplica:** SOLO A LA CARTA. Instalar `godot-master` (99 skills) es
  contraproducente aca. Lo que puede valer suelto: la de **state machines**, la
  de **3d-raycasting** (el proyecto ya se quemo con rayos que paran en la copa
  del arbol) y la de **composition**. Advertencia de licencia: **LGPLv3**, mas
  restrictiva que MIT/Apache; si algun texto se copia al repo, tenerlo presente.

### GDScript LSP para Claude Code
El aporte tecnico mas real de todos: le da a Claude diagnostics, go-to-definition,
hover y completions sobre `.gd` reales via el language server que Godot ya trae.
Deja de adivinar nombres de API. Hay tres implementaciones; ninguna es dominante:

1. **twaananen/claude-code-gdscript** — https://github.com/twaananen/claude-code-gdscript
   - 4 estrellas, 2 forks, MIT. Godot 4.3+, Node.js, puerto LSP 6005
     (`GODOT_LSP_PORT`), Godot en PATH o `GODOT_EDITOR_PATH`.
   - Instalacion:
     ```
     /plugin marketplace add twaananen/claude-code-gdscript
     claude plugin install gdscript@claude-code-gdscript --scope project
     ```
   - Windows: no documentado explicitamente, pero la ruta es configurable por
     env var y aca ya se sabe donde esta el exe
     (`C:\Users\ivanu\Downloads\Godot_v4.6.3-stable_win64.exe\...`).
2. **minami110/claude-godot-tools** — https://github.com/minami110/claude-godot-tools
   - 13 estrellas. Marketplace con 4 plugins: `gdscript-lsp`,
     `gdscript-toolkit` (file manager, formato, busqueda en la doc oficial +
     agente `godot-doc-search`), `gdunit4-toolkit`, `vscode-gdscript-tools`
     (este ultimo requiere MCP de VSCode, ignorar).
   - Instalacion:
     ```
     claude plugin marketplace add minami110/claude-godot-tools
     claude plugin install gdscript-lsp@claude-godot-tools
     claude plugin install gdscript-toolkit@claude-godot-tools
     ```
   - Aplica: el `gdscript-toolkit` con busqueda en la documentacion oficial de
     Godot es lo mas util del grupo despues del LSP.
3. **Sods2/claude-code-gdscript-lsp** — https://github.com/Sods2/claude-code-gdscript-lsp
   - 7 estrellas, 5 commits, requiere Claude Code v2.0.74+. Se instala con
     `./scripts/install.sh` (bash) — en Windows necesita Git Bash/WSL.
   - **Descartar**: es el mas nuevo y menos mantenido de los tres y no aporta
     nada sobre el de twaananen.

**Nota importante sobre el LSP:** los tres necesitan el editor de Godot corriendo
con el proyecto abierto para que el language server escuche. En este proyecto el
editor ya se abre para usar el MCP, asi que el costo extra es cero. Pero ojo: el
MCP `godot` de este repo **fallo al conectar en esta sesion** (ConnectionRefused),
lo que sugiere que el editor no siempre esta levantado.

---

## 2. Lo que existe pero NO recomiendo para este proyecto

### wshobson/agents — plugin game-development
- **URL:** https://github.com/wshobson/agents (39.3k estrellas, MIT)
- Directorio verificado: `plugins/game-development/skills/` contiene exactamente
  dos skills: `godot-gdscript-patterns` y `unity-ecs-patterns`.
  https://github.com/wshobson/agents/tree/main/plugins/game-development/skills
- Instalacion: `/plugin marketplace add wshobson/agents` y luego
  `/plugin install game-development`. **Advertencia:** el README del repo no
  lista `game-development` entre sus plugins destacados; el directorio existe
  pero no pude confirmar el nombre exacto del plugin en su marketplace.json.
  Verificar con `/plugin marketplace add` antes de instalar a ciegas.
- La skill `godot-gdscript-patterns` (FSM, event bus por autoload, object
  pooling, composicion de escenas) se solapa casi entera con las de
  GodotPrompter y gd-agentic-skills. Si ya instalas una de esas, esta sobra.

### alexmeckes/godot-claude-skills
- **URL:** https://github.com/alexmeckes/godot-claude-skills — 27 estrellas, MIT.
- 5 skills: `godot-code-gen`, `godot-live-edit`, `godot-interactive`,
  `godot-scene-design`, `godot-shader`.
- Instalacion:
  ```
  /plugin marketplace add alexmeckes/godot-claude-skills
  /plugin install godot-claude-skills
  ```
- **NO aplica.** `godot-interactive` y `godot-live-edit` dependen de *otro*
  MCP (`godot-mcp` + un addon "AI Bridge") distinto del que este proyecto ya
  tiene. `godot-scene-design` es exactamente lo que la skill propia
  `/godot-escena` ya hace, y mejor, porque la propia conoce las trampas de este
  repo (AABB con esqueleto, rayos que paran en la copa, colision de barrotes).

### Randroids-Dojo/Godot-Claude-Skills
- **URL:** https://github.com/Randroids-Dojo/Godot-Claude-Skills — 41 estrellas.
- Una sola skill: GdUnit4 + PlayGodot + CI/CD GitHub Actions + deploy a
  Vercel/Pages/itch.io. Godot 4.x (probado en 4.3.0).
- Instalacion: `/plugin marketplace add Randroids-Dojo/Godot-Claude-Skills` +
  `/plugin install godot`.
- **NO aplica, y ademas el README la declara DEPRECADA** (dice que migro al
  marketplace de Randroid's Dojo). El unico pedazo interesante seria GdUnit4,
  pero este proyecto ya tiene su propio arnes de verificacion
  (`_self_check()` headless con `--quit-after`), que es mas barato que montar
  GdUnit4 entero.

### PooDoge/godot-mcp-skills
- **URL:** https://github.com/PooDoge/godot-mcp-skills — **0 estrellas, 1 commit**, MIT.
- 5 skills: `godot-scene-builder`, `godot-debugger`, `godot-shader-lab`,
  `godot-collision-audit`, `godot-scene-doctor`.
- **NO aplica.** Requiere el MCP `godot-mcp-pro` (155+ tools), que NO es el
  addon de este proyecto (332 comandos). Sin ese servidor las skills no hacen
  nada. Repo sin historia ni adopcion.

### Directorios / agregadores (no instalar desde ahi)
Sirven solo para descubrir. Verificados como existentes:
- https://claudemarketplaces.com/ — 381 skills de gamedev listadas.
- https://www.claudepluginhub.com/ — no afiliado a Anthropic.
- https://claudeskills.info/skills/category/game-development/
- https://mcpmarket.com/tools/skills/... — fichas SEO de skills sueltas.
- https://github.com/anthropics/claude-plugins-official — el oficial, sin gamedev.
- https://github.com/anthropics/claude-plugins-community — el community, sin gamedev.

---

## 3. Recomendacion final

Instalar, en este orden y midiendo despues de cada uno:

1. `disciplines@awesome-gamedev-agent-skills` — por `game-feel` y `level-design`.
   Es lo unico que ataca el problema real declarado en CLAUDE.md: sacarle el
   pasado de golf al juego y rediseniar como se siente y como se lee el nivel.
2. Un LSP de GDScript (`gdscript@claude-code-gdscript`, o `gdscript-lsp` +
   `gdscript-toolkit` de minami110) — beneficio puramente tecnico, cero
   solapamiento con lo que ya hay, y elimina APIs inventadas.
3. Solo si el refactor de `juego.gd` se pone serio: la skill de state machine de
   GodotPrompter o de gd-agentic-skills, suelta, no el paquete completo.

NO instalar paquetes Godot completos (`godot@awesome-gamedev-agent-skills`,
`godot-master`, `godot-prompter` entero): este repo ya tiene tres skills propias
que codifican trampas especificas que ninguna skill generica conoce, y el ruido
de contexto de 55-99 skills genericas puede empujar al agente justo contra las
reglas de CLAUDE.md (construir en `_ready`, `.new()` de nodos, `get_node("..")`).
