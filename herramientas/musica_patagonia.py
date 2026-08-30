# -*- coding: utf-8 -*-
"""Pista ambiental de Golfito: folclore patagonico, charango siempre presente.

6/8 a 84 (negra con puntillo), re menor, 48 compases = 68.6 s en bucle exacto.
La cola de reverb y las notas que pasan del final se doblan sobre el principio,
asi que el bucle no tiene costura.
"""
import numpy as np

SR = 44100
RNG = np.random.default_rng(20260830)

CORCHEA = 0.238095          # segundos; compas de 6/8 = 1.428571 s
COMPAS = CORCHEA * 6
COMPASES = 48
LARGO = int(round(COMPASES * COMPAS * SR))
COLA = int(4.0 * SR)        # margen para que resuenen las ultimas notas
buf = {k: np.zeros(LARGO + COLA, dtype=np.float32) for k in
       ("charango", "bajo", "bombo", "quena", "aire")}


def nota_hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def filtro(x, tipo, fc, orden=2, fc2=None):
    """Filtro de fase cero en frecuencia. Vale para diseno de sonido."""
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    if tipo == "lp":
        h = 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * orden))
    elif tipo == "hp":
        h = 1.0 / np.sqrt(1.0 + (fc / np.maximum(f, 1e-6)) ** (2 * orden))
    else:  # bp
        alto = fc2 if fc2 else fc * 1.6
        h = (1.0 / np.sqrt(1.0 + (fc / np.maximum(f, 1e-6)) ** (2 * orden))
             * 1.0 / np.sqrt(1.0 + (f / alto) ** (2 * orden)))
    return np.fft.irfft(X * h, n)


def mezclar(pista, x, t):
    i = int(round(t * SR))
    j = min(i + len(x), LARGO + COLA)
    if j > i:
        buf[pista][i:j] += x[:j - i].astype(np.float32)


# ---------------------------------------------------------------------------
# Cuerdas pulsadas: Karplus-Strong por periodos, que en numpy va vectorizado.
# El retardo fraccionario afina de verdad; con el entero, un mi6 se iba 22
# centesimas y el charango sonaba desafinado contra el bajo.
# ---------------------------------------------------------------------------

def pulsada(hz, dur, decaim=0.9965, brillo=0.5, nivel=1.0):
    d = SR / hz
    L = max(2, int(np.floor(d)))
    f = d - L                          # parte fraccionaria del retardo
    n = int(dur * SR)
    exc = RNG.uniform(-1.0, 1.0, L)
    exc = filtro(exc, "lp", hz * (6.0 + 10.0 * brillo))
    exc -= exc.mean()                  # sin continua: si no, la nota empuja
    prev, arrastre = exc.copy(), exc[-1]
    trozos, total = [exc], L
    while total < n:
        corrido = np.concatenate(([arrastre], prev[:-1]))
        arrastre = prev[-1]
        prev = decaim * ((1.0 - f) * prev + f * corrido)
        # el promedio de dos muestras ya es el filtro paso bajo del algoritmo;
        # este segundo tap ajusta el brillo sin tocar la afinacion
        prev = brillo * prev + (1.0 - brillo) * np.concatenate(([prev[0]], prev[:-1]))
        trozos.append(prev)
        total += L
    y = np.concatenate(trozos)[:n]
    ata = np.minimum(1.0, np.arange(n) / (0.0015 * SR))       # sin clic
    sal = np.minimum(1.0, (n - np.arange(n)) / (0.02 * SR))
    return y * ata * sal * nivel


def charango(midi, dur, nivel=1.0):
    """Un orden del charango: dos cuerdas casi iguales. Ese leve desfase y la
    desafinacion de unas pocas centesimas son la mitad del timbre."""
    a = pulsada(nota_hz(midi), dur, 0.9955, 0.62, 1.0)
    b = pulsada(nota_hz(midi + RNG.uniform(-0.055, 0.055)), dur, 0.9950, 0.58, 0.85)
    ret = int(RNG.uniform(0.004, 0.009) * SR)                 # la segunda, despues
    y = a.copy()
    y[ret:] += b[:len(b) - ret]
    y = filtro(y, "hp", 180.0)          # el charango no tiene graves: es chico
    return y * nivel


