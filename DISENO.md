# Golfito — definición del juego

> Una vuelta de 4 hoyos, un bioma por hoyo. Menos golpes es mejor.
> El terreno manda y la fauna te cuesta caro.

Documento de diseño cerrado. Si el código y este documento no coinciden, manda
este documento.

---

## 1. El principio rector

**Cada golpe tiene que ser una decisión.** Si apuntar a la bandera y pegar a
tope es siempre lo correcto, no hay juego: hay una barra de potencia con
paisaje. Todo lo que sigue existe para crear la duda *"¿voy a por ello o me
quedo corto?"*.

De ahí salen las tres fuentes de riesgo:

1. **El golpe fuerte se paga en precisión** (dispersión).
2. **La zona de caída de un drive completo duele** (búnker, lava, rough).
3. **La fauna ocupa el buen camino** (manadas en la línea corta).

---

## 2. El swing

Apuntas (dirección + ángulo 5°–55°), cargas potencia y sueltas.

**Dispersión por potencia.** Cuanto más rápido sale la bola, más se abre un
cono de desvío aleatorio, y **el cono se dibuja en el suelo mientras cargas**.
No hay azar oculto: ves lo que arriesgas antes de soltar.

- La dispersión escala con la **velocidad real de salida**, no con el
  porcentaje de barra. Así un putt sale siempre exacto y solo el driver a tope
  tiembla.
- Golpe suave: línea exacta. Golpe a tope: hasta ~5° de desvío.

Sin selección de palos: potencia + ángulo cubren lo mismo con dos perillas en
vez de un inventario.

## 3. El putt

Se activa solo cuando la bola está dentro del green.

- Ángulo forzado a 0 (rasante), potencia máxima recortada, cámara más baja.
- **El green tiene una caída suave, distinta en cada hoyo.** Para embocar de
  lejos apuntas a un lado y dejas que la pendiente la meta.
- La caída se comunica con una **flecha 3D apoyada en el césped apuntando
  cuesta abajo**, más larga cuanto más fuerte es la pendiente. Una pendiente
  suave no se ve en low-poly; pedir que la leas a ojo sería injusto.

## 4. El campo y los cuatro hoyos

El campo mide 128×128 m y un drive máximo son 72 m. **No hace falta un campo
más grande**: la longitud se fabrica con doglegs y con la diagonal, que da
181 m de esquina a esquina.

Un **dogleg** es una cresta: una loma alargada entre tee y hoyo. La sobrevuelas
solo con un golpe alto y fuerte (el que más dispersión tiene) o la rodeas por
seguro.

| # | Bioma | Par | Trazado | Regla propia del bioma |
|---|---|---|---|---|
| 1 | Pradera | 3 | 75 m recto | Ninguna. Es el tutorial: un drive bueno llega al green |
| 2 | Desierto | 4 | 130 m, dogleg derecha | **La arena no deja rodar**: todo es vuelo. Viento lateral constante. Búnker en la caída del atajo recto |
| 3 | Nieve | 4 | 120 m | **El problema es pasarse**: la bola rueda eternamente, hay placas de hielo y el green está en una hondonada |
| 4 | Volcán | 5 | 175 m, diagonal completa | Terreno quebrado y un **río de lava a los 90 m**: lo cruzas de un golpe (riesgo) o vas al paso estrecho (dos golpes seguros) |

**Par de la vuelta: 16.**

Cada hoyo tiene una línea larga segura y una corta arriesgada. El hoyo 1 es la
excepción deliberada: enseña a jugar, no pone trampas.

Un bioma que solo cambia la paleta es un fondo de pantalla. Por eso cada uno
cambia **una regla** y obliga a un tipo de golpe distinto.

## 5. La fauna

**Manadas en zonas fijas.** Pastan agrupadas en sitios concretos y se mueven
poco. Las ves desde el tee y planificas: la línea corta pasa por la manada,
rodearla cuesta distancia.

El castigo siempre es culpa tuya, nunca mala suerte. Un bicho que se cruza
mientras la bola vuela sería un impuesto aleatorio, y en un juego de precisión
eso se siente injusto.

Al recibir el pelotazo el animal queda **aturdido, no muerto**: estrellitas, se
levanta y sale corriendo. Mismo castigo, misma lectura, y el juego deja de ir
de matar bichos.

## 6. Reglas y penalizaciones

Marcador único: **golpes**. Todo se paga en la misma moneda.

| Situación | Coste |
|---|---|
| Animal alcanzado | **+2 golpes** |
| Lava o agua | **+1 golpe**, repites desde donde pegaste |
| Drop voluntario (tecla R) | **+1 golpe**, junto a donde estabas |
| Árbol | Sin penalización: ya te castiga comiéndose la velocidad y dejándote en mal sitio |
| Fuera de límites | No existe. El perímetro rebota, con un seto visible para que no parezca un muro roto |

**Nunca se pierde una bola.** Con dispersión, lava y manadas, el peor caso
posible de cualquier desastre es un golpe. `R` no puede ser un rebobinado
gratis: sin coste, ninguna mala posición tiene consecuencias.

El **viento** es constante por hoyo, con flecha e intensidad en el HUD, y solo
actúa en vuelo. Sin ráfagas: una ráfaga aleatoria es azar oculto, exactamente
lo contrario del cono de dispersión, que sí se ve.

Los **cráteres** son cosméticos: la cicatriz de un golpe que se fue largo.

## 7. La partida

Cuatro hoyos, de cinco a ocho minutos. Al terminar, tarjeta con el desglose
hoyo a hoyo, el total contra par, y **la mejor vuelta guardada en disco**.

Ese es todo el metajuego que necesita. Sin desbloqueos, sin monedas, sin
carrera profesional.

## 8. Lo que queda fuera

Selección de palos, multijugador, personalización, campos infinitos, efecto
lateral en la bola, modo carrera. Son juegos distintos y más grandes, y ninguno
resuelve el problema del punto 1.

---

## 9. Orden de construcción

1. **Que sea golf.** Modo putt + caída del green con flecha, dispersión con
   cono visible, calle/rough/búnker con rozamiento y color propios, animal +2,
   `R` con coste, árbol como obstáculo.
2. **El campo.** Los cuatro trazados con sus pares reales, doglegs por cresta,
   manadas en zonas fijas, lava en el hoyo 4, viento por hoyo.
3. **El cierre.** Tarjeta final, récord en disco, avisos de birdie/bogey,
   cámara al embocar, sonido.
