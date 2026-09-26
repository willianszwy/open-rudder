// case.scad — caixa da placa de controle do Open Rudder
//
// Abriga a placa de tiras de 129 × 28 mm com o Pro Micro, o TCA9548A e os três
// conectores dos sensores. Duas peças: bandeja e tampa, sem parafuso nenhum
// prendendo a placa.
//
// POR QUE A PLACA NÃO É PARAFUSADA. Placa de tiras não vem com furo de fixação,
// e furar depois de montada é onde se corta uma trilha sem perceber. Aqui ela
// apenas DESCE na bandeja e pousa num ressalto corrido; a tampa traz duas
// nervuras que descem até a face de cima e a prensam contra esse ressalto. A
// placa fica presa pelas duas bordas longas, sem furo, sem espaçador e sem
// parafuso passando perto de cobre.
//
// O preço disso é que os APOIO mm mais externos de cada borda ficam cobertos
// pelo ressalto embaixo e pela nervura em cima. A fileira de furos mais externa
// precisa estar livre de solda alta desse lado — se tiver, reduza APOIO ou
// levante H_SOLDA.
//
// AS NERVURAS SÓ EXISTEM NAS LATERAIS. Nas duas pontas a tampa é vazada de
// propósito: é por onde sai o cabo USB. Nervura correndo na ponta fecharia
// justamente essa passagem.
//
// OS CHICOTES SAEM POR CIMA, pela tampa, e não pela parede. O JST-XH é de
// entrada vertical, então o cabo já aponta para cima; desviá-lo 90° para uma
// fenda lateral colocaria a dobra em cima da solda. Os rasgos são largos o
// bastante para a carcaça do conector atravessar, de modo que a tampa sai sem
// desplugar nada.
//
// FURO DE ACESSO AO RESET. Não é conveniência: este Pro Micro não enumera no
// plug a frio — o Windows acusa falha de descritor e a placa só aparece depois
// de um toque no RESET. Enquanto ele não for trocado, o botão precisa estar
// alcançável com a caixa fechada, senão cada boot do PC vira desmontagem.
// Confira RESET_X contra a sua montagem antes de imprimir; a cota é medida do
// centro da caixa.
//
// FIXAÇÃO NO PERFIL. Dois furos retos na linha de centro do fundo, para
// castanha de 2020. Ficam na linha de centro porque a caixa é mais larga que o
// perfil: orelha lateral jogaria o furo para fora da fenda.
//
// O parafuso entra de dentro para fora, então a cabeça fica alojada sob a placa
// e consome parte de H_SOLDA. O furo é reto de propósito — escareado na face
// externa não alojaria nada e só afinaria o fundo. Se a cabeça não couber no
// vão, ESCAREADO = "interno" afunda ela no fundo pela face de cima.
//
// Imprima as duas peças deitadas, sem suporte: a bandeja com a boca para cima,
// a tampa com as nervuras para cima.
//
// Precisa do OpenSCAD 2021.01 ou mais novo.


/* ------------------------------------------------------------- parâmetros */

PECA = "ambas";    // "base" | "tampa" | "ambas" (ambas = vista de montagem)

PLACA_C = 129;     // mm, comprimento da placa
PLACA_L = 28;      // mm, largura
PLACA_E = 1.6;     // mm, espessura do laminado
// FOLGA DE IMPRESSÃO. Todo encaixe entre peça impressa e peça impressa — ou
// entre peça impressa e componente — precisa dela: furo sai menor que o
// nominal, saliência sai maior, e encaixe modelado justo simplesmente não
// entra. A primeira impressão provou isso em três pontos de uma vez.
//
// Aplicada POR FACE. Um bolso para um corpo de 6,0 mm vira 6,0 + 2*TOL.
TOL = 0.2;         // mm, folga por face

FOLGA   = 0.35;    // mm, folga por lado na LARGURA (justo: é o que centra)
FOLGA_C = 1.0;     // mm, folga por ponta no COMPRIMENTO

// O USB-C do Pro Micro avança além da borda do laminado. Essa sobra é só de um
// lado, então a cavidade cresce SÓ na ponta do USB — folgar as duas pontas
// desperdiçaria comprimento e ainda deixaria a placa jogar dentro da caixa.
//
// x = 0 continua sendo o CENTRO DA PLACA, não o da caixa: é a referência em que
// você mede tudo (SAIDAS, RESET_X, FUROS, ARDUINO_Y). Quem fica assimétrico em
// torno dela é o case.
USB_SAI = 3.0;     // mm, quanto o conector avança além da borda

