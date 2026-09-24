#!/usr/bin/env python3
"""
Gera hardware/tiras.svg - o layout dos componentes na placa de TIRAS
(estilo protoboard: linhas horizontais de 5 furos separadas por dois trilhos
verticais centrais).

A ideia do layout: os dois trilhos centrais viram GND e VCC, e os conectores
dos sensores montam a cavalo sobre eles - os dois pinos do meio caem direto
na alimentacao, sem um unico jumper de forca. Pro Micro e TCA9548A tambem
montam a cavalo, com uma fileira de pernas em cada metade.

Este desenho NAO e 1:1 (o de 1:1 e o perfurada.svg, da placa lisa). Aqui o
passo e esticado para caber rotulo legivel; localize tudo pelas linhas
numeradas, que a propria placa traz serigrafadas.

    python hardware/gerar_tiras.py
"""

from pathlib import Path

# ------------------------------------------------------------------ geometria
COLS, ROWS = 12, 40        # A..L  x  1..40
PITCH = 7.0                # passo de desenho, nao de fabricacao
ML, MT, MB = 16, 24, 26    # margens: reguas e rotulos dos trilhos
PAD = 6                    # folga do painel da placa
LEG_W = 196                # coluna da legenda

# colunas (0-based): A-E = tira esquerda, F = GND, G = VCC, H-L = tira direita
STRIP_L = (0, 4)
RAIL_GND, RAIL_VCC = 5, 6
STRIP_R = (7, 11)

W = ML + COLS * PITCH + PAD + LEG_W
H = MT + ROWS * PITCH + MB

# --------------------------------------------------------------------- cores
PAPEL, FURO, LETRA, TINTA = "#f7f2e4", "#9a8e70", "#8a7f66", "#2b2b2b"
COBRE = "#b08d57"
C_GND, C_VCC, C_SDA, C_SCL = "#334155", "#d64545", "#e0921f", "#2f80d6"
C_PM, C_MUX, C_CON = "#2f80d6", "#7c5cd6", "#159a6b"
MONO = "ui-monospace, Consolas, monospace"

# ------------------------------------------------------------------ ocupacao
PM_ROW, PM_CL, PM_CR = 2, 3, 9          # Pro Micro: pernas nas colunas D e J
PM_L = ["TX0", "RX1", "GND", "GND", "2 SDA", "3 SCL",
        "4", "5", "6", "7", "8", "9"]
PM_R = ["RAW", "GND", "RST", "VCC", "A3", "A2", "A1", "A0",
        "15", "14", "16", "10"]
PM_L_FORA = {2}                          # rotulos que saem do corpo p/ nao
PM_R_FORA = {3}                          # bater no jumper de alimentacao

# Dois capacitores em paralelo, cada um na sua linha - os dois atravessam
# F e G, e os trilhos ja os poem em paralelo.
CAPS = [(14, "10 uF  (tarja em F)", True), (15, "100 nF  ceramico", False)]

# HW-617: 24 pinos, 12 por lado. Os canais 0 e 1 saem do MESMO lado dos
# pinos de controle; do outro lado, SD2/SC2 sobem ate SC7 (ordem invertida).
MUX_ROW, MUX_CL, MUX_CR = 18, 3, 9
MUX_L = ["VIN", "GND", "SCL", "SDA", "RST", "A0", "A1", "A2",
         "SD0", "SC0", "SD1", "SC1"]
# ...e esse lado corre ao contrario: SD2 embaixo, subindo ate SC7 no topo.
MUX_R = ["SC7", "SD7", "SC6", "SD6", "SC5", "SD5", "SC4", "SD4",
         "SC3", "SD3", "SC2", "SD2"]
MUX_L_FORA = {0, 1, 5, 6, 7}

JST_C0 = 4                               # pinos nas colunas E F G H
JSTS = [(32, "LEME", "canal 0", "SD0", "SC0"),
        (35, "FREIO ESQ", "canal 1", "SD1", "SC1"),
        (38, "FREIO DIR", "canal 2", "SD2", "SC2")]


def col_name(i):
    return chr(65 + i)


def cx(c):
    return ML + PITCH / 2 + c * PITCH


def cy(r):
    return MT + PITCH / 2 + r * PITCH


