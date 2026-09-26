#!/usr/bin/env python3
"""
Trata as fotos do pedal para a página: recorta no assunto, uniformiza o
enquadramento e ajusta a imagem para assentar no fundo escuro.

O pedal é todo preto sobre piso claro e quente. Duas coisas resolvem isso:

  - a curva de gama abre a faixa baixa e deixa a geometria do hardware
    aparecer. Contraste global faria o contrário — esmagaria o preto;
  - dessaturar quase tudo neutraliza a madeira do piso, que é a única cor
    da cena e a que briga com a página.

O recorte é automático: o assunto é escuro sobre fundo claro, então basta
limiarizar e pegar o retângulo. Cada foto tem seu enquadramento alvo — a
frontal é quase 2:1 e o pedal ocupa a largura inteira, então forçar 4:3
nela decepa um dos pedais.

    python fotos/tratar.py <pasta-de-origem> [pasta-de-saida]
"""

from PIL import Image, ImageEnhance, ImageFilter, ImageDraw
from pathlib import Path
import sys

# (arquivo de origem, nome de saída, largura, altura)
FOTOS = [
    ("WhatsApp Image 2026-09-26 at 13.46.35.jpeg", "pedal-frente.jpg", 1600, 740),
    ("WhatsApp Image 2026-09-26 at 13.47.38.jpeg", "pedal-cima.jpg",   1200, 900),
    ("WhatsApp Image 2026-09-26 at 13.47.36.jpeg", "pedal-lado.jpg",   1200, 1100),
]

MARGEM    = 0.07   # folga em volta do assunto, antes de enquadrar
LIMIAR    = 85     # abaixo disto é assunto, acima é piso
GAMA      = 0.80   # < 1 levanta as sombras
SATURACAO = 0.34
CONTRASTE = 1.10
NITIDEZ   = 1.35
VINHETA   = 0.28   # quanto escurece o canto
QUALIDADE = 84


def levanta_sombras(im, g=GAMA):
    lut = [min(255, int(255 * (i / 255) ** g)) for i in range(256)]
    return im.point(lut * 3)


def bbox_assunto(im):
    """Limiariza e devolve o retângulo do assunto. O MinFilter erode a
    máscara, matando sombra solta e reflexo que inflariam o retângulo."""
    mask = im.convert("L").point(lambda p: 255 if p < LIMIAR else 0)
    return mask.filter(ImageFilter.MinFilter(9)).getbbox()


def enquadra(im, bbox, alvo_w, alvo_h):
    """Expande o retângulo do assunto até a proporção alvo, sem sair da
    imagem. Encolhe antes de deslocar, para nunca pedir pixel inexistente."""
    W, H = im.size
    x0, y0, x1, y1 = bbox
    mx, my = (x1 - x0) * MARGEM, (y1 - y0) * MARGEM
    x0, y0, x1, y1 = x0 - mx, y0 - my, x1 + mx, y1 + my

    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    w, h = x1 - x0, y1 - y0
    alvo = alvo_w / alvo_h
    w, h = (h * alvo, h) if w / h < alvo else (w, w / alvo)

    w, h = min(w, W), min(h, H)
    w, h = (h * alvo, h) if w / h > alvo else (w, w / alvo)
    cx = min(max(cx, w / 2), W - w / 2)
    cy = min(max(cy, h / 2), H - h / 2)
    return im.crop((int(cx - w / 2), int(cy - h / 2),
                    int(cx + w / 2), int(cy + h / 2)))


def vinheta(im, forca=VINHETA):
    """Escurece os cantos para a foto assentar na página escura em vez de
    recortar contra ela. Elipses concêntricas e um blur: sem numpy, é o
    caminho barato para um gradiente radial."""
    W, H = im.size
    g = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(g)
    passos = 60
    for i in range(passos):
        t = i / passos
        rw, rh = W * (1.35 - 0.62 * t), H * (1.35 - 0.62 * t)
        d.ellipse([W / 2 - rw / 2, H / 2 - rh / 2,
                   W / 2 + rw / 2, H / 2 + rh / 2],
                  fill=int(255 * (1 - forca * t * t)))
    g = g.filter(ImageFilter.GaussianBlur(W / 22))
    return Image.composite(im, Image.new("RGB", (W, H), (0, 0, 0)), g)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__.strip().splitlines()[-1].strip())
    src = Path(sys.argv[1])
    dst = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).parent
    dst.mkdir(parents=True, exist_ok=True)

    for origem, destino, alvo_w, alvo_h in FOTOS:
        caminho = src / origem
        if not caminho.exists():
            print(f"{destino:18} origem ausente: {origem}")
            continue
        im = Image.open(caminho).convert("RGB")
        bb = bbox_assunto(im)
        if bb:
            im = enquadra(im, bb, alvo_w, alvo_h)
        im = im.resize((alvo_w, alvo_h), Image.LANCZOS)

        im = levanta_sombras(im)
        im = ImageEnhance.Color(im).enhance(SATURACAO)
        im = ImageEnhance.Contrast(im).enhance(CONTRASTE)
        im = ImageEnhance.Sharpness(im).enhance(NITIDEZ)
        im = vinheta(im)

        alvo = dst / destino
        im.save(alvo, "JPEG", quality=QUALIDADE, optimize=True, progressive=True)
        print(f"{destino:18} {im.width}x{im.height}  "
              f"{alvo.stat().st_size / 1024:6.1f} kB")


if __name__ == "__main__":
    main()