H_SOLDA = 3.5;     // mm, vão sob a placa para as pernas soldadas
// 18 e não 16: esta é a única cota que não foi medida, e o erro é assimétrico.
// Para baixo, a tampa não fecha e as duas peças vão fora. Para cima, o custo é
// só altura — as nervuras ficam na borda da placa, onde não há componente, e
// alcançam a face dela de qualquer forma. Vale pagar 2 mm pelo seguro.
//
// Pilha esperada: soquete 8,5 + plaquinha 1,6 + USB-C 3,2 = ~13,3 mm.
// Altura livre sobre a placa. Com o interruptor de alavanca na tampa ela deixa
// de ser escolha e vira consequência: o corpo dele desce RESET_CORPO a partir
// da tampa, e embaixo do ponto escolhido há ALT_SOB_RESET de componente. A
// conta se faz sozinha abaixo, em H_COMP.
H_COMP_MIN   = 18;     // mm, o que já bastava para a placa sozinha
ALT_SOB_RESET = 10.1;  // mm, altura do que está sob o interruptor — aqui o mux
                       //     em soquete (8,5 + 1,6). Medido na foto: o mux vai
                       //     de x=-9,3 a +22,7, e RESET_X=-3 cai sobre ele.

// Pro Micro e mux ficam em soquete, para poderem sair sem dessoldar. Isso
// levanta o conector USB: ele não está rente à placa, e sim H_SOQUETE acima
// dela. O rasgo do USB é posicionado a partir daqui — desenhado rente à placa,
// ele ficaria inteiro abaixo do conector.
H_SOQUETE = 8.5;   // mm, altura do soquete fêmea
H_MODULO  = 1.6;   // mm, espessura da plaquinha do Pro Micro
H_USB     = 3.0;   // mm, altura da carcaça do conector USB
APOIO   = 2.0;     // mm, quanto o ressalto avança sob a borda da placa

// As nervuras da tampa NÃO descem até a face da placa. Elas desceriam bem em
// cima das bordas, que é justamente por onde correm os fios — e foi isso que
// impediu a tampa de fechar na primeira montagem, faltando ~2 mm.
//
// Subir H_COMP não resolveria: a tampa sobe e as nervuras sobem junto, e elas
// continuam alcançando a mesma altura sobre a placa. O que resolve é encurtar.
//
// O preço é que a placa deixa de ser prensada e ganha esta folga vertical. Ela
// continua presa de lado pelas paredes e apoiada nos ressaltos; o que some é o
// aperto. Se chacoalhar, o caminho não é alongar a nervura de volta — é pôr um
// calço de espuma na tampa, que se acomoda aos fios.
NERVURA_FOLGA = 3.0;  // mm, quanto a nervura para antes da placa

T_PAREDE = 3.0;    // mm, parede lateral — 3 é o padrão do usuário, para a
                   //     parede aguentar castanha/porca embutida
T_FUNDO  = 3.0;    // mm, fundo — grosso para escarear a cabeça do parafuso
T_TAMPA  = 2.0;    // mm, tampa

// --- encaixe da tampa (friso nas nervuras, sulco na parede)
FRISO_P = 0.7;     // mm, quanto o friso avança
FRISO_H = 1.4;     // mm, altura do friso
FRISO_Z = 4.0;     // mm, do topo da parede até o topo do friso
FRISO_F = TOL;     // mm, folga no sulco

// --- aberturas. X é medido do centro da caixa, ao longo do comprimento.
// O Pro Micro não está centrado na largura da placa, então o rasgo do USB e o
// furo do RESET seguem o EIXO DELE, não o da placa. Meça do centro da placa até
// o centro do Pro Micro e ponha aqui, com sinal.
// Medido direto no que importa: 12,2 mm da borda direita da placa até o CENTRO
// do conector USB. Daí 28,0 - 12,2 = 15,8 da borda esquerda, e o descentramento
// é 15,8 - 14,0 = 1,8 mm para o lado direito.
//
// Essa é a cota boa. As folgas de borda medidas antes (8,4 e 4,0) davam 2,2 e
// não fechavam com a largura nominal do Pro Micro — medir até o centro do
// conector não passa por suposição nenhuma sobre o módulo.
//
// O sinal positivo aponta para a borda direita. Se o rasgo sair espelhado na
// peça impressa, troque o sinal: é a única coisa aqui que depende de qual lado
// você chamou de direito.
ARDUINO_Y = 1.8;   // mm

