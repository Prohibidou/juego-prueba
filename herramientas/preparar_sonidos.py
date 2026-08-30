# -*- coding: utf-8 -*-
"""Deja los mp3 de PGJ_Sounds listos para el juego.

Los originales traen aire muerto al principio y al final, y el "Female Jump"
son TRES tomas en un mismo archivo. Aqui se recortan, se separan, se nivelan a
-1 dBFS de pico y se guardan con nombres del proyecto. Los cortos van a WAV
(no se vuelve a comprimir lo ya comprimido y arrancan sin latencia); los
ambientes, que duran mas de un minuto, a OGG.
"""
import subprocess, numpy as np, os, sys

SR = 44100
ORIG = "C:/Users/veram/Downloads/PGJ_Sounds/"
DEST = sys.argv[1] if len(sys.argv) > 1 else "sonidos"
os.makedirs(DEST, exist_ok=True)


def leer(nombre, canales=2):
    raw = subprocess.run(
        ["ffmpeg", "-v", "quiet", "-i", ORIG + nombre, "-f", "f32le",
         "-ac", str(canales), "-ar", str(SR), "-"],
        capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, canales).copy()


def escribir(x, ruta, ogg=False, pico_db=-1.0):
    x = x / max(np.abs(x).max(), 1e-9) * 10 ** (pico_db / 20.0)
    cmd = ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR),
           "-ac", str(x.shape[1]), "-i", "-"]
    cmd += ["-c:a", "libvorbis", "-q:a", "5"] if ogg else ["-c:a", "pcm_s16le"]
    subprocess.run(cmd + [ruta], input=x.astype(np.float32).tobytes(), check=True)
    print("  %-26s %6.2f s  %s" % (os.path.basename(ruta), len(x) / SR,
                                   "ogg" if ogg else "wav 16 bit"))


def recorte(x, ini, fin, entra=0.004, sale=0.03):
    """Corta y pone rampas: sin ellas, cortar a mitad de onda hace un clic."""
    y = x[int(ini * SR):int(fin * SR)].copy()
    a, b = int(entra * SR), int(sale * SR)
    y[:a] *= np.linspace(0, 1, a)[:, None]
    y[-b:] *= np.linspace(1, 0, b)[:, None]
    return y


print("cortos:")
# El grunido del piche al impulsarse. Los primeros 40 ms son silencio.
escribir(recorte(leer("esfuerzodesaltopiche.mp3"), 0.04, 0.27),
         f"{DEST}/impulso.wav")

# "Female Jump" son tres tomas de salto+caida en un solo archivo (0.11/1.70/3.37).
# Se queda solo la parte del salto de cada una: tres variantes para que el
# brinco no suene identico veinte veces seguidas.
salto = leer("Female Jump Videogame Sound FX.mp3")
for i, (a, b) in enumerate([(0.08, 0.58), (1.66, 2.14), (3.33, 3.79)], 1):
    escribir(recorte(salto, a, b), f"{DEST}/salto_{i}.wav")

escribir(recorte(leer("impactocaidaimpulsogrande.mp3"), 0.06, 1.00),
         f"{DEST}/aterrizaje.wav")
escribir(recorte(leer("abrirjaula.mp3"), 0.05, 2.60), f"{DEST}/jaula.wav")
# El splash empieza a 1.14 y se acaba a 3.92; el resto del archivo es silencio.
escribir(recorte(leer("Water Splash Sound Effect  Free Clip Sounds  Ambient Sounds.mp3"),
                 1.10, 3.95), f"{DEST}/chapuzon.wav")
escribir(recorte(leer("tocarbotonmenu.mp3"), 0.08, 0.30, 0.002, 0.02),
         f"{DEST}/boton.wav")

# El giro en el aire suena mientras el piche vuela, o sea en bucle: hay que
# cerrarlo. Se solapa la cola sobre la cabeza, y asi el empalme no chasquea.
giro = leer("girarenelaire.mp3")
CF = int(0.45 * SR)
cuerpo = giro[int(0.12 * SR):int(3.00 * SR)].copy()
rampa = np.linspace(0, 1, CF)[:, None]
cuerpo[:CF] = cuerpo[:CF] * rampa + cuerpo[-CF:] * (1 - rampa)
escribir(cuerpo[:-CF], f"{DEST}/vuelo.wav")

print("ambientes:")
# Se dejan largos y sin recortar: son camas y cuanto mas tardan en repetirse,
# menos se nota el bucle. Bajos de nivel a proposito, que van por debajo de todo.
escribir(leer("sea waves [calm sound of waves in the sea] NO COPYRIGHT.mp3"),
         f"{DEST}/olas.ogg", ogg=True, pico_db=-6.0)
escribir(leer("Seagull Sounds _ Royalty Free Sound Effects.mp3"),
         f"{DEST}/gaviotas.ogg", ogg=True, pico_db=-6.0)

print("musica:")
SC = os.path.dirname(os.path.abspath(__file__))
mus = np.fromfile(SC + "/musica_cruda.f32", dtype=np.float32).reshape(-1, 2)
escribir(mus, f"{DEST}/musica.ogg", ogg=True, pico_db=-3.0)
