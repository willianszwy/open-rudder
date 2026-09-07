# Open Rudder — Rudder Pedal Magnético

Pedais de leme com arquitetura de **rudder bar** (barra central, como em aeronaves
reais) e três inovações que nenhum produto do mercado combina:

| # | Inovação | O que substitui | Benefício |
|---|----------|-----------------|-----------|
| 1 | **Centragem magnética sem contato** (repulsão N-N de ímãs de neodímio) com ajuste 0–100% por um único anel helicoidal | Mola + came (MFG, Virpil, TPR) | Zero desgaste, silêncio total, força ajustável em voo. 0% = modo helicóptero (sem centragem) |
| 2 | **Amortecimento por correntes de Foucault** (disco de cobre entre ímãs) | Amortecedor hidráulico/atrito | Amortecimento viscoso real, proporcional à velocidade, sem fluido, sem manutenção, ajustável por engajamento |
| 3 | **Freios de biqueira isométricos** com célula de carga | Potenciômetro + mola no pivô | Você dosa *força*, não curso — como o pedal hidráulico real. Sem desgaste |

Sensor de eixo: **AS5600** (Hall magnético, 12 bits, sem contato). Nada no caminho
do sinal encosta em nada: a vida útil mecânica é limitada só pelos rolamentos 608.

> Este repositório também traz o **MAGNUS S1** (`magnus_s1.scad`), manche com gimbal
> magnético que compartilha a mesma física — resumo no fim, ainda com o nome antigo.

## Arquivos

- `firmware/open_rudder/` — firmware do Pro Micro (leme + 2 freios, USB HID).
- `web/calibrador.html` — calibrador que fala com a placa por Web Serial.
- `open_rudder.scad` — CAD paramétrico completo (OpenSCAD).
  - `part = "assembly"` — montagem; `bar_angle` (-17..17) anima a deflexão;
    `ring_lift` (0..18) mostra o anel de força subindo; `yoke_engage` (0..1) o amortecedor.
  - `part = "exploded"` — vista explodida.
  - `part = "<nome>"` — cada peça imprimível isolada para exportar STL:
    `lower_block, upper_block, shell_half (x2), force_ring, force_collar,
    rotor, eddy_hub, eddy_yoke, bar_hub, pedal_post (x2), pedal_plate (x2)`.

## Como funciona a centragem magnética

O rotor tem 2 ímãs (Ø10×10, N para cima) a 75 mm do eixo, em ±Y. O anel estator
tem 4 dedos com ímãs idênticos, mesma polaridade, a ±30° de cada ímã do rotor.
Ímãs paralelos lado a lado com mesma orientação **se repelem**: ao defletir a barra,
o ímã do rotor se aproxima de um dedo do estator e é empurrado de volta ao centro.
A força cresce progressivamente com a deflexão (curva exponencial natural dos ímãs
— parecida com a carga aerodinâmica real do leme).

O **colar laranja externo** tem 3 rasgos helicoidais: girá-lo 120° levanta o anel
estator 18 mm, tirando os ímãs do plano do rotor → força de centragem cai
continuamente de 100% a ~0%. Um único gesto, como focar uma lente.

## Como funciona o amortecedor eddy

Um disco de cobre de 2 mm gira com o eixo entre dois ímãs de bloco N52 (20×20×10)
montados num garfo em C. O movimento induz correntes de Foucault no cobre →
força contrária **proporcional à velocidade** (amortecimento viscoso ideal).
Parado, força zero — não adiciona atrito estático. O garfo desliza radialmente:
mais área de disco entre os ímãs = mais amortecimento.

## BOM (estimativa, jul/2026)

| Item | Qtd | ~R$ |
|------|-----|-----|
| Perfil alumínio 2020 (2×380 + 1×360 + 1×400 mm) | 1,5 m | 90 |
| Eixo aço retificado Ø8 × 140 mm | 1 | 25 |
| Rolamento 608ZZ | 2 | 12 |
| Ímã neodímio N52 Ø10×5 (rotor 4 + estator 8) | 12 | 60 |
| Ímã bloco N52 20×20×10 (amortecedor) | 2 | 50 |
| Ímã diametral Ø6×2,5 (sensor) | 1 | 8 |
| Disco/chapa de cobre Ø120 × 2 mm | 1 | 60 |
| Célula de carga barra 50 kg (YZC-131/TAL220) | 2 | 40 |
| Módulo HX711 | 2 | 20 |
| RP2040-Zero (USB-C, HID nativo) | 1 | 40 |
| Módulo AS5600 | 1 | 25 |
| Parafusos M4/M5, porcas T, insertos M4/M5 | — | 90 |
| Filamento PETG/ASA (~1,2 kg) | — | 90 |
| Pés de borracha, batentes, cabos | — | 40 |
| **Total** | | **~R$ 650** |