// Largura generosa e CENTRADA NA PLACA, em vez de justa e centrada no Pro
// Micro. A primeira impressão saiu com o rasgo visivelmente torto, e a causa
// mais provável é o sinal de ARDUINO_Y: qual borda é "direita" dependeu da
// minha interpretação de uma medida em texto, e sinal trocado dobra o erro
// para 3,6 mm.
//
// Com 22 mm o rasgo cobre o conector nas DUAS hipóteses de sinal — no pior
// caso ele fica entre -6,3 e +2,7, bem dentro dos ±11. Some-se o overmold do
// plugue, que é bem maior que a carcaça metálica.
//
// Se um dia você medir o descentramento real, dá para reapertar: volte USB_Y
// para ARDUINO_Y e USB_L para uns 15.
USB_L = 22;        // mm, largura do rasgo
USB_H = 8 + 2 * TOL;   // mm, altura
USB_Y = 0;         // mm, centrado na placa — ver nota em USB_L
USB_Z = H_SOQUETE + H_MODULO + H_USB / 2;   // mm, centro do conector sobre a placa

// O rasgo do USB sobe até o topo da parede em vez de ser uma janela fechada: em
// soquete o conector fica tão alto que uma janela deixaria menos de 1 mm de
// parede acima dela — uma lasca que não imprime. A tampa apoia em cima e fecha
// a abertura de qualquer jeito. Só feche a janela (false) se aumentar H_COMP o
// bastante para sobrar uns 2,5 mm de material acima do rasgo.
USB_ABERTO = true;

// Saídas dos chicotes: pela TAMPA, não pela lateral. O JST-XH da placa é de
// entrada vertical (trava para cima, como especifica o chicote.svg), então o
// cabo já sai para cima — fazê-lo dobrar 90° para escapar por uma fenda na
// parede castigaria a solda e o alívio de tração, que é onde esses chicotes
// morrem. Os rasgos passam a CARCAÇA do conector, não só o cabo: assim a tampa
// sai com os três ainda plugados.
// O corpo do JST-XH de 4 vias fica COMPRIDO NO SENTIDO DA LARGURA da placa
// (as quatro vias ocupam quatro colunas), então o rasgo é estreito no
// comprimento e largo na transversal — não o contrário.
SAIDA_C = 8;       // mm, do rasgo ao longo do COMPRIMENTO da caixa
SAIDA_L = 13 + 2 * TOL;  // mm, do rasgo na LARGURA
SAIDA_R = 1.5;     // mm, raio dos cantos — cabo não gosta de aresta viva

// Um rasgo por conector. O passo é de 6 FUROS (15,24 mm), não os ~10 mm
// estimados a olho: o usuário contou 4 linhas de furos livres entre os corpos,
// e o corpo do JST-XH cobre ~2 linhas — 4 + 2 = 6. Confere com a medição na
// foto com régua, que deu ~14 mm entre centros.
//
// Num perfurado o passo é sempre múltiplo de 2,54, então vale desconfiar de
// qualquer cota "redonda" em milímetros: 10 mm não existe nessa grade.
//
// Com 10 mm de espaçamento e SAIDA_C de 8 sobram 2 mm de tampa entre um rasgo e
// o seguinte. É pouco, mas aguenta: a tampa não é estrutural, quem prende a
// placa são as nervuras das bordas. Se quiser mais material ali, baixe SAIDA_C
// para 7 — a carcaça do JST-XH tem ~6,7 mm nesse sentido e ainda passa, só que
// com menos folga para encaixar de primeira.
// UM RASGO ÚNICO cobrindo os três conectores, em vez de três justos.
//
// O motivo é honesto: as posições vieram de medição em foto e carregam uns
// ±3 mm de incerteza, enquanto um rasgo de 8 mm deixa só 1,3 mm de folga sobre
// a carcaça do JST. Três rasgos justos exigiriam acertar a posição no
// milímetro; um rasgo corrido não exige nada disso — cobre a faixa inteira e
// perdoa o erro.
//
// Medido na foto com régua: conectores em aproximadamente -50, -34 e -19. O
// rasgo vai de -57 a -11, com folga sobrando dos dois lados.
SAIDA_UNICA = true;
// Encurtado na ponta do USB para dar material ao furo do interruptor. A foto
// com a tampa posta mostrou ~7,6 mm de sobra desse lado, então dá para tirar
// sem descobrir o primeiro conector.
SAIDA_X     = -35.6; // mm, centro do rasgo corrido
SAIDA_UC    = 42.8 + 2 * TOL;  // mm, comprimento do rasgo corrido