def txt(x, y, s, size=4.0, anchor="middle", fill=LETRA, weight="400", halo=True):
    h = (f'paint-order="stroke" stroke="{PAPEL}" stroke-width="{size * .5:.2f}" '
         f'stroke-linejoin="round" ') if halo else ""
    return (f'<text x="{x:.2f}" y="{y:.2f}" text-anchor="{anchor}" font-size="{size}" '
            f'fill="{fill}" font-weight="{weight}" {h}>{s}</text>')


def wire(c1, r1, c2, r2, color, width=1.9):
    """Jumper: risco com halo de papel, para ler como fio por cima da placa."""
    x1, y1, x2, y2 = cx(c1), cy(r1), cx(c2), cy(r2)
    return (f'<line x1="{x1:.2f}" y1="{y1:.2f}" x2="{x2:.2f}" y2="{y2:.2f}" '
            f'stroke="{PAPEL}" stroke-width="{width + 2.4:.2f}" stroke-linecap="round"/>'
            f'<line x1="{x1:.2f}" y1="{y1:.2f}" x2="{x2:.2f}" y2="{y2:.2f}" '
            f'stroke="{color}" stroke-width="{width}" stroke-linecap="round"/>'
            f'<circle cx="{x1:.2f}" cy="{y1:.2f}" r="1.7" fill="{color}"/>'
            f'<circle cx="{x2:.2f}" cy="{y2:.2f}" r="1.7" fill="{color}"/>')


def hop(c1, c2, r, color, width=1.9):
    """Jumper que pula por cima de um trilho: arco, para nao parecer solda."""
    x1, x2, y = cx(c1), cx(c2), cy(r)
    d = (f'M {x1:.2f} {y:.2f} Q {(x1 + x2) / 2:.2f} {y - PITCH * .8:.2f} '
         f'{x2:.2f} {y:.2f}')
    return (f'<path d="{d}" fill="none" stroke="{PAPEL}" stroke-width="{width + 2.4:.2f}" '
            f'stroke-linecap="round"/>'
            f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{width}" '
            f'stroke-linecap="round"/>'
            f'<circle cx="{x1:.2f}" cy="{y:.2f}" r="1.7" fill="{color}"/>'
            f'<circle cx="{x2:.2f}" cy="{y:.2f}" r="1.7" fill="{color}"/>')


def corpo(row, n, cl, cr, label, color):
    """Contorno tracejado do modulo, desenhado ANTES dos trilhos: os trilhos
    passam por baixo do corpo, e nenhuma perna encosta neles."""
    x, y = cx(cl) - PITCH * .75, cy(row) - PITCH * .75
    w, h = cx(cr) - cx(cl) + PITCH * 1.5, (n - 1) * PITCH + PITCH * 1.5
    return (f'<rect x="{x:.2f}" y="{y:.2f}" width="{w:.2f}" height="{h:.2f}" rx="3" '
            f'fill="{color}" fill-opacity=".07" stroke="{color}" stroke-width="1" '
            f'stroke-dasharray="3 2.4"/>')


def titulo(row, label, color):
    """Nome do modulo sobre a tira da direita - nunca em cima dos trilhos,
    e desenhado depois deles para nao ficar por baixo."""
    return txt(cx(7) - 3, cy(row) - PITCH * .75 - 3.4, label, 5.0,
               anchor="start", fill=color, weight="700")


def pernas(row, n, cl, cr, esq, dir_, fora_l, fora_r, color):
    """Pinos e rotulos. Por padrao o nome fica dentro do corpo; nas linhas que
    levam jumper ele sai para fora, para nao brigar com o fio."""
    p = []
    for i in range(n):
        r = row + i
        for c, nome, dentro, fora in (
                (cl, esq[i], i not in fora_l, "esq"),
                (cr, dir_[i], i not in fora_r, "dir")):
            p.append(f'<circle cx="{cx(c):.2f}" cy="{cy(r):.2f}" r="2.1" fill="{color}"/>')
            if fora == "esq":
                x, anchor = (cx(c) + 3.4, "start") if dentro else (cx(c) - 6.5, "end")
            else:
                x, anchor = (cx(c) - 3.4, "end") if dentro else (cx(c) + 6.5, "start")
            p.append(txt(x, cy(r) + 1.4, nome, 3.7, anchor=anchor, fill=color,
                         weight="700"))
    return p