def criolla(midi, dur, nivel=1.0):
    """Guitarra criolla para los bajos: mas oscura y mas larga que el charango."""
    y = pulsada(nota_hz(midi), dur, 0.9988, 0.34, 1.0)
    return filtro(y, "lp", 2200.0) * nivel


# ---------------------------------------------------------------------------
# Bombo leguero: parche grave con caida de tono, y aro (el palo en el borde).
# ---------------------------------------------------------------------------

def parche(nivel=1.0, dur=0.55):
    n = int(dur * SR)
    t = np.arange(n) / SR
    hz = 48.0 + 52.0 * np.exp(-t / 0.035)
    cuerpo = np.sin(2 * np.pi * np.cumsum(hz) / SR) * np.exp(-t / 0.13)
    golpe = filtro(RNG.uniform(-1, 1, n), "lp", 700.0) * np.exp(-t / 0.012)
    madera = filtro(RNG.uniform(-1, 1, n), "bp", 190.0, 2, 520.0) * np.exp(-t / 0.06)
    return filtro(cuerpo + 0.42 * golpe + 0.45 * madera, "hp", 45.0) * nivel


def aro(nivel=1.0, dur=0.09):
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = filtro(RNG.uniform(-1, 1, n), "bp", 1700.0, 2, 5200.0)
    return y * np.exp(-t / 0.014) * nivel


# ---------------------------------------------------------------------------
# Quena: sopla aire de verdad, no es solo un seno.
# ---------------------------------------------------------------------------