PASSO_JST = 6 * 2.54;                       // 15,24 mm
P1        = -PLACA_C / 2 + 14.5;            // centro do 1o conector, da ponta
SAIDAS  = SAIDA_UNICA
        ? [[SAIDA_X, 0]]
        : [[P1, 0], [P1 + PASSO_JST, 0], [P1 + 2 * PASSO_JST, 0]];

CABO_LATERAL = false;  // true reabre também a fenda na parede da ponta
CABO_L = 22;       // mm, fenda lateral, só se CABO_LATERAL
CABO_H = 7;
CABO_Y = 0;

// RESET no painel. Em vez de um furo para alcançar o botão da placa, entra um
// interruptor ON-ON de 3 pinos montado na tampa. Ligação: pino central no
// RESET, um dos extremos no GND, o terceiro sem ligar nada — numa posição o
// RESET fica aterrado (placa parada), na outra ele solta e a placa parte.
//
// ATENÇÃO: ON-ON é de trava, não momentâneo. Esquecer na posição aterrada
// deixa a placa morta sem sintoma nenhum além de não enumerar — que é
// exatamente o defeito que a gente passou horas caçando. Vale marcar na tampa
// qual lado é "roda".
//
// Cotas do MTS-102 (o ON-ON de 3 pinos mais comum). Confira as suas: bucha
// M6x0,75 pede furo de 6,1, e o corpo mais os terminais descem ~14 mm abaixo
// do painel — quase todo o H_COMP disponível.
// BOTÃO TÁTIL NA TAMPA. Um 6x6 DIP momentâneo, alojado num ressalto na face
// interna da tampa, com o atuador saindo por um furo.
//
// É melhor que o ON-ON em três frentes: é momentâneo, que é o que o RESET pede
// (o de trava, esquecido na posição aterrada, deixa a placa morta com o mesmo
// sintoma do defeito de fábrica dela); é pequeno o bastante para caber na
// tampa; e como o ressalto invade só TATIL_C mm, ele passa por cima de
// qualquer componente mais baixo que H_COMP - TATIL_C, o que elimina a
// dependência de acertar a posição no milímetro.
//
// Dimensionado para o 6x6x4.3: corpo de 3,5 mm e atuador sobressaindo 0,8.
// Esses 0,8 não vencem os 2 mm da tampa — solto, o atuador ficaria 1,2 mm
// afundado no furo e ninguém apertaria com o dedo. Por isso a tampa é AFINADA
// no ponto: um rebaixo de TATIL_DEDO de diâmetro deixa só TATIL_ATU mm de
// material, e aí o atuador fica rente ao fundo do rebaixo, com espaço para a
// ponta do dedo entrar. Curso de tátil é ~0,25 mm, então rente basta.
//
// Se quiser botão saliente, cole um capuz impresso no atuador — ou use a
// variante de 9 mm, que dispensa o rebaixo.
//
// O botão entra no bolso pela face interna e é preso por atrito — uma gota de
// cola quente resolve se ficar folgado. Os dois fios saem pelo rasgo lateral e
// vão ao RST e ao GND.
RESET_TIPO  = "interruptor";  // "tatil" | "interruptor" | "furo"

TATIL_LADO = 6.0;  // mm, lado do botão
TATIL_L    = TATIL_LADO + 2 * TOL;  // mm, lado do bolso
TATIL_CANTO = 1.4; // mm, alívio de canto — ver nota no bolso
TATIL_C    = 3.5;  // mm, altura do CORPO, sem o atuador
TATIL_ATU  = 0.8;  // mm, quanto o atuador sobressai do corpo
TATIL_D    = 4.5;  // mm, furo do atuador
// O rebaixo do dedo foi ABANDONADO. A tampa só imprime sem suporte com a face
// de cima na mesa (é a orientação em que as nervuras de 18 mm ficam para
// cima), e nessa posição o rebaixo vira um vão de 10 mm fechado em ponte, bem
// na face visível. Sem ele a peça sai limpa: face lisa na mesa, furo vertical,
// e o único balanço é um anel de ~1 mm no fundo do bolso.
//
// O atuador fica 1,2 mm afundado no furo. Quem resolve é o CAPUZ, peça
// separada colada nele — imprima com PECA = "capuz".
TATIL_DEDO_ON = false;
TATIL_DEDO = 10;   // mm, só usado se TATIL_DEDO_ON

