# Piche: La Gran Fuga — diseño

> Un piche se escapó y quiere volver a su casa. Cada mapa se cruza a pie y a
> saltos hasta llegar a la camioneta, que lo lleva al mapa siguiente.

Este documento describe **el juego que se está haciendo**. Reemplaza al
documento de diseño de golf, que describía otro juego (cuatro hoyos, par,
putt, biomas) y ya no aplica a nada del código.

Lo que todavía no está decidido va marcado como **abierto**. Lo pendiente de
implementar, con su orden, está en [AUDITORIA.md](AUDITORIA.md).

---

## 1. El principio rector

**Cruzar el mapa tiene que ser un problema, no una caminata.** Si caminar en
línea recta hasta la camioneta siempre alcanza, no hay juego: hay un paseo con
paisaje. Todo lo que se agregue tiene que responder a *"¿por dónde paso?"* o
*"¿me alcanza para llegar?"*.

Hoy el juego no cumple esto: nada te puede detener y la stamina nunca se
acaba. Es el hueco principal.

## 2. El bucle

1. El piche arranca **encerrado en una jaula**, en la cubierta de un barco.
2. El primer impulso revienta la puerta — es la intro, en cámara lenta.
3. Se cruza el mapa: caminando (lento, gratis) o a impulsos (rápido, cuesta
   stamina), esquivando lo que haya en el medio y juntando basura para
   recargar.
4. Se llega a la **caja de la camioneta** y hay que quedarse ahí, posado: pasar
   por arriba volando no cuenta.
5. Cambio de mapa. Al último, el piche llegó a su casa y se termina.

## 3. Los verbos

| Verbo | Tecla | Qué hace |
|---|---|---|
| Girar | A / D, stick izq. eje X | Cambia la mira, que es el rumbo *y* el ángulo de cámara |
| Caminar | W / S, stick izq. eje Y | Avanza en la mira. Tope 4,5 m/s. No cuesta nada |
| Impulso | G, botón A | Carga una barra 2 s y sale disparado hasta 26 m/s. Cuesta stamina |
| Salto | Espacio, botón X | Brinco corto, gratis, sin salir del modo de andar |
| Timón | ← / →, arrastre | En el aire, corrige la línea. Presupuesto corto por impulso |
| Destrabar | R | Reubica al piche a un par de metros. Sin coste |

El mando es **de tanque a propósito**: girar y avanzar son ejes distintos, así
que moverse en línea recta nunca mueve la cámara y una pendiente no puede
desviar el rumbo.

**Cuanto más cargás el impulso, menos puntería tenés** (la dispersión va con el
cuadrado de la fuerza). Sin eso, cargar a tope sería siempre lo correcto y la
barra no sería una decisión.

**Abierto:** ¿el piche *corre* o el piche *se catapulta*? Hoy caminar es
cinemático (velocidad forzada por código, cuerpo congelado al soltar) y lo
único que interactúa con el terreno es el impulso. De esa decisión depende si
la stamina y el impulso quedan como están.

## 4. La stamina

Una barra. La gasta el impulso (60 de 100 a barra llena); la repone la basura
tirada por el mapa (20 por pieza). Caminar es gratis.

Es lo que obliga a desviarse de la línea recta: para poder saltar el hueco que
viene hay que haber juntado antes.

**Abierto:** hoy no aprieta. Hay 16 piezas por mapa (320 de recarga) contra un
tanque de 100, y caminar gratis siempre alcanza. O caminar cuesta algo, o el
impulso es la única forma de pasar ciertos sitios.

## 5. El mapa

Escenario real por fotogrametría, no terreno generado. Hoy: un muelle con un
barco, galpones y grúas. La malla trae su propio relieve y sus obstáculos, así
que el diseño de nivel es **dónde se pone la salida, dónde la camioneta y qué
hay en el medio**, no esculpir terreno.

Del glb se leen dos cosas por nombre:

- la malla `jaula` marca **dónde arranca** el piche (posición y giro tal cual
  los dejó el artista; el marcador `Salida` de `escenas/mapas/Muelle.tscn` la sigue),
- la malla `CAMIONETA` es **la meta**.

Un mapa sin `CAMIONETA` no se puede terminar y avisa por consola.

**Abierto:** cuántos mapas y cuáles. Hoy hay uno.

## 6. Lo que hay en el medio

- **Basura**: recarga stamina. Está sembrada por el camino de la salida a la
  meta, hasta 22 m a los costados.
- **Fauna**: animales que pastan y salen corriendo si el piche pasa rápido
  cerca. Atropellarlos los deja **aturdidos, no muertos**: se levantan y se
  van. No cuesta nada — el juego no va de lastimar bichos.

**Abierto, y es el hueco grande:** no hay ninguna amenaza. Nada te puede
atrapar, herir ni frenar; caerse del mapa te devuelve gratis al punto anterior.
Un juego sobre escaparse necesita algo de lo que escaparse.

## 7. Lo que NO es este juego

- No es golf. No hay par, ni golpes, ni tarjeta, ni copa, ni bandera, ni
  calle/rough/green. Se sacó todo en agosto de 2026.
- No hay marcador. Terminar el mapa no da puntos: te lleva al siguiente.
- No hay tienda, ni desbloqueos, ni monedas, ni multijugador.
- No hay muerte por ahora. Si algún día la hay, el reintento arranca en el
  mapa, no en la partida.