def build() -> str:
    p = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W:.0f}" height="{H:.0f}" '
         f'viewBox="0 0 {W:.2f} {H:.2f}" font-family="{MONO}">',
         "<title>Open Rudder - layout na placa de tiras</title>",
         f'<rect width="{W:.2f}" height="{H:.2f}" fill="#fffdf7"/>',
         f'<rect x="{cx(0) - PITCH / 2 - PAD:.2f}" y="{cy(0) - PITCH / 2 - PAD:.2f}" '
         f'width="{COLS * PITCH + PAD * 2:.2f}" height="{ROWS * PITCH + PAD * 2:.2f}" '
         f'rx="4" fill="{PAPEL}" stroke="#b9a67c" stroke-width="1"/>']

    # ---- cobre: tiras horizontais de 5 furos
    for r in range(ROWS):
        for a, b in (STRIP_L, STRIP_R):
            p.append(f'<rect x="{cx(a) - 3.1:.2f}" y="{cy(r) - 3.1:.2f}" '
                     f'width="{cx(b) - cx(a) + 6.2:.2f}" height="6.2" rx="3.1" '
                     f'fill="{COBRE}" fill-opacity=".20"/>')

    # ---- corpo dos modulos (os trilhos passam por cima, depois)
    p.append(corpo(PM_ROW, 12, PM_CL, PM_CR, "Pro Micro", C_PM))
    p.append(corpo(MUX_ROW, 12, MUX_CL, MUX_CR, "TCA9548A", C_MUX))

    # ---- os dois trilhos verticais, contínuos por baixo dos modulos
    for col, cor in ((RAIL_GND, C_GND), (RAIL_VCC, C_VCC)):
        p.append(f'<rect x="{cx(col) - 3.1:.2f}" y="{cy(0) - 3.1:.2f}" width="6.2" '
                 f'height="{(ROWS - 1) * PITCH + 6.2:.2f}" rx="3.1" fill="{cor}"/>')

    # ---- furos
    for r in range(ROWS):
        for c in range(COLS):
            claro = c in (RAIL_GND, RAIL_VCC)
            p.append(f'<circle cx="{cx(c):.2f}" cy="{cy(r):.2f}" r="1.25" '
                     f'fill="{PAPEL if claro else "none"}" '
                     f'stroke="{"none" if claro else FURO}" stroke-width=".5"/>')

    p.append(titulo(PM_ROW, "Pro Micro", C_PM))
    p.append(titulo(MUX_ROW, "TCA9548A", C_MUX))

    # ---- alimentacao: cada trilho recebe pelo lado que fica de frente p/ ele
    p.append(wire(4, PM_ROW + 2, RAIL_GND, PM_ROW + 2, C_GND))
    p.append(wire(7, PM_ROW + 3, RAIL_VCC, PM_ROW + 3, C_VCC))
    p.append(wire(4, MUX_ROW + 1, RAIL_GND, MUX_ROW + 1, C_GND))
    p.append(hop(4, RAIL_VCC, MUX_ROW, C_VCC))          # VIN e o unico que pula
    for i in (5, 6, 7):                                 # A0 A1 A2 -> GND
        p.append(wire(4, MUX_ROW + i, RAIL_GND, MUX_ROW + i, C_GND))

    # ---- I2C do mux para o Pro Micro: os dois pinos ficam do lado esquerdo
    p.append(wire(1, MUX_ROW + 3, 1, PM_ROW + 4, C_SDA))
    p.append(wire(0, MUX_ROW + 2, 0, PM_ROW + 5, C_SCL))

    # ---- pernas e rotulos
    p += pernas(PM_ROW, 12, PM_CL, PM_CR, PM_L, PM_R, PM_L_FORA, PM_R_FORA, C_PM)
    p += pernas(MUX_ROW, 12, MUX_CL, MUX_CR, MUX_L, MUX_R, MUX_L_FORA, set(), C_MUX)

    # ---- desacoplamento atravessando os trilhos
    for row, rotulo, polarizado in CAPS:
        p.append(f'<rect x="{cx(RAIL_GND) - 4:.2f}" y="{cy(row) - 3.4:.2f}" '
                 f'width="{PITCH + 8:.2f}" height="6.8" rx="3.2" fill="#fff" '
                 f'stroke="{TINTA}" stroke-width=".8"/>')
        if polarizado:
            p.append(txt(cx(RAIL_GND), cy(row) + 1.6, "&#8722;", 5.2, fill=C_GND,
                         weight="700", halo=False))
            p.append(txt(cx(RAIL_VCC), cy(row) + 1.5, "+", 4.4, fill=C_VCC,
                         weight="700", halo=False))
        p.append(txt(cx(RAIL_VCC) + 6.5, cy(row) + 1.4, rotulo, 3.7,
                     anchor="start", fill=TINTA, weight="700"))

    # ---- conectores dos sensores, a cavalo sobre os trilhos
    for row, nome, canal, sd, sc in JSTS:
        x = cx(JST_C0) - 3.6
        p.append(f'<rect x="{x:.2f}" y="{cy(row) - 3.6:.2f}" '
                 f'width="{3 * PITCH + 7.2:.2f}" height="7.2" rx="2" '
                 f'fill="{C_CON}" fill-opacity=".16" stroke="{C_CON}" stroke-width="1"/>')
        p.append(txt(cx(JST_C0) + 1.5 * PITCH, cy(row) - 6.4,
                     f"{nome} &#183; {canal}", 4.4, fill=C_CON, weight="700"))
        for k, (cor, nm) in enumerate(((C_SDA, "SDA"), (C_GND, "GND"),
                                       (C_VCC, "VCC"), (C_SCL, "SCL"))):
            c = JST_C0 + k
            p.append(f'<circle cx="{cx(c):.2f}" cy="{cy(row):.2f}" r="2.2" fill="{cor}"/>')
            p.append(txt(cx(c), cy(row) + 9.4, nm, 3.4, fill=cor, weight="700"))
        p.append(txt(cx(JST_C0) - 5.2, cy(row) + 1.4, sd, 3.7, anchor="end",
                     fill=C_SDA, weight="700"))
        p.append(txt(cx(JST_C0 + 3) + 5.2, cy(row) + 1.4, sc, 3.7, anchor="start",
                     fill=C_SCL, weight="700"))

    # ---- reguas
    for c in range(COLS):
        cor = C_GND if c == RAIL_GND else C_VCC if c == RAIL_VCC else LETRA
        p.append(txt(cx(c), cy(0) - PITCH / 2 - PAD - 4, col_name(c), 4.2, fill=cor,
                     weight="700" if cor != LETRA else "400", halo=False))
    for r in range(ROWS):
        p.append(txt(cx(0) - PITCH / 2 - PAD - 3, cy(r) + 1.4, str(r + 1), 3.6,
                     anchor="end", fill=LETRA, halo=False))

    # ---- nome dos trilhos, escalonado para os dois nao colidirem
    base = cy(ROWS - 1) + PITCH / 2 + PAD
    for col, cor, nome, dy in ((RAIL_GND, C_GND, "GND", 7), (RAIL_VCC, C_VCC, "VCC", 16)):
        p.append(f'<line x1="{cx(col):.2f}" y1="{base:.2f}" x2="{cx(col):.2f}" '
                 f'y2="{base + dy - 4:.2f}" stroke="{cor}" stroke-width="1"/>')
        p.append(txt(cx(col), base + dy, nome, 4.2, fill=cor, weight="700", halo=False))

    # ------------------------------------------------------------------ legenda
    lx = ML + COLS * PITCH + PAD + 16
    y = MT - 8
    p.append(txt(lx, y, "Open Rudder", 11, anchor="start", fill=TINTA,
                 weight="700", halo=False))
    y += 11
    p.append(txt(lx, y, "layout na placa de tiras &#183; GND e VCC", 5.0,
                 anchor="start", fill=LETRA, halo=False))
    y += 7
    p.append(txt(lx, y, "nos dois trilhos centrais (F e G)", 5.0,
                 anchor="start", fill=LETRA, halo=False))

    y += 14
    for cor, rot in ((C_GND, "GND"), (C_VCC, "VCC 5 V"),
                     (C_SDA, "SDA"), (C_SCL, "SCL")):
        p.append(f'<line x1="{lx:.2f}" y1="{y - 1.6:.2f}" x2="{lx + 11:.2f}" '
                 f'y2="{y - 1.6:.2f}" stroke="{cor}" stroke-width="3" '
                 f'stroke-linecap="round"/>')
        p.append(txt(lx + 15, y, rot, 4.4, anchor="start", fill=LETRA, halo=False))
        y += 7.6
    p.append(f'<rect x="{lx:.2f}" y="{y - 4.4:.2f}" width="11" height="4.4" rx="2.2" '
             f'fill="{COBRE}" fill-opacity=".35"/>')
    p.append(txt(lx + 15, y, "tira de 5 furos = 1 no", 4.4, anchor="start",
                 fill=LETRA, halo=False))
    y += 13

    notas = [
        ("O ganho", [
            "Os dois pinos do meio de cada conector caem",
            "direto nos trilhos: zero jumper de forca nos",
            "tres sensores. Pro Micro e mux levam um jumper",
            "de um furo - GND sai pela metade esquerda, VCC",
            "pela direita, nenhum cruza o outro trilho. So o",
            "VIN do mux pula (arco vermelho na linha 19).",
        ]),
        ("De onde sai cada canal", [
            "No seu HW-617 os canais 0 e 1 saem do mesmo lado",
            "dos pinos de controle (esquerda); o canal 2 sai",
            "do lado oposto, e de baixo para cima. Um fio por",
            "sensor cruza os trilhos: o SCL nos canais 0 e 1,",
            "o SDA no canal 2. O firmware usa canal = indice",
            "do eixo, entao 0/1/2 valem sem mexer no codigo.",
        ]),
        ("Muda o chicote", [
            "Pinagem do JST passa a ser SDA . GND . VCC . SCL",
            "(forca no meio) - hoje o chicote.svg diz",
            "VCC . GND . SDA . SCL. Mesma ordem nos tres.",
            "Bonus: VCC/GND entre os dois sinais reduz",
            "crosstalk no cabo ate as biqueiras.",
        ]),
        ("Confira antes de soldar", [
            "1. Nenhuma perna pode cair em F ou G. Encaixe a",
            "   seco: pino no trilho e curto de VCC em GND.",
            "2. O lado dos canais corre de baixo para cima:",
            "   SD2/SC2 embaixo, SC7 no topo. Os pinos",
            "   SD3..SC7 ocupam tiras que nao usamos -",
            "   deixe essas linhas livres.",
            "3. Trilho partido no meio? Jumper unindo as",
            "   metades.",
            "4. RST do mux: pull-up no modulo; sem ele,",
            "   jumper de RST para VCC.",
            "5. Sao DOIS capacitores aqui, um por linha (14 e",
            "   15), os dois atravessando F e G - os trilhos",
            "   ja os poem em paralelo. So o 10 uF eletrolitico",
            "   e polarizado: tarja (-) em F = GND. Um ceramico",
            "   de 10 uF evita esse erro - nao tem lado.",
            "6. Os 100 nF dos sensores sao a parte: um em cada",
            "   AS5600, conforme o diagrama de ligacao.",
        ]),
        ("Escala", [
            "Desenho esquematico, nao 1:1 - localize pelas",
            "linhas numeradas da placa. 12 colunas x 40",
            "linhas, tiras de 5 furos. Me passe as medidas",
            "reais da sua placa que eu ajusto.",
        ]),
    ]
    for cabecalho, linhas in notas:
        p.append(txt(lx, y, cabecalho, 5.2, anchor="start", fill=TINTA,
                     weight="700", halo=False))
        y += 7.6
        for ln in linhas:
            p.append(txt(lx, y, ln, 4.4, anchor="start", fill=LETRA, halo=False))
            y += 6.3
        y += 5.5

    p.append("</svg>")
    return "\n".join(p)


if __name__ == "__main__":
    destino = Path(__file__).parent / "tiras.svg"
    destino.write_text(build(), encoding="utf-8")
    print(f"{destino}  ({destino.stat().st_size / 1024:.1f} kB, "
          f"{COLS}x{ROWS} furos, {W:.0f}x{H:.0f})")