// Capuz: haste que preenche o furo e cabeça que sobra para o dedo. A haste é
// 0,4 mm mais longa que o vão, para a cabeça flutuar sobre a tampa — assim o
// curso do botão (~0,25 mm) acontece antes de a cabeça encostar.
CAPUZ_H_D = 6.0;   // mm, diâmetro da cabeça
CAPUZ_H_E = 1.5;   // mm, espessura da cabeça
CAPUZ_FOLGA = 0.4; // mm, quanto a cabeça flutua
TATIL_P    = 1.8;  // mm, parede do bolso
TATIL_FIO  = 2.6;  // mm, rasgo lateral por onde saem os dois fios
RESET_D     = 6.1;  // mm, furo de painel para a bucha
RESET_CORPO = 6;    // mm, quanto o corpo + terminais descem sob a tampa
                    //     (medido pelo usuário; eu tinha assumido 14)
RESET_FOLGA = 1.5;  // mm, folga mínima que quero entre o corpo e a placa
// O corpo do interruptor desce RESET_CORPO mm e só sobram H_COMP, então ele
// precisa de placa NUA embaixo: sobre o Pro Micro em soquete ou sobre um JST
// mated (~13 mm cada) não entra, e sobre o mux também não.
//
// A faixa livre sai por eliminação: com o passo de 15,24 o último conector fica
// em -24 e o corpo dele acaba por volta de -21; o mux começa em torno de +9.
// Sobram ~30 mm de placa nua, cujo centro é -6.
//
// O preço é fio mais longo até o RST, que fica lá na ponta do USB. Vale: o RST
// puxa corrente desprezível e o comprimento do fio não incomoda nada.
//
// Confira antes de imprimir: apoie a tampa sobre a placa montada e olhe pelo
// furo. Se enxergar cobre nu, cabe.
// -3 e não -13: o rasgo corrido dos cabos termina em -11, e o bolso do botão
// tem ~10 mm de lado — em -13 os dois se cruzavam e o rasgo abria o alojamento
// ao meio. Em -3 sobram 3 mm de chapa entre um e outro.
//
// Ficar sobre o mux não é problema: o ressalto desce só TATIL_C (3,5 mm) dos
// H_COMP disponíveis, então passa folgado por cima dele (~10 mm).
// -8: cinco milímetros para o lado dos cabos, para sair de cima do TCA. Na
// primeira montagem dava para ver o roxo do mux pelo furo.
RESET_X = -8;      // mm, do centro da PLACA (positivo = lado do USB)
RESET_Y = 0;       // mm, do centro da CAIXA na largura

// --- fixação no perfil 2020
FUROS     = [[-40, 0], [40, 0]];  // mm, [x, y] de cada parafuso
PARAFUSO  = 5.0 + 2 * TOL;   // mm, passagem do M5
CABECA_H  = 2.8;   // mm, altura da cabeça — M5 chata (DIN 7991) tem 2,8
CABECA_D  = 10.0;  // mm, diâmetro da cabeça (só usado se escarear)

// O parafuso entra de DENTRO para fora. A face externa é lisa — escareado ali
// não alojaria nada e só afinaria o fundo. O escareado vai na face INTERNA, e
// com parafuso de cabeça chata ela afunda rente ao fundo, deixando H_SOLDA
// inteiro livre para as pernas soldadas.
//
// Com ESCAREADO = "nenhum" o furo fica reto dos dois lados, mas aí a cabeça
// fica exposta dentro da caixa e come CABECA_H do vão sob a placa: nesse caso
// H_SOLDA precisa subir para CABECA_H + a altura das suas pernas soldadas. O
// assert no fim do arquivo não deixa passar batido.
ESCAREADO = "interno";  // "nenhum" | "interno"