def quena(midi, dur, nivel=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    hz = nota_hz(midi)
    vib = 1.0 + 0.0045 * np.sin(2 * np.pi * 5.2 * t) * np.minimum(1.0, t / 0.35)
    ph = 2 * np.pi * hz * np.cumsum(vib) / SR
    tono = (np.sin(ph) + 0.30 * np.sin(2 * ph) + 0.10 * np.sin(3 * ph)
            + 0.04 * np.sin(4 * ph))
    soplo = filtro(RNG.uniform(-1, 1, n), "bp", hz * 1.6, 2, hz * 5.0)
    env = np.minimum(1.0, t / 0.075) ** 1.5
    env = env * np.minimum(1.0, (dur - t) / 0.22)
    env = np.clip(env, 0.0, 1.0)
    return (0.72 * tono + 0.30 * soplo) * env * nivel


# ---------------------------------------------------------------------------
# Armonia. Re menor con el la mayor prestado del menor armonico: ese do
# sostenido es el giro que suena andino y no pop.
# ---------------------------------------------------------------------------

ACORDES = {
    "Dm": [2, 5, 9], "Bb": [10, 2, 5], "C": [0, 4, 7],
    "F": [5, 9, 0], "Gm": [7, 10, 2], "A": [9, 1, 4],
}
VUELTA = ["Dm", "Dm", "Bb", "C", "Dm", "Bb", "C", "Dm"]
PUENTE = ["F", "F", "C", "C", "Dm", "Bb", "A", "A"]
PLAN = (VUELTA * 2 + PUENTE + VUELTA + PUENTE + VUELTA)[:COMPASES]


def voces(nombre, grave=67, agudo=88):
    """Reparte el acorde por el registro del charango, de grave a agudo."""
    ns = []
    for pc in ACORDES[nombre]:
        m = grave + ((pc - grave) % 12)
        while m <= agudo:
            ns.append(m)
            m += 12
    return sorted(ns)


RAIZ = {"Dm": 38, "Bb": 34, "C": 36, "F": 29, "Gm": 31, "A": 33}

# arpegios de 6 corcheas: indices dentro del acorde repartido
ARPEGIOS = [
    [0, 2, 4, 1, 3, 5],
    [0, 3, 2, 4, 3, 5],
    [0, 2, 3, 1, 4, 2],
    [0, 4, 2, 5, 3, 4],
]

for c in range(COMPASES):
    t0 = c * COMPAS
    acorde = PLAN[c]
    notas = voces(acorde)
    while len(notas) < 6:
        notas.append(notas[-1] + 12)

    # --- charango: no calla nunca, es el hilo de toda la pista ---
    arp = ARPEGIOS[(c // 2) % len(ARPEGIOS)]
    for k in range(6):
        m = notas[arp[k] % len(notas)]
        # el 1 y el 4 marcan el 6/8; las demas, mas flojas
        v = 0.62 if k in (0, 3) else 0.34
        v = v * RNG.uniform(0.88, 1.12)
        # empuje: las corcheas debiles llegan un pelo tarde, como una mano
        tr = 0.0 if k in (0, 3) else RNG.uniform(0.004, 0.013)
        mezclar("charango", charango(m, 1.5, v), t0 + k * CORCHEA + tr)
    # rasgueo: la mano barre el acorde entero en 25 ms
    if c % 2 == 1:
        for i, m in enumerate(notas[:5]):
            mezclar("charango", charango(m, 1.9, 0.40 * (0.75 + 0.06 * i)),
                    t0 + 3 * CORCHEA + i * 0.006)
    if c % 8 == 7:      # cierre de vuelta: rasgueo a contratiempo
        for i, m in enumerate(reversed(notas[:5])):
            mezclar("charango", charango(m, 1.4, 0.30),
                    t0 + 5 * CORCHEA + i * 0.007)

    # --- bajo de criolla: fundamental en 1, quinta en 4 ---
    r = RAIZ[acorde]
    mezclar("bajo", criolla(r, 1.6, 0.50), t0)
    mezclar("bajo", criolla(r + 7, 1.3, 0.30), t0 + 3 * CORCHEA)
    if c % 4 == 3:
        mezclar("bajo", criolla(r + 12, 0.9, 0.22), t0 + 5 * CORCHEA)

    # --- bombo leguero: el loncomeo apoya en 1 y en 4, con fantasma en 3 ---
    # El bombo no se toma vacaciones: con los cuatro primeros compases sin
    # parche, cada vuelta del bucle abria un bache de 5.7 s (-4.8 dB) que se
    # oia como un corte. En un bucle no hay intro que valga.
    if True:
        mezclar("bombo", parche(0.92), t0)
        mezclar("bombo", parche(0.78), t0 + 3 * CORCHEA)
        mezclar("bombo", parche(0.26), t0 + 2 * CORCHEA)
        for k, v in ((1, 0.42), (2, 0.18), (4, 0.46), (5, 0.34)):
            mezclar("bombo", aro(v), t0 + k * CORCHEA)
        if c % 8 == 7:                       # repique de cierre
            for k in range(3):
                mezclar("bombo", parche(0.34 + 0.12 * k, 0.3),
                        t0 + 4 * CORCHEA + k * CORCHEA * 0.5)

# --- quena: entra en el puente, frases cortas y con aire entre medio ---
FRASE = [  # (compas, corchea, midi, corcheas de duracion)
    (16, 0, 74, 3), (16, 3, 72, 3), (17, 0, 69, 4), (17, 4, 72, 2),
    (18, 0, 74, 2), (18, 2, 76, 4), (19, 0, 74, 6),
    (20, 0, 77, 3), (20, 3, 76, 3), (21, 0, 74, 4), (21, 4, 72, 2),
    (22, 0, 69, 3), (22, 3, 71, 3), (23, 0, 69, 6),
    (32, 0, 81, 3), (32, 3, 79, 3), (33, 0, 77, 4), (33, 4, 76, 2),
    (34, 0, 74, 2), (34, 2, 76, 4), (35, 0, 77, 6),
    (36, 0, 76, 3), (36, 3, 74, 3), (37, 0, 72, 4), (37, 4, 74, 2),
    (38, 0, 73, 3), (38, 3, 76, 3), (39, 0, 74, 6),
]
for cc, k, m, largo in FRASE:
    mezclar("quena", quena(m, largo * CORCHEA * 0.92, 0.30),
            cc * COMPAS + k * CORCHEA)

# --- aire: viento de meseta, muy por debajo de todo. No es una nota, es sitio ---
viento = filtro(RNG.uniform(-1, 1, LARGO + COLA), "bp", 700.0, 1, 3400.0)
lento = np.interp(np.arange(LARGO + COLA),
                  np.linspace(0, LARGO + COLA, 40),
                  RNG.uniform(0.25, 1.0, 40))
buf["aire"] += viento * lento * 0.018

# ---------------------------------------------------------------------------
# Mezcla, reverb y cierre del bucle.
# ---------------------------------------------------------------------------

# El charango manda: es lo que pidio el encargo y lo que lleva la pista. El
# bombo apoya. Con bombo 0.52 se comia el 54 % de la energia y la mezcla
# retumbaba; el charango quedaba detras de su propio acompanamiento.
NIVEL = {"charango": 0.86, "bajo": 0.50, "bombo": 0.40, "quena": 0.52, "aire": 1.0}
seco = np.zeros(LARGO + COLA, dtype=np.float32)
for k in list(buf):
    seco += buf[k] * np.float32(NIVEL[k])
    buf[k] = None          # se suelta en cuanto se usa: la RAM esta justa

# reverb: ruido que decae, como la sala. Corto, que esto acompana y no envuelve.
ir_n = int(1.5 * SR)
t_ir = np.arange(ir_n) / SR
ir = RNG.uniform(-1, 1, ir_n) * np.exp(-t_ir / 0.42)
ir = filtro(ir, "lp", 4200.0)
ir[:int(0.012 * SR)] = 0.0
ir = ir / np.sqrt((ir ** 2).sum())
BLOQUE = 1 << 16
n_fft = 1 << int(np.ceil(np.log2(BLOQUE + ir_n)))
IR = np.fft.rfft(ir, n_fft)
mezcla = np.zeros(len(seco) + ir_n, dtype=np.float32)
mezcla[:len(seco)] += seco
for i in range(0, len(seco), BLOQUE):
    trozo = seco[i:i + BLOQUE]
    y = np.fft.irfft(np.fft.rfft(trozo, n_fft) * IR, n_fft)[:len(trozo) + ir_n]
    mezcla[i:i + len(y)] += (y * 0.30).astype(np.float32)
    del y
del IR

# El bucle: todo lo que suena pasado el final vuelve al principio. Sin esto se
# oye el corte cada 68 s, que es exactamente lo que no puede pasar en un bucle.
sobra = len(mezcla) - LARGO
mezcla[:sobra] += mezcla[LARGO:]
mezcla = mezcla[:LARGO]

mezcla = filtro(mezcla, "hp", 35.0)
mezcla = mezcla / np.abs(mezcla).max()

# estereo: una copia retardada abre la imagen sin descolocar el bombo
ret = int(0.010 * SR)
der = np.zeros_like(mezcla)
der[ret:] = mezcla[:-ret] * 0.55
der = der + mezcla * 0.45
est = np.stack([mezcla * 0.85 + der * 0.15, der * 0.85 + mezcla * 0.15], axis=1)
est = est / np.abs(est).max() * 10 ** (-3.0 / 20.0)   # -3 dBFS: el juego lo baja mas

est.astype(np.float32).tofile("musica_cruda.f32")
print("compases %d, %.2f s, pico %.3f, rms %.1f dB"
      % (COMPASES, LARGO / SR, np.abs(est).max(),
         20 * np.log10(np.sqrt((est ** 2).mean()))))
