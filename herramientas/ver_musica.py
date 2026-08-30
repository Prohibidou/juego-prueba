# Verificacion de la pista: costura del bucle, reparto por bandas (ponderado A,
# que es lo que se OYE, no lo que mide un vatimetro) y un espectrograma en PNG,
# que es lo unico que se puede MIRAR sin oido.
import numpy as np, zlib, struct, sys

SR = 44100
x = np.fromfile(sys.argv[1] if len(sys.argv) > 1 else "musica_cruda.f32",
                dtype=np.float32).reshape(-1, 2)
mono = x.mean(axis=1)
n = len(mono)
print("dur %.2f s  pico %.3f  rms %.1f dB" % (n / SR, np.abs(x).max(),
      20 * np.log10(np.sqrt((mono ** 2).mean()))))


def pond_a(f):
    """Ponderacion A: el oido no oye los graves como los mide un FFT."""
    f = np.maximum(f, 1e-6)
    f2 = f ** 2
    num = (12194.0 ** 2) * f2 ** 2
    den = ((f2 + 20.6 ** 2) * np.sqrt((f2 + 107.7 ** 2) * (f2 + 737.9 ** 2))
           * (f2 + 12194.0 ** 2))
    return num / den * 1.2589


# --- costura del bucle: el salto de muestra al empalmar final con principio
salto = abs(mono[0] - mono[-1])
d = np.abs(np.diff(mono))
print("costura: salto %.5f  (mediana interna %.5f, p99.9 interna %.5f)"
      % (salto, np.median(d), np.percentile(d, 99.9)))
w = int(0.25 * SR)
a = np.sqrt((mono[-w:] ** 2).mean())
b = np.sqrt((mono[:w] ** 2).mean())
print("costura: rms 0.25 s antes %.1f dB, despues %.1f dB (dif %+.1f dB)"
      % (20 * np.log10(a), 20 * np.log10(b), 20 * np.log10(b / a)))

# --- reparto por bandas, con y sin ponderar
F = np.abs(np.fft.rfft(mono * np.hanning(n)))
f = np.fft.rfftfreq(n, 1 / SR)
P = F ** 2
Pa = P * pond_a(f) ** 2
print("  banda                bruto   oido(A)")
for lo, hi, nom in [(20, 120, "bombo/grave"), (120, 400, "bajo criolla"),
                    (400, 1200, "cuerpo charango"), (1200, 4000, "brillo charango"),
                    (4000, 12000, "aire/aro"), (12000, 22050, "muy agudo")]:
    m = (f >= lo) & (f < hi)
    print("  %-18s %5.1f %%  %5.1f %%"
          % (nom, 100 * P[m].sum() / P.sum(), 100 * Pa[m].sum() / Pa.sum()))

# --- pulso: energia por corchea, para ver que el 6/8 esta ahi
CORCHEA = 0.238095
paso = int(CORCHEA * SR)
env = np.array([np.sqrt((mono[i:i + paso] ** 2).mean())
                for i in range(0, n - paso, paso)])
pl = env[:len(env) // 6 * 6].reshape(-1, 6).mean(axis=0)
print("perfil de las 6 corcheas del compas: " +
      " ".join("%.2f" % v for v in pl / pl.max()))
# --- y que no haya baches: el bucle tiene que sonar parejo de punta a punta
seg = np.array([np.sqrt((c ** 2).mean()) for c in np.array_split(mono, 24)])
print("rms por 24avo: min %+.1f dB max %+.1f dB (rango %.1f dB)"
      % (20 * np.log10(seg.min()), 20 * np.log10(seg.max()),
         20 * np.log10(seg.max() / seg.min())))

# --- espectrograma a PNG (escrito a mano: no hay matplotlib)
VEN, SAL = 2048, 1024
cols = (n - VEN) // SAL
esp = np.zeros((cols, VEN // 2 + 1))
win = np.hanning(VEN)
for i in range(cols):
    esp[i] = np.abs(np.fft.rfft(mono[i * SAL:i * SAL + VEN] * win))
db = 20 * np.log10(esp + 1e-9)
pico = np.percentile(db, 99.9)
img01 = np.clip((db - (pico - 62)) / 62, 0, 1)      # 62 dB de recorrido util
alto = 340
bins = np.geomspace(2, VEN // 2, alto).astype(int)
img = img01[:, bins].T[::-1]                        # arriba agudos, abajo graves
img = img[:, ::max(1, img.shape[1] // 1200)]
h, w2 = img.shape
# rampa negro -> azul -> naranja -> blanco: fuerte = claro, silencio = negro
v = img
rgb = np.stack([np.clip(1.8 * v - 0.35, 0, 1),
                np.clip(1.9 * v ** 1.7 - 0.15, 0, 1),
                np.clip(1.5 * v ** 0.7 - 0.05, 0, 1) * (1 - 0.55 * v)], axis=-1)
rgb = (rgb * 255).astype(np.uint8)
raw = b"".join(b"\x00" + rgb[i].tobytes() for i in range(h))


def chunk(t, d):
    c = t + d
    return struct.pack(">I", len(d)) + c + struct.pack(">I", zlib.crc32(c))


png = (b"\x89PNG\r\n\x1a\n"
       + chunk(b"IHDR", struct.pack(">IIBBBBB", w2, h, 8, 2, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))
open("espectro.png", "wb").write(png)
print("espectrograma %dx%d -> espectro.png (Y log 42 Hz abajo .. 22 kHz arriba)"
      % (w2, h))
