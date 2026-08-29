# Golfito — producción 3D: escenas, modelos y calidad visual

Complemento de [DISENO.md](DISENO.md). Este documento responde a: **cómo se
construye el juego para que se vea bien de verdad**, y qué es alcanzable en la
máquina en la que se está desarrollando.

---

## 1. El techo del hardware, con datos

La GPU de desarrollo es una **Intel Iris Xe integrada**. Esto no es una opinión
sobre el objetivo, es el dato que condiciona todas las decisiones siguientes:

- Usuarios con **Iris Xe (i7-1185G7)** reportan **10 FPS en el editor y 10–20
  FPS en build** con la plantilla 3D mínima de Godot usando **Forward+**
  ([godot#82644](https://github.com/godotengine/godot/issues/82644)).
- Las funciones con más impacto en frame rate son justo las "cinematográficas":
  SSIL, SDFGI, sombras en el césped y follaje denso
  ([docs de optimización GPU](https://docs.godotengine.org/en/4.3/tutorials/performance/gpu_optimization.html)).

**Conclusión: Forward+ y la iluminación global en tiempo real están descartados.**
El proyecto se queda en el renderer **Mobile**, que es donde ya está.

Esto no es una renuncia a la calidad. Es elegir el camino correcto: la calidad
visual de un campo de golf no viene de la GI en tiempo real, viene de la
densidad de detalle, del material del suelo y de la dirección de arte.

### Lo que Mobile no tiene, y con qué se sustituye

| No disponible en Mobile | Sustituto |
|---|---|
| SDFGI / VoxelGI (GI en tiempo real) | Ambiente del cielo (HDRI) + AO horneada en las texturas |
| SSAO / SSIL | AO horneada en los modelos y en los colores de vértice del terreno |
| Niebla volumétrica | Niebla de distancia (ya la usamos) + capa de neblina en el horizonte |
| Reflejos en espacio de pantalla | Sonda de reflexión o reflejo plano solo para el agua |
| Más de 8 luces omni/spot por malla | Irrelevante: un campo de golf tiene una luz, el sol |

Fuente: [comparativa de renderers en godot-docs](https://github.com/godotengine/godot-docs/blob/master/tutorials/rendering/renderers.rst).

**Dato importante:** los **lightmaps horneados sí se renderizan en Mobile**. El
horneado requiere hardware con RenderingDevice, que esta máquina tiene.

---

## 2. La bifurcación, ya decidida: camino A

Los lightmaps exigen **mallas estáticas con UV2, horneadas desde el editor**
([using_lightmap_gi](https://github.com/godotengine/godot-docs/blob/master/tutorials/3d/global_illumination/using_lightmap_gi.rst)).
Una malla que se genera por código al arrancar el juego **no se puede hornear**:
no existe cuando el editor hornea.

Ahí está la bifurcación:

### Camino A — Escenas autoradas (calidad máxima)

Cuatro escenas `.tscn`, una por hoyo, esculpidas a mano en el editor con
Terrain3D. El terreno procedural actual se degrada a **herramienta**: genera el
mapa de alturas base, lo exportas, lo importas en Terrain3D y lo esculpes.

- Se puede pintar a mano dónde está la calle, el rough, el búnker y el green.
- Se puede colocar cada árbol donde tiene sentido de juego, no donde cayó un
  `randf()`.
- Los doglegs, la manada y la lava quedan exactamente donde dice el diseño.
- Es lo que hace un estudio, y es lo que se ve como un estudio.

Coste: es trabajo de artista, no de programador. Y añade Terrain3D, una
dependencia binaria C++.

### Camino B — Generación dirigida por datos (lo que ya hay, subido de nivel)

Se mantiene la generación por código, pero cada hoyo pasa de ser un `randf()` a
un bloque de datos: dónde va la cresta, el búnker, la lava, las manadas. Se le
añade shader de splatmap propio, AO por color de vértice y césped instanciado.

- Cero dependencias nuevas, reutiliza todo el trabajo hecho.
- Aproximadamente **una quinta parte del esfuerzo** del camino A.
- Techo visual claramente más bajo: se llega a "muy buen indie estilizado", no a
  "parece un juego comercial".

### Decisión tomada: camino A

Se autoran los cuatro hoyos con Terrain3D. El generador procedural actual pasa a
ser una **herramienta de preproducción**: escupe el mapa de altura base de cada
hoyo, se importa en Terrain3D y se esculpe a mano desde ahí.

Consecuencia asumida: a partir de la fase 2, la mayor parte del trabajo restante
deja de ser código y pasa a ser montaje y dirección de arte.

---

## 3. El objetivo visual realista: realismo estilizado

Referencias correctas: *Everybody's Golf*, *The Golf Club*, *Cursed to Golf*.
Referencia incorrecta: *PGA Tour 2K*, que pide una GPU dedicada moderna.

El realismo estilizado gana aquí por dos motivos: se ve deliberado en vez de
pobre, y envejece mucho mejor que un fotorrealismo a medias.

---

## 4. De dónde salen los modelos

Todo lo siguiente es **CC0**: uso comercial, sin atribución, sin sorpresas de
licencia.

| Fuente | Qué aporta | Formato |
|---|---|---|
| [Poly Haven](https://polyhaven.com) | HDRIs de cielo, texturas PBR, modelos | glTF, EXR |
| [ambientCG](https://ambientcg.com) | Materiales PBR: césped, arena, roca, tierra | PNG/EXR |
| [Kenney](https://kenney.nl) | Más de 40.000 assets, kits estilizados, atlas de textura compartido | glTF, FBX, OBJ |
| [Quaternius](https://quaternius.com) | Packs de naturaleza, árboles low-poly texturizados | glTF |
| [KayKit](https://kaylousberg.itch.io) | Kits con estilo coherente entre sí | glTF |
| [awesome-cc0](https://github.com/madjin/awesome-cc0) | Índice de todo lo anterior y más | — |

Kenney y Quaternius **comparten atlas de textura dentro de cada pack**, lo que
permite renderizar una escena entera en pocas draw calls. Eso importa mucho en
una GPU integrada.

### Pipeline de modelado propio

Para lo que no exista (la bandera, el hoyo, la bola, los animales):

1. **Blender** (gratis). Godot 4 importa `.blend` directamente si Blender está
   instalado; si no, se exporta a **glTF 2.0 (`.glb`)**, que es el formato
   recomendado.
2. Hornear AO y detalle en las texturas dentro de Blender. Esa AO horneada es la
   que sustituye al SSAO que Mobile no tiene.
3. Un solo material por modelo, atlas compartido entre modelos del mismo tipo.

---

## 5. Terreno

**[Terrain3D](https://github.com/TokisanGames/Terrain3D)** es la opción seria.
GDExtension en C++, compatible con **Godot 4.4–4.6+**, última versión de
mayo de 2026.

Lo relevante para este juego:

- Malla clipmap movida por GPU, con **10 niveles de detalle**.
- **Hasta 32 texturas con pintado manual**: exactamente lo que hace falta para
  calle / rough / búnker / green / camino.
- **Instanciado de follaje con 10 niveles de LOD**, capaz de cientos de miles de
  mallas.
- Agujeros en el terreno (para el hoyo de verdad, y para la lava).
- Importa mapas de altura de HTerrain, Gaea, World Machine, Unity y Unreal — o
  del generador que ya tenemos.

La alternativa sin dependencias es seguir con la malla propia y escribirle un
shader de splatmap. Es viable, pero pintar a mano cuatro superficies distintas
por hoyo sin editor es tedioso y se nota en el resultado.

---

## 6. Césped: lo que más cambia la sensación

Un campo de golf es césped. Un plano verde liso lo delata al instante.

- **MultiMeshInstance3D** es lo indicado a partir de 50 instancias idénticas, y
  permite decenas de miles de mallas animadas en **una sola draw call**.
- **Terrain3DInstancer** hace lo mismo con LOD ya resuelto, que MultiMesh crudo
  no trae: sin frustum culling ni LOD propios, hay que implementarlos aparte.
- El viento se hace con **animación en el vértice dentro del shader**, no con
  nodos de animación.
- Referencias de shader listas para usar en
  [Godot Shaders](https://godotshaders.com/shader/stylized-multimesh-grass-shader/)
  y [GodotGrass](https://github.com/2Retr0/GodotGrass).

Presupuesto realista en Iris Xe: **briznas solo en un radio de 20–25 m
alrededor de la bola**, y textura de césped con normal map más allá. Nadie mira
el suelo a 80 metros.

---

## 7. Los detalles que hacen que un juego de golf parezca caro

Por orden de impacto visual respecto al esfuerzo:

1. **Franjas de corte en la calle.** La firma visual del golf televisado.
   Se hacen con una máscara de rayas en el shader según la posición del mundo,
   modulando albedo y rugosidad. Coste: casi cero. Impacto: enorme.
2. **Cielo HDRI** (`PanoramaSkyMaterial` con un HDRI de Poly Haven) en vez del
   cielo procedural. Además da ambiente gratis a toda la escena.
3. **Neblina de distancia en capas** que separa el primer plano del fondo. Es lo
   que crea la sensación de campo grande.
4. **Sombra de contacto bajo la bola**, para que no parezca flotando.
5. **Estela y marca de bote**, ya implementadas, solo hay que subirles el nivel.
6. **Desenfoque de campo suave en la cámara del tee**, que se abre al golpear.
7. **Gradación de color** con LUT, distinta por bioma: cálida en el desierto,
   azulada en la nieve.
8. **Árboles con impostor** más allá de 60 m: un cuadrilátero con textura en vez
   de geometría.
9. **Bandera con animación de tela** por vértice, respondiendo al viento del
   hoyo. Detalle diminuto, comunica una mecánica.
10. **Bruma volumétrica falsa** en el volcán: planos de niebla con textura.

---

## 8. Estructura de escenas propuesta

```
res://
  escenas/
    Juego.tscn            <- raíz, cámara, HUD, gestor de vuelta
    hoyos/
      Hoyo1Pradera.tscn   <- terreno, props, manadas, marcadores de tee/hoyo
      Hoyo2Desierto.tscn
      Hoyo3Nieve.tscn
      Hoyo4Volcan.tscn
    piezas/
      Bola.tscn
      Bandera.tscn
      Animal.tscn
      Arbol.tscn / Cactus.tscn / Roca.tscn
  modelos/                <- .glb importados
  materiales/
  shaders/
    cesped.gdshader
    franjas_calle.gdshader
    agua.gdshader
  scripts/
    juego.gd              <- reglas, marcador, estado
    golpe.gd              <- swing, dispersión, putt
    hoyo.gd               <- datos del hoyo: par, viento, tee, bandera
```

Cada `HoyoN.tscn` expone marcadores (`Marker3D`) para tee y bandera, un valor de
par, un vector de viento y las zonas de manada. `juego.gd` carga el hoyo
siguiente y no sabe nada de cómo está hecho por dentro.

Esto separa **reglas** de **contenido**, que es justo lo que hoy no está
separado: los 721 renglones actuales mezclan las dos cosas.

---

## 9. Presupuesto de rendimiento para Iris Xe

Objetivo: **1080p y 60 FPS estables**, o 1080p/30 con escala de resolución si
hace falta.

| Concepto | Límite |
|---|---|
| Draw calls por frame | < 1.000 |
| Triángulos visibles | < 1,5 M |
| Sombra direccional | 2048 px, 2 particiones, 80 m de alcance |
| Césped instanciado | radio de 25 m |
| Árboles con geometría | hasta 60 m; impostor más allá |
| Antialiasing | MSAA 2x (TAA no está en Mobile) |
| GI en tiempo real | ninguna |

Regla práctica: si algo baja de 60 FPS, se recorta la distancia antes que la
calidad. Un campo con niebla a 90 m se ve intencionado; un campo a 20 FPS no.

---

## 10. Fases de producción

1. **Reestructurar** (solo código). Partir `golf.gd` en reglas + contenido, con
   escenas de hoyo vacías y marcadores. Sin cambio visual, pero sin esto no se
   puede meter arte.
2. **Terreno y materiales.** Terrain3D, mapas de altura del generador actual,
   pintado de calle/rough/búnker/green, franjas de corte.
3. **Vegetación y props.** Assets CC0, instanciado con LOD, viento por shader.
4. **Cielo e iluminación.** HDRI por bioma, sol, niebla en capas, gradación de
   color.
5. **Mecánicas del diseño.** Dispersión, putt con caída, manadas, lava, viento.
6. **Pulido.** Cámaras, estela, sonido, tarjeta final.

Las fases 1 y 5 son código. Las 2, 3 y 4 son trabajo de arte y montaje, y son la
mayor parte del calendario.

---

## 11. Riesgos honestos

- **El cuello de botella pasa a ser el arte, no el código.** A partir de la fase
  2, la velocidad la marca cuánto tarda en montarse y afinarse cada hoyo.
- **Terrain3D es una dependencia binaria.** Si el proyecto se actualiza a una
  versión de Godot que el plugin no soporta todavía, el proyecto se queda
  esperando. Es un riesgo aceptable a cambio de lo que ahorra, pero es real.
- **La máquina de desarrollo es el peor caso.** Puede llevar a subestimar el
  rendimiento y quedarse corto de ambición, o a perder días optimizando para una
  GPU que el jugador final quizá no tenga. Conviene fijar el objetivo mínimo
  ahora y no volver a discutirlo.
- **El alcance puede comerse el proyecto.** Cuatro hoyos con calidad de estudio
  son más trabajo que cuarenta hoyos generados. El diseño ya está acotado a
  cuatro; conviene que siga así.

---

## Fuentes

- [Terrain3D — repositorio](https://github.com/TokisanGames/Terrain3D)
- [Terrain3D — instanciado de follaje](https://terrain3d.readthedocs.io/en/stable/docs/instancer.html)
- [Godot — comparativa de renderers](https://github.com/godotengine/godot-docs/blob/master/tutorials/rendering/renderers.rst)
- [Godot — lista de funciones](https://github.com/godotengine/godot-docs/blob/master/about/list_of_features.rst)
- [Godot — uso de LightmapGI](https://github.com/godotengine/godot-docs/blob/master/tutorials/3d/global_illumination/using_lightmap_gi.rst)
- [Godot — optimización de GPU](https://docs.godotengine.org/en/4.3/tutorials/performance/gpu_optimization.html)
- [Rendimiento en Intel Iris Xe (godot#82644)](https://github.com/godotengine/godot/issues/82644)
- [Rendimiento de Forward+ en escena simple (godot#82238)](https://github.com/godotengine/godot/issues/82238)
- [Shader de césped multimesh estilizado](https://godotshaders.com/shader/stylized-multimesh-grass-shader/)
- [GodotGrass](https://github.com/2Retr0/GodotGrass)
- [awesome-cc0 — índice de assets libres](https://github.com/madjin/awesome-cc0)
- [Poly Haven](https://polyhaven.com) · [ambientCG](https://ambientcg.com) · [Kenney](https://kenney.nl) · [Quaternius](https://quaternius.com)
