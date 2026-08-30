# Que lo que suena sea lo que esta escrito: se saca el croma de cada compas y
# se compara con el acorde del plan. Un charango desafinado o un arpegio que
# coge notas de fuera del acorde se ven aqui y no en un espectrograma.
import numpy as np

SR = 44100
CORCHEA = 0.238095
COMPAS = CORCHEA * 6
NOM = ["do", "do#", "re", "re#", "mi", "fa", "fa#", "sol", "sol#", "la", "la#", "si"]
ACORDES = {"Dm": [2, 5, 9], "Bb": [10, 2, 5], "C": [0, 4, 7],
           "F": [5, 9, 0], "Gm": [7, 10, 2], "A": [9, 1, 4]}
VUELTA = ["Dm", "Dm", "Bb", "C", "Dm", "Bb", "C", "Dm"]
PUENTE = ["F", "F", "C", "C", "Dm", "Bb", "A", "A"]
PLAN = (VUELTA * 2 + PUENTE + VUELTA + PUENTE + VUELTA)[:48]

x = np.fromfile("musica_cruda.f32", dtype=np.float32).reshape(-1, 2).mean(axis=1)

aciertos, fallos = 0, []
for c, acorde in enumerate(PLAN):
    i = int(c * COMPAS * SR)
    n = int(COMPAS * SR)
    seg = x[i:i + n] * np.hanning(n)
    F = np.abs(np.fft.rfft(seg))
    f = np.fft.rfftfreq(n, 1 / SR)
    m = (f > 180) & (f < 2600)          # el registro del charango
    midi = 69 + 12 * np.log2(f[m] / 440.0)
    croma = np.zeros(12)
    np.add.at(croma, np.round(midi).astype(int) % 12, F[m] ** 2)
    croma /= croma.sum()
    top3 = set(np.argsort(croma)[-3:])
    esperado = set(ACORDES[acorde])
    ok = len(top3 & esperado)
    if ok >= 2:
        aciertos += 1
    else:
        fallos.append((c, acorde, [NOM[i] for i in sorted(top3)]))
    if c < 6 or c in (16, 30, 47):
        print("compas %2d  %-3s  esperado %-14s  suena %s"
              % (c, acorde, "/".join(NOM[i] for i in sorted(esperado)),
                 "/".join(NOM[i] for i in sorted(top3))))
print("\n%d/%d compases con al menos 2 de 3 notas del acorde" % (aciertos, len(PLAN)))
for c, a, t in fallos:
    print("  falla compas %d (%s): %s" % (c, a, t))

# afinacion: la desviacion del pico mas fuerte respecto al semitono templado
picos = []
for c in range(0, 48, 4):
    i = int(c * COMPAS * SR)
    n = int(COMPAS * SR)
    F = np.abs(np.fft.rfft(x[i:i + n] * np.hanning(n)))
    f = np.fft.rfftfreq(n, 1 / SR)
    m = (f > 250) & (f < 1400)
    k = np.argmax(F[m])
    hz = f[m][k]
    midi = 69 + 12 * np.log2(hz / 440.0)
    picos.append((midi - round(midi)) * 100)
print("afinacion: desviacion mediana %.1f centesimas, maxima %.1f"
      % (np.median(np.abs(picos)), np.max(np.abs(picos))))