// ALOJAMENTO EXTERNO DO INTERRUPTOR. A placa não tem 12 mm livres em lugar
// nenhum que comporte o corpo do MTS-102, e o Pro Micro não traz botão de RESET
// embarcado — então o interruptor sai do volume da placa e vai para uma
// saliência lateral, onde nenhum componente disputa espaço com ele.
//
// Fica na BASE, não na tampa: assim a tampa sobe sem arrancar os dois fios.
// Eles entram na cavidade por um furo pequeno na parede.
//
// A tampinha de POD_T fecha por cima da cavidade e é ponte na impressão — 3 mm
// de material vencendo ~10 mm de vão, que qualquer impressora faz.
POD      = false;  // desnecessário com o tátil: ele cabe na tampa
POD_LADO = -1;     // 1 ou -1: de que lado da caixa ele sai
// Medido nas fotos com régua: o usuário testou duas posições, ao lado do Pro
// Micro (x ~ +34) e logo abaixo do mux (x ~ -12). Adotada a segunda. Trocar é
// um número — e as duas ficam longe dos entalhes de abertura, em -33,5 e +36,5.
POD_X    = -12;    // mm, ao longo do comprimento (ref. centro da placa)
POD_C    = 20;     // mm, comprimento do alojamento
POD_W    = 16;     // mm, quanto avança para fora da parede
POD_T    = 3;      // mm, espessura da tampinha — é nela que a porca do
                   //     interruptor morde, então não afine
POD_FIO  = 4;      // mm, furo de passagem dos dois fios

ENTALHE = true;    // recortes para alavancar a tampa na hora de abrir

$fn = 56;


/* ------------------------------------------------------------- derivados */

C_CAV = PLACA_C + 2 * FOLGA_C + USB_SAI;  // cavidade: comprimento
XC    = USB_SAI / 2;                      // deslocamento da caixa: a placa fica
                                          // centrada em x=0, a caixa não
W_CAV = PLACA_L + 2 * FOLGA;              // cavidade: largura
C_EXT = C_CAV + 2 * T_PAREDE;             // externo
W_EXT = W_CAV + 2 * T_PAREDE;

// Se o interruptor vai na tampa, a altura é ditada por ele; senão, pela placa.
H_COMP = RESET_TIPO == "interruptor" && !POD
       ? max(H_COMP_MIN, ALT_SOB_RESET + RESET_CORPO + RESET_FOLGA)
       : H_COMP_MIN;

Z_PLACA = T_FUNDO + H_SOLDA;              // face de baixo da placa
Z_TOPO  = Z_PLACA + PLACA_E;              // face de cima da placa
H_BASE  = Z_TOPO + H_COMP;                // topo da parede da bandeja


/* --------------------------------------------------------------- módulos */

// Cunha de trava: face reta em cima (é o que segura), rampa embaixo (é o que
// deixa a tampa entrar sem forçar).
module friso(comp, p = FRISO_P, h = FRISO_H) {
    hull() {
        cube([comp, 0.01, h], center = true);
        translate([0, p, h / 2 - 0.005]) cube([comp, 0.01, 0.01], center = true);
    }
}

// Rasgo de cantos arredondados: aresta viva em saída de cabo corta a capa.
module rasgo(c, l, r, h) {
    hull()
        for (sx = [-1, 1], sy = [-1, 1])
            translate([sx * (c / 2 - r), sy * (l / 2 - r), 0])
                cylinder(r = r, h = h);
}

module aberturas_ponta() {
    // USB numa ponta, chicotes na outra, ambos acima da face da placa
    z0 = Z_TOPO + USB_Z - USB_H / 2;                       // base do rasgo
    z1 = USB_ABERTO ? H_BASE + 1 : Z_TOPO + USB_Z + USB_H / 2;
    translate([XC + C_EXT / 2 - T_PAREDE / 2, USB_Y, (z0 + z1) / 2])
        cube([T_PAREDE * 3, USB_L, z1 - z0], center = true);
    if (CABO_LATERAL)
        translate([XC - C_EXT / 2 + T_PAREDE / 2, CABO_Y, Z_TOPO + CABO_H / 2])
            cube([T_PAREDE * 3, CABO_L, CABO_H], center = true);
}

module furos_perfil() {
    for (f = FUROS) {
        translate([f[0], f[1], -1])
            cylinder(d = PARAFUSO, h = T_FUNDO + 2);
        if (ESCAREADO == "interno")
            translate([f[0], f[1], T_FUNDO - CABECA_H])
                cylinder(d1 = PARAFUSO, d2 = CABECA_D, h = CABECA_H + 0.01);
    }
}

