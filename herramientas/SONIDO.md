# De donde sale cada sonido

Los `.wav` y `.ogg` de `sonidos/` son ARTEFACTOS: no se editan a mano, se
vuelven a generar. Aca esta como.

## Los efectos y el ambiente

Vienen de `PGJ_Sounds` (los mp3 que paso el equipo). `preparar_sonidos.py` los
recorta, los separa y los nivela:

```
python herramientas/preparar_sonidos.py sonidos
```

Lo que hace, y por que:

- Casi todos traen aire muerto delante y detras. Se recortan al tramo con
  sonido, con rampas de pocos milisegundos: cortar a mitad de onda hace un clic.
- **`Female Jump Videogame Sound FX.mp3` son TRES tomas en un archivo**
  (salto+caida a 0.11, 1.70 y 3.37 s). Se separa la parte del salto de cada una
  y salen `salto_1..3.wav`. En el juego van dentro de un `AudioStreamRandomizer`
  sin repeticion, para que veinte brincos seguidos no suenen iguales.
- `girarenelaire.mp3` suena EN BUCLE mientras el piche vuela, asi que hay que
  cerrarlo: se solapa la cola sobre la cabeza (450 ms) y se corta esa cola. Sin
  eso el empalme chasquea cada 2.4 s.
- El splash empieza a 1.14 s y se acaba a 3.92; el resto del archivo son cuatro
  segundos de nada.
- Los cortos van a WAV: no se vuelve a comprimir lo ya comprimido y arrancan sin
  latencia. Los ambientes, que pasan del minuto, a OGG.

Los bucles NO estan en el codigo, estan en el `.import` de cada archivo
(`loop=true` en los ogg, `edit/loop_mode=2` en `vuelo.wav`). Es lo primero que se
pierde en una reimportacion, por eso `_self_check()` de `juego.gd` lo comprueba.

## La musica

`sonidos/musica.ogg` no viene de ningun lado: se sintetiza entera con
`musica_patagonia.py`, que no necesita mas que numpy.

```
python herramientas/musica_patagonia.py        # deja musica_cruda.f32
python herramientas/ver_musica.py              # bandas, costura del bucle, pulso
python herramientas/ver_armonia.py             # que suene lo que esta escrito
```

Que es: **6/8 a 84, re menor, 48 compases = 68.57 s de bucle exacto.** Charango
(el arpegio no calla nunca), bajo de guitarra criolla, bombo leguero apoyando en
1 y en 4 al modo del loncomeo, quena en los puentes y una cama de viento debajo.
El la mayor prestado del menor armonico -ese do sostenido- es lo que lo aparta
del pop y lo acerca al folclore.

Como esta hecho, por si hay que tocarlo:

- Las cuerdas son Karplus-Strong por periodos, vectorizado en numpy. El retardo
  es FRACCIONARIO: con el entero, un mi6 se iba 22 centesimas y el charango
  sonaba desafinado contra el bajo. Medido: 2.1 centesimas de desvio mediano.
- El charango son DOS cuerdas por orden, una desafinada unas centesimas y
  retrasada unos milisegundos. Ese batido es la mitad del timbre.
- El bucle no tiene costura porque se renderiza con 4 s de cola y todo lo que
  suena pasado el final -notas y reverb- se suma sobre el principio.

Dos cosas que ya salieron mal y estan resueltas, para no repetirlas:

- **Los cuatro primeros compases sin bombo** parecian una intro bonita, pero en
  un bucle son un bache de 5.7 s cada vuelta: la costura medía -4.8 dB de salto.
  En un bucle no hay intro que valga. Ahora el bombo entra desde el compas 1 y el
  salto es +0.7 dB.
- **El bombo a 0.52 se comia el 54 % de la energia** y la mezcla retumbaba; el
  charango quedaba detras de su propio acompanamiento, que es justo lo contrario
  de lo que se pidio. Con 0.40 el charango se lleva el 92 % de lo que se OYE
  (ponderado A) y el bombo se sigue sintiendo.

`ver_musica.py` imprime esos numeros y ademas escribe un espectrograma en PNG.
Los que importan: la costura (el salto tiene que quedar por debajo del p99.9
interno), el reparto por bandas y el perfil de las seis corcheas, que tiene que
acentuar la 1 y la 4 -es lo que hace que sea un 6/8 y no una pulsacion plana-.
