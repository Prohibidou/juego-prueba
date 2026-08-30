# Piche: La Gran Fuga — producción 3D

Complemento de [DISENO.md](DISENO.md): **qué es alcanzable en la máquina en la
que se está desarrollando**, y de dónde salen los modelos.

> Este documento se recortó en agosto de 2026. La versión anterior planificaba
> un campo de golf de cuatro hoyos con terreno esculpido en Terrain3D; el juego
> usa fotogrametría real y no esculpe terreno, así que ese plan entero se cayó.
> Queda lo que sigue siendo cierto: el techo del hardware y las fuentes de arte.

---

## 1. El techo del hardware, con datos

La GPU de desarrollo es una **Intel Iris Xe integrada**. Esto no es una opinión
sobre el objetivo, es el dato que condiciona todo lo demás:

- Usuarios con **Iris Xe (i7-1185G7)** reportan **10 FPS en el editor y 10–20
  FPS en build** con la plantilla 3D mínima de Godot usando **Forward+**
  ([godot#82644](https://github.com/godotengine/godot/issues/82644)).
- Las funciones con más impacto en frame rate son justo las "cinematográficas":
  SSIL, SDFGI, sombras de follaje denso
  ([docs de optimización GPU](https://docs.godotengine.org/en/4.3/tutorials/performance/gpu_optimization.html)).

**Conclusión: Forward+ y la iluminación global en tiempo real están descartados.**
El proyecto se queda en el renderer **Mobile**, que es donde ya está.

### Lo que Mobile no tiene, y con qué se sustituye

| No disponible en Mobile | Sustituto |
|---|---|
| SDFGI / VoxelGI (GI en tiempo real) | Ambiente del cielo (HDRI) + AO horneada en las texturas |
| SSAO / SSIL | AO horneada en los modelos |
| Niebla volumétrica | Niebla de distancia (ya la usamos) + capa de neblina en el horizonte |
| Reflejos en espacio de pantalla | Sonda de reflexión o reflejo plano solo para el agua |
| Más de 8 luces omni/spot por malla | Irrelevante: hay una luz, el sol |

Fuente: [comparativa de renderers en godot-docs](https://github.com/godotengine/godot-docs/blob/master/tutorials/rendering/renderers.rst).

**Dato importante:** los **lightmaps horneados sí se renderizan en Mobile**, y
el horneado requiere hardware con RenderingDevice, que esta máquina tiene. Como
el escenario es una malla estática importada, es horneable — a diferencia de un
terreno generado en `_ready`, que no existe cuando el editor hornea.

---

## 2. Presupuesto de rendimiento para Iris Xe

Objetivo: **1080p y 60 FPS estables**, o 1080p/30 con escala de resolución si
hace falta.

| Concepto | Límite |
|---|---|
| Draw calls por frame | < 1.000 |
| Triángulos visibles | < 1,5 M |
| Sombra direccional | 2048 px, 2 particiones, 80 m de alcance |
| Antialiasing | MSAA 2x (TAA no está en Mobile) |
| GI en tiempo real | ninguna |

Regla práctica: si algo baja de 60 FPS, se recorta la distancia antes que la
calidad. Un mapa con niebla a 90 m se ve intencionado; un mapa a 20 FPS no.

**Pendiente y sin medir:** nadie corrió un profiling del muelle todavía. El
mapa son 60 mallas con colisión trimesh generada en cada arranque (varios
segundos de carga, por eso existe la portada). Ver AUDITORIA.md.

---

## 3. Objetivo visual: realismo estilizado

El escenario es fotogrametría real, así que la coherencia la marca él: los
modelos que se le agreguen (el piche, la jaula, la camioneta, la basura) tienen
que estar a su nivel de detalle, no en low-poly plano.

---

## 4. De dónde salen los modelos

Todo lo siguiente es **CC0**: uso comercial, sin atribución, sin sorpresas de
licencia.

| Fuente | Qué aporta | Formato |
|---|---|---|
| [Poly Haven](https://polyhaven.com) | HDRIs de cielo, texturas PBR, modelos | glTF, EXR |
| [ambientCG](https://ambientcg.com) | Materiales PBR: metal, madera, hormigón, óxido | PNG/EXR |
| [Kenney](https://kenney.nl) | Más de 40.000 assets, atlas de textura compartido | glTF, FBX, OBJ |
| [Quaternius](https://quaternius.com) | Packs de naturaleza y props | glTF |
| [KayKit](https://kaylousberg.itch.io) | Kits con estilo coherente entre sí | glTF |
| [awesome-cc0](https://github.com/madjin/awesome-cc0) | Índice de todo lo anterior | — |

Kenney y Quaternius **comparten atlas de textura dentro de cada pack**, lo que
permite renderizar una escena entera en pocas draw calls. Importa en una GPU
integrada.

### Pipeline propio

Para lo que no exista:

1. **Blender**. Godot 4 importa `.blend` directamente si Blender está
   instalado; si no, se exporta a **glTF 2.0 (`.glb`)**, que es el recomendado.
2. Hornear AO y detalle en las texturas dentro de Blender. Esa AO horneada es
   la que sustituye al SSAO que Mobile no tiene.
3. Un material por modelo, atlas compartido entre modelos del mismo tipo.

---

## 5. Riesgos honestos

- **El cuello de botella es el arte, no el código.** Cada mapa nuevo es
  conseguir o modelar un escenario, colocarle la jaula de salida y la
  camioneta, y afinarlo.
- **La máquina de desarrollo es el peor caso.** Puede llevar a subestimar el
  rendimiento, o a perder días optimizando para una GPU que el jugador quizá no
  tenga. El objetivo mínimo está fijado arriba; no conviene volver a discutirlo.
- **La animación del piche está sin usar.** El `.fbx` trae animaciones que hoy
  se descartan en `_preparar_piche()`. Es la pieza de arte con más impacto
  visual pendiente.

---

## Fuentes

- [Godot — comparativa de renderers](https://github.com/godotengine/godot-docs/blob/master/tutorials/rendering/renderers.rst)
- [Godot — uso de LightmapGI](https://github.com/godotengine/godot-docs/blob/master/tutorials/3d/global_illumination/using_lightmap_gi.rst)
- [Godot — optimización de GPU](https://docs.godotengine.org/en/4.3/tutorials/performance/gpu_optimization.html)
- [Rendimiento en Intel Iris Xe (godot#82644)](https://github.com/godotengine/godot/issues/82644)
- [awesome-cc0 — índice de assets libres](https://github.com/madjin/awesome-cc0)
- [Poly Haven](https://polyhaven.com) · [ambientCG](https://ambientcg.com) · [Kenney](https://kenney.nl) · [Quaternius](https://quaternius.com)