module sulcos_tampa() {
    // sulco na face interna de cada parede longa, onde o friso trava
    z = H_BASE - FRISO_Z;
    for (s = [-1, 1])
        translate([XC, s * (W_CAV / 2), z])
            rotate([0, 0, s == 1 ? 0 : 180])
                friso(C_CAV + 1, FRISO_P + FRISO_F, FRISO_H + 2 * FRISO_F);
}

// Saliência lateral que abriga o interruptor, fora do volume da placa.
module pod_corpo() {
    translate([POD_X, POD_LADO * (W_EXT / 2 + POD_W / 2), H_BASE / 2])
        cube([POD_C, POD_W, H_BASE], center = true);
}

module pod_vazios() {
    yc = POD_LADO * (W_EXT / 2 + POD_W / 2);
    z  = H_BASE - POD_T - RESET_CORPO / 2;
    // Cavidade do corpo, ABERTA POR BAIXO. Fechada, o único acesso seria o furo
    // da bucha (RESET_D) e o corpo do interruptor — bem maior — nunca entraria.
    // Aberta assim, ele sobe por baixo, a bucha atravessa a tampinha e a porca
    // aperta por cima. O lado de baixo do alojamento fica no ar: ele é externo à
    // caixa, então não apoia no perfil e o rasgo não atrapalha a fixação.
    translate([POD_X, yc, (H_BASE - POD_T) / 2 - 0.5])
        cube([POD_C - 2 * POD_T, POD_W - 2 * POD_T, H_BASE - POD_T + 1],
             center = true);
    // furo da bucha roscada, na tampinha
    translate([POD_X, yc, H_BASE - POD_T - 1])
        cylinder(d = RESET_D, h = POD_T + 2);
    // passagem dos fios para dentro da caixa
    translate([POD_X, POD_LADO * W_EXT / 2, z])
        rotate([90, 0, 0])
            cylinder(d = POD_FIO, h = T_PAREDE * 3, center = true);
}

module base() {
    difference() {
        union() {
        translate([XC, 0, H_BASE / 2])
            cube([C_EXT, W_EXT, H_BASE], center = true);
        if (POD) pod_corpo();
        }

        if (POD) pod_vazios();

        // cavidade acima do ressalto
        translate([XC, 0, Z_PLACA + (H_BASE - Z_PLACA) / 2 + 0.5])
            cube([C_CAV, W_CAV, H_BASE - Z_PLACA + 1], center = true);

        // cavidade sob a placa, menor: a diferença das duas é o ressalto
        translate([XC, 0, T_FUNDO + H_SOLDA / 2])
            cube([C_CAV - 2 * APOIO, W_CAV - 2 * APOIO, H_SOLDA + 0.02], center = true);

        aberturas_ponta();
        furos_perfil();
        sulcos_tampa();

        if (ENTALHE)
            for (s = [-1, 1])
                translate([XC + s * C_EXT / 4, 0, H_BASE])
                    rotate([90, 0, 0])
                        cylinder(d = 5, h = W_EXT + 2, center = true);
    }
}

// Ressalto que aloja o botão tátil na face interna da tampa.
module tatil_bloco() {
    // Sobe 0,1 dentro da chapa: encostar exatamente em z=0 cria face coincidente
    // na união, e o resultado sai não-manifold.
    translate([RESET_X, RESET_Y, (-TATIL_C + 0.1) / 2])
        cube([TATIL_L + 2 * TATIL_P, TATIL_L + 2 * TATIL_P, TATIL_C + 0.1],
             center = true);
}

