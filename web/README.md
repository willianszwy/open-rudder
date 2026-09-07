# Calibrador web — Open Rudder

Página que conversa com o Pro Micro pela porta serial (Web Serial API) para
visualizar o eixo e calibrar o pedal sem abrir o Serial Monitor.

## Versão hospedada

**https://willianszwy.github.io/open-rudder/** — o GitHub Pages serve por HTTPS, que é
contexto seguro, então a Web Serial funciona direto. Não precisa de servidor local.

O `servir.bat` abaixo continua útil só para desenvolver offline ou testar alterações
antes de commitar.

## Como usar

1. Grave o sketch `firmware/open_rudder` no Pro Micro.
2. Dê dois cliques em **`servir.bat`** (sobe um servidor local e abre o navegador).
3. Clique em **Conectar** e escolha a porta do Arduino na lista do Chrome.

> A Web Serial API só funciona em **Chrome ou Edge** e só em contexto seguro
> (`localhost` ou HTTPS). Abrir o `calibrador.html` direto pelo Explorer
> (`file://`) faz o botão Conectar falhar — por isso o `servir.bat`.

Para parar o servidor: `Ctrl+C` na janela preta.

## Calibração

1. **Centro** — pedais soltos, clique em Capturar.
2. **Batente esquerdo** — pise a fundo à esquerda, Capturar.
3. **Batente direito** — pise a fundo à direita, Capturar.
4. **Gravar na EEPROM**.

Se os lados saírem trocados, clique em *Inverter lados* e repita os passos 2 e 3.
Enquanto houver mudança não gravada, aparece o aviso "alterações não gravadas" —
sem clicar em Gravar, tudo volta ao estado anterior no próximo boot.

## O que a página mostra

- **Eixo do leme** — deflexão em graus, saída em %, valor HID (±16383) e leitura
  bruta do AS5600 (0–4095).
- **Posição no giro do ímã** — onde o centro e o curso útil caem no círculo
  completo do sensor. Útil pra ver que só ~9% do giro é usado (±17°) e que o
  centro pode estar em qualquer ponto.
- **Ajuste de resposta** — deadzone e expo, com a curva desenhada e um ponto
  amarelo mostrando onde você está nela em tempo real.
- **Ímã** — status (OK / fraco / forte / ausente) e AGC. Use na montagem pra
  achar a distância certa entre o ímã e o chip.

## Protocolo

O firmware emite duas linhas de máquina (25 Hz, só depois do comando `>`):

```
D,raw,rel,eixo,statusIma,agc      statusIma: 0=ok 1=sem ima 2=fraco 3=forte 4=erro
C,centro,minRel,maxRel,invert,deadzone,expo
```

Comandos aceitos (um por linha): `c` `l` `r` `i` `w` `e` `?` `s` `p` `>` `<`,
mais `d<n>` (deadzone) e `x<n>` (expo). Qualquer outra linha é texto humano —
a página joga no painel de mensagens.