## Impressão

- Material: **PETG** (protótipo) ou **ASA/PC-blend** (produto).
- Estruturais (`lower_block`, `upper_block`, `bar_hub`, `pedal_post`): 5 perímetros,
  40% gyroid, camada 0,25.
- `shell_half`, `force_collar`, `force_ring`: 3 perímetros, 20%.
- `pedal_plate`: 5 perímetros, nervuras já modeladas; imprimir deitada (face do pé na mesa).
- Insertos de latão M4/M5 a quente em todos os furos de fixação repetitiva.
- **Ímãs colados com epóxi** nos bolsos (atenção à polaridade: TODOS com N para cima —
  marque com caneta antes de colar).

## Eletrônica / Firmware

```
AS5600 (I2C) ─┐
HX711 esq ────┼── RP2040-Zero ── USB HID (joystick 3 eixos)
HX711 dir ────┘
```

- Firmware sugerido: RP2040 + TinyUSB HID (ou Arduino-Pico + biblioteca Joystick).
- Eixo do leme: AS5600 (4096 passos em ±17° ≈ resolução efetiva de ~380 passos/grau
  usando gearing por software; aplicar filtro EMA leve).
- Freios: HX711 a 80 SPS, tara automática no boot, curva de resposta configurável.
- Calibração e curvas por utilitário desktop (fase 2 do produto).

## Sequência de montagem

1. Base em H: trilhos + travessa com cantoneiras e porcas T.
2. `lower_block` na travessa (4× M5); AS5600 no nicho, cabo pela janela -Y.
3. Rolamento inferior no bolso; eixo com ímã diametral na ponta.
4. `eddy_hub` + disco de cobre no eixo (parafuso M4); garfo `eddy_yoke` na guia.
5. `rotor` com ímãs colados; conferir polaridade.
6. `force_ring` (ímãs colados) sobre o rotor; pinos pelos rasgos das `shell_half`;
   `force_collar` por fora, engatando os pinos nas hélices.
7. Fechar as duas `shell_half` nos blocos; `upper_block` com rolamento superior.
8. `bar_hub` no topo do eixo; barra 2020 no berço.
9. `pedal_post` nas pontas da barra; célula de carga na torre; `pedal_plate` no pivô.
10. Eletrônica na caixa do trilho; flash do firmware; calibrar.

## Roadmap de produto

- **v1 (este CAD):** mecânica completa, ajustes manuais.
- **v1.5:** escala clicada no colar de força (detentes), heel rests ajustáveis,
  chapa de ancoragem para cadeira.
- **v2:** motor de passo no colar = perfis de força trocados por software
  (a arquitetura magnética já é "FFB-ready" sem redesenho).

---

# MAGNUS S1 — Manche com Gimbal Magnético

Gimbal cardan de 2 eixos (anel externo = pitch, bloco interno = roll), tudo em
rolamentos 608 com eixos de aço 8 mm. Em cada eixo, um **cartucho magnético**:

- **Paddle** no eixo com ímã N52 Ø10×10 a 42 mm, flanqueado por 2 ímãs de
  estator (mesma polaridade) a ±28° → repulsão progressiva, sem mola.
- **Ajuste por eixo**: o estator desliza axialmente (rodinha lateral na base
  para pitch; roll interno na v1) → força 0–100% independente por eixo.
- **Detent central por atração**: par de ímãs Ø5×2 de pólos opostos alinhados
  no centro — repulsão dá o gradiente, atração dá o centro definido.
- **Amortecimento eddy**: setor de cobre de 80° por eixo girando na garganta
  de um garfo com ímãs de bloco — mata a oscilação sem atrito estático.
- **Sensores**: 2× AS5600 nas pontas OPOSTAS aos cartuchos, arruela de aço
  como blindagem no meio do eixo. Calibrar zero após a montagem.

Curso ±18°/eixo · base 190×190×116 · stick 250 mm · BOM ~R$ 480.
Eletrônica idêntica ao R1 (RP2040-Zero HID); dá para ligar os dois num só
RP2040 (4 eixos + freios) ou cada um com o seu.

`magnus_s1.scad`: `part = "assembly" | "cutaway"` ou peça para STL
(`base_shell, top_plate, outer_frame, inner_block, paddle, stator_slider,
stick, thumbwheel`); `pitch_angle`/`roll_angle` = deflexão;
`pitch_engage`/`roll_engage` = engajamento dos cartuchos.

Ponto de atenção estrutural: o quadro interno concentra toda a alavanca do
stick — PETG maciço (100% infill) e, na versão produto, é a única peça que
migraria para alumínio usinado.