module tatil_vazios() {
    // Bolso do corpo, aberto para baixo, COM ALÍVIO DE CANTO. Bico de 0,4 mm
    // não faz canto vivo: o bolso sai com raio interno, e um corpo quadrado
    // encosta nesse raio antes de assentar. Os quatro furinhos nos cantos
    // abrem espaço para as quinas do botão — é isso, mais que a folga, que
    // fazia ele não entrar.
    translate([RESET_X, RESET_Y, -TATIL_C / 2 - 0.5])
        cube([TATIL_L, TATIL_L, TATIL_C + 1], center = true);
    for (sx = [-1, 1], sy = [-1, 1])
        translate([RESET_X + sx * TATIL_L / 2, RESET_Y + sy * TATIL_L / 2,
                   -TATIL_C / 2 - 0.5])
            cylinder(d = TATIL_CANTO, h = TATIL_C + 1, center = true);
    // furo do atuador: só até onde o atuador chega
    translate([RESET_X, RESET_Y, -0.01])
        cylinder(d = TATIL_D, h = TATIL_ATU + 0.02);
    // furo do atuador, agora atravessando a tampa inteira
    translate([RESET_X, RESET_Y, -0.02])
        cylinder(d = TATIL_D, h = T_TAMPA + 1);
    if (TATIL_DEDO_ON)
        translate([RESET_X, RESET_Y, TATIL_ATU - 0.05])
            cylinder(d = TATIL_DEDO, h = T_TAMPA - TATIL_ATU + 1.05);
    // rasgo dos fios
    translate([RESET_X, RESET_Y, -TATIL_C / 2])
        cube([TATIL_L + 2 * TATIL_P + 2, TATIL_FIO, TATIL_C - 1], center = true);
}

module tampa() {
    difference() {
        union() {
            translate([XC, 0, T_TAMPA / 2])
                cube([C_EXT, W_EXT, T_TAMPA], center = true);

            // nervuras: descem até a face de cima da placa e a prensam
            // Sobem 0,1 dentro da chapa: encostar exatamente em z=0 deixa
            // face coincidente na união.
            for (s = [-1, 1])
                translate([XC, s * ((W_CAV - APOIO) / 2 - TOL),
                           (-(H_COMP - NERVURA_FOLGA) + 0.1) / 2])
                    cube([C_CAV - 2 * TOL, APOIO,
                          H_COMP - NERVURA_FOLGA + 0.1], center = true);

            if (RESET_TIPO == "tatil") tatil_bloco();

            // Friso de trava. O z é -FRISO_Z e NÃO -FRISO_Z + T_TAMPA: a
            // tampa apoia a face de baixo no topo da parede, então a origem
            // dela já é H_BASE e o friso cai no mesmo plano do sulco.
            for (s = [-1, 1])
                translate([XC, s * (W_CAV / 2 - TOL - 0.01), -FRISO_Z])
                    rotate([0, 0, s == 1 ? 0 : 180])
                        friso(C_CAV - 2 * TOL - 0.4);
        }
        if (RESET_TIPO == "tatil") tatil_vazios();
        else if (!POD)
            translate([RESET_X, RESET_Y, -1])
                cylinder(d = RESET_D, h = T_TAMPA + 2);

        for (p = SAIDAS)
            translate([p[0], p[1], -1])
                rasgo(SAIDA_UNICA ? SAIDA_UC : SAIDA_C, SAIDA_L, SAIDA_R,
                      T_TAMPA + 2);
    }
}


/* --------------------------------------------------------- verificação */

SOB_RESET = RESET_TIPO == "interruptor" ? H_COMP - RESET_CORPO : H_COMP;
echo(str("interruptor de RESET: desce ", RESET_CORPO, " mm sob a tampa | H_COMP ",
         H_COMP, " mm | sobra ", SOB_RESET, " mm ate a placa"));
assert(POD || RESET_TIPO != "interruptor" || SOB_RESET >= RESET_FOLGA,
       "O corpo do interruptor nao cabe: aumente H_COMP ou use RESET_TIPO=\"furo\".");

VAO_LIVRE = ESCAREADO == "interno" ? H_SOLDA : H_SOLDA - CABECA_H;
echo(str("cabeça do parafuso: ", CABECA_H, " mm | vão sob a placa: ", H_SOLDA,
         " mm | sobra ", VAO_LIVRE, " mm para as pernas soldadas"));
assert(VAO_LIVRE > 0,
       "A cabeça do parafuso não cabe sob a placa. Use ESCAREADO=\"interno\" ou aumente H_SOLDA.");


/* ------------------------------------------------------------ montagem */

// Capuz do botão: cola no atuador do tátil e sobra para fora da tampa.
module capuz() {
    haste = T_TAMPA - TATIL_ATU + CAPUZ_FOLGA;
    cylinder(d = TATIL_D - 2 * TOL, h = haste);
    translate([0, 0, haste])
        cylinder(d = CAPUZ_H_D, h = CAPUZ_H_E);
}

if (PECA == "base")  base();
else if (PECA == "tampa") tampa();
else if (PECA == "capuz") capuz();
else {
    base();
    translate([0, 0, H_BASE + 18]) tampa();   // explodida, só para conferir
}
