#!/usr/bin/env python3
"""
Gera hardware/perfurada.svg — o layout dos componentes na placa perfurada.

O SVG sai em unidades reais (mm), então imprimir a 100% dá um gabarito 1:1
para apoiar em cima da placa. Rode depois de mexer em BLOCOS ou na grade:

    python hardware/gerar_perfurada.py
"""

from pathlib import Path

# ------------------------------------------------------------------ geometria
COLS, ROWS = 26, 31        # furos: 26 x 2,54 = 66 mm ; 31 x 2,54 = 79 mm
PITCH = 2.54               # passo padrão de placa perfurada, em mm
MARGIN = 9                 # espaço para as réguas de letras

W = COLS * PITCH + MARGIN * 2
H = ROWS * PITCH + MARGIN * 2

# barramentos: coluna B = GND, coluna D = VCC (5 V do Pro Micro). Índices 0-based.
COL_GND, COL_VCC = 1, 3

# (coluna, linha, largura, altura, rótulo, cor) — tudo em furos
BLOCOS = [
    (8,   0, 10, 13, "Pro Micro (soquete)",   "#2f80d6"),
    (8,  15,  9,  7, "TCA9548A",              "#7c5cd6"),
    (19, 15,  6,  7, "AMS1117 (só p/ AS5600 3V3)", "#c2410c"),
    (4,  24,  6,  5, "LEME",                  "#159a6b"),
    (11, 24,  6,  5, "FREIO ESQ",             "#159a6b"),
    (18, 24,  6,  5, "FREIO DIR",             "#159a6b"),
]

PAPEL, FURO, LETRA = "#f7f2e4", "#9a8e70", "#8a7f66"
MONO = "ui-monospace, Consolas, monospace"


def col_name(i: int) -> str:
    return chr(65 + i)


def row_name(i: int) -> str:
    """A..Z e depois A'..E', como vem impresso na placa."""
    return chr(65 + i) if i < 26 else chr(65 + i - 26) + "'"


def cx(c: float) -> float:
    return MARGIN + PITCH / 2 + c * PITCH


def cy(r: float) -> float:
    return MARGIN + PITCH / 2 + r * PITCH


def build() -> str:
    p = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}mm" height="{H}mm" '
        f'viewBox="0 0 {W} {H}" font-family="{MONO}">',
        "<title>Open Rudder — layout na placa perfurada</title>",
        f'<rect x="{MARGIN - 2}" y="{MARGIN - 2}" width="{COLS * PITCH + 4}" '
        f'height="{ROWS * PITCH + 4}" rx="1.5" fill="{PAPEL}" stroke="#b9a67c" stroke-width=".4"/>',
    ]

    for c, r, w, h, label, color in BLOCOS:
        x, y = cx(c) - PITCH / 2, cy(r) - PITCH / 2
        p.append(
            f'<rect x="{x:.2f}" y="{y:.2f}" width="{w * PITCH:.2f}" height="{h * PITCH:.2f}" '
            f'rx="1" fill="{color}" fill-opacity=".10" stroke="{color}" stroke-width=".35"/>'
        )
        p.append(
            f'<text x="{x + w * PITCH / 2:.2f}" y="{y + h * PITCH / 2 + .9:.2f}" '
            f'text-anchor="middle" font-size="2.1" fill="{color}" font-weight="700" '
            f'paint-order="stroke" stroke="{PAPEL}" stroke-width="1.1" '
            f'stroke-linejoin="round">{label}</text>'
        )

    for col, color, nome in ((COL_GND, "#334155", "GND"), (COL_VCC, "#d64545", "VCC")):
        p.append(
            f'<line x1="{cx(col):.2f}" y1="{cy(0):.2f}" x2="{cx(col):.2f}" y2="{cy(ROWS - 1):.2f}" '
            f'stroke="{color}" stroke-width="1.1" stroke-linecap="round"/>'
        )
        p.append(
            f'<text x="{cx(col):.2f}" y="{cy(ROWS - 1) + 5.4:.2f}" text-anchor="middle" '
            f'font-size="2.2" fill="{color}" font-weight="700">{nome}</text>'
        )

    for r in range(ROWS):
        for c in range(COLS):
            p.append(
                f'<circle cx="{cx(c):.2f}" cy="{cy(r):.2f}" r=".42" fill="none" '
                f'stroke="{FURO}" stroke-width=".18"/>'
            )

    for c in range(COLS):
        p.append(
            f'<text x="{cx(c):.2f}" y="{MARGIN - 3.4:.2f}" text-anchor="middle" '
            f'font-size="1.9" fill="{LETRA}">{col_name(c)}</text>'
        )
    for r in range(ROWS):
        p.append(
            f'<text x="{MARGIN - 3.2:.2f}" y="{cy(r) + .7:.2f}" text-anchor="middle" '
            f'font-size="1.9" fill="{LETRA}">{row_name(r)}</text>'
        )

    p.append("</svg>")
    return "\n".join(p)


if __name__ == "__main__":
    destino = Path(__file__).parent / "perfurada.svg"
    destino.write_text(build(), encoding="utf-8")
    print(f"{destino}  ({destino.stat().st_size / 1024:.1f} kB, {COLS}x{ROWS} furos, {W:.2f}x{H:.2f} mm)")
