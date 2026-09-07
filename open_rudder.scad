//==============================================================
// Open Rudder — Rudder Pedal magnético para simulação de voo
//--------------------------------------------------------------
// Conceito: barra de leme central (rudder bar) com:
//  * Centragem magnética sem contato (repulsão N-N), força
//    ajustável de 0-100% por um único anel helicoidal (estilo
//    zoom de lente). 0% = modo helicóptero.
//  * Amortecimento por correntes de Foucault (disco de cobre
//    + garfo de ímãs deslizante) — viscoso, sem fluido.
//  * Freios de biqueira isométricos com célula de carga.
//  * Sensor de eixo AS5600 (Hall, sem contato).
//
// Fabricação: perfis de alumínio 2020 + peças impressas
// (PETG/ASA, 5 perímetros, 40% infill nas estruturais).
//
// Renderização:
//   part = "assembly"  -> montagem completa (use bar_angle)
//   part = "exploded"  -> montagem expandida em Z
//   ou o nome de uma peça imprimível (lista abaixo)
//==============================================================

part = "assembly";
// peças imprimíveis: "lower_block", "upper_block", "shell_half",
// "force_ring", "force_collar", "rotor", "eddy_hub", "eddy_yoke",
// "bar_hub", "pedal_post", "pedal_plate", "foot_bracket"

bar_angle = 0;          // deflexão da barra p/ visualização (-17..17)
ring_lift = 0;          // elevação do anel estator 0=força máx .. 18=0%
yoke_engage = 1.0;      // 0..1 engajamento do amortecedor eddy
explode = 0;            // 0 normal; ~30 para vista explodida

$fn = 72;
EPS = 0.01;

//----------------------------------------------- parâmetros gerais
travel_deg   = 17;      // curso ±17°
ext          = 20;      // perfil 2020
base_len     = 380;     // trilhos Y (profundidade)
base_width   = 420;     // trilho X (largura)
rail_x       = 190;     // posição dos trilhos Y

shaft_d      = 8;       // eixo aço 8 mm
brg_od       = 22;      // rolamento 608
brg_h        = 7;

// pilha vertical (z)
z_base       = ext;             // topo do perfil da base
z_lb0        = z_base;          // bloco inferior
z_lb1        = 62;
z_shaft0     = 33;
z_shaft1     = 172;
z_eddy       = 72;              // plano do disco de cobre
z_rotor      = 98;              // plano dos ímãs de centragem
z_ring0      = 116;             // base do anel estator (engajado)
ring_h       = 12;
z_ub0        = 140;             // bloco superior
z_ub1        = 168;
z_hub0       = 172;             // cubo da barra
z_bar        = 184;             // centro da barra 2020

// centragem magnética
mag_d        = 10;              // ímãs N52 Ø10x5 (empilhar 2 = 10 mm)
mag_h        = 10;
mag_r        = 75;              // raio dos ímãs
stator_ang   = 30;              // ímãs do estator a ±30° de cada ±Y
finger_w     = 15;

// amortecedor eddy
eddy_d       = 120;             // disco de cobre Ø120 x 2 mm
eddy_t       = 2;
yoke_mag     = [20, 20, 10];    // ímãs de bloco N52

// carcaça / anel de ajuste
shell_id     = 192;
shell_od     = 204;
collar_id    = 206;
collar_od    = 218;
collar_h     = 46;

// barra e pedais
bar_len      = 400;
pedal_x      = 170;             // centro do pedal
plate_w      = 100;
plate_l      = 160;
plate_t      = 12;
plate_tilt   = 35;              // graus a partir da vertical (55° do chão:
                                // ergonomia de calcanhar no chão)
z_plate0     = 40;              // borda inferior da chapa do pedal

// ponto de contato do freio na chapa (local) e sua posição global,
// derivados de plate_tilt — a célula de carga acompanha o ângulo.
// fica no meio da chapa: célula e escora escondidas SOB a rampa,
// nunca acima da superfície de pisada
pc  = plate_l - 70;
pcy = 10 + 4*cos(plate_tilt) + (pc - 8)*sin(plate_tilt);
pcz = z_plate0 - 4*sin(plate_tilt) + (pc - 8)*cos(plate_tilt);

// células de carga barra 50 kg (YZC-131): 80 x 12.7 x 12.7
lc = [80, 12.7, 12.7];

// cores
C_PRINT  = "#39424e";   // peças impressas (grafite)
C_ACCENT = "#ff7a1a";   // peças de interface (laranja)
C_ALU    = "#c9ced4";
C_STEEL  = "#8f98a3";
C_COPPER = "#c87533";
C_MAG    = "#4a4a52";
C_PCB    = "#1f7a4d";

//==============================================================
// utilitários
//==============================================================
module extrusion2020(l) {
    color(C_ALU) linear_extrude(l) difference() {
        offset(r = 1.5) square(ext - 3, center = true);
        circle(d = 4.2);
        for (a = [0:90:270]) rotate(a) {
            translate([ext/2, 0]) square([3, 6.2], center = true);
            translate([ext/2 - 2.6, 0]) square([3, 11], center = true);
        }
    }
}

module magnet_cyl(d = mag_d, h = mag_h) color(C_MAG) cylinder(d = d, h = h);

module bearing608() color(C_STEEL) difference() {
    cylinder(d = brg_od, h = brg_h);
    translate([0, 0, -EPS]) cylinder(d = shaft_d, h = brg_h + 2*EPS);
}

module knurl(d, h, n = 60) {
    for (a = [0 : 360/n : 359])
        rotate(a) translate([d/2, 0, h/2]) cube([1.6, 1.6, h], center = true);
}

//==============================================================
// BASE — quadro de alumínio em H
//==============================================================
module frame() {
    // trilhos longitudinais (Y)
    for (sx = [-1, 1])
        translate([sx*rail_x, -base_len/2, ext/2])
            rotate([-90, 0, 0]) extrusion2020(base_len);
    // travessa central (X) — suporta a torre
    translate([-(base_width/2 - 30), 0, ext/2])
        rotate([0, 90, 0]) extrusion2020(base_width - 60);
    // pés de borracha
    color(C_MAG) for (sx = [-1, 1], sy = [-1, 1])
        translate([sx*rail_x, sy*(base_len/2 - 15), -3])
            cylinder(d = 24, h = 3);
}

//==============================================================
// BLOCO INFERIOR — mancal, sensor AS5600, guia do garfo eddy
//==============================================================
module lower_block() {
    difference() {
        union() {
            // flange sobre a travessa
            translate([0, 0, z_lb0]) linear_extrude(6)
                offset(r = 8) square([104, 74], center = true);
            // corpo
            translate([0, 0, z_lb0]) cylinder(d = 88, h = z_lb1 - z_lb0);
            // boca de fixação da carcaça
            translate([0, 0, z_lb1 - 6]) cylinder(d = shell_od, h = 6);
            // guia radial do garfo eddy (+Y)
            translate([-16, 40, z_lb0]) cube([32, 80, 26]);
        }
        // furo do eixo + alojamento do rolamento
        translate([0, 0, z_lb0 - EPS]) cylinder(d = 12, h = 60);
        translate([0, 0, z_lb1 - brg_h]) cylinder(d = brg_od + 0.4, h = brg_h + EPS);
        // nicho da PCB AS5600 (frente -Y)
        translate([-11, -46, z_lb0 + 6]) cube([22, 30, 4]);
        // canal do carrinho do garfo (rabo de andorinha simplificado)
        translate([-11, 38, z_lb0 + 12]) cube([22, 84, 15]);
        // parafusos M5 -> porcas T da travessa
        for (sx = [-1, 1], sy = [-1, 1])
            translate([sx*44, sy*28, z_lb0 - EPS]) cylinder(d = 5.4, h = 8);
    }
}

//==============================================================
// BLOCO SUPERIOR — mancal superior + batentes de fim de curso
//==============================================================
module upper_block() {
    difference() {
        union() {
            translate([0, 0, z_ub0]) cylinder(d = shell_od, h = 6);
            translate([0, 0, z_ub0]) cylinder(d = 88, h = z_ub1 - z_ub0);
            // orelhas dos batentes
            for (a = [90 - travel_deg - 6, 90 + travel_deg + 6,
                      270 - travel_deg - 6, 270 + travel_deg + 6])
                rotate(a) translate([34, -6, z_ub1 - 10]) cube([26, 12, 10]);
        }
        translate([0, 0, z_ub0 - EPS]) cylinder(d = brg_od + 0.4, h = brg_h + EPS);
        translate([0, 0, z_ub0 - EPS]) cylinder(d = 12, h = z_ub1 - z_ub0 + 2*EPS);
    }
    // batentes de borracha
    color(C_MAG) for (a = [90 - travel_deg - 6, 90 + travel_deg + 6,
                           270 - travel_deg - 6, 270 + travel_deg + 6])
        rotate(a) translate([52, 0, z_ub1 - 5]) sphere(d = 10);
}

//==============================================================
// CARCAÇA CILÍNDRICA ("turbina") — 2 metades
//==============================================================
module shell_half() {
    difference() {
        translate([0, 0, z_lb1]) cylinder(d = shell_od, h = z_ub0 - z_lb1);
        translate([0, 0, z_lb1 - EPS])
            cylinder(d = shell_id, h = z_ub0 - z_lb1 + 2*EPS);
        // corta a metade
        translate([-200, 0, z_lb1 - 1]) cube([400, 200, 120]);
        // 3 rasgos verticais p/ pinos do anel estator
        for (a = [0, 120, 240]) rotate(a)
            translate([shell_id/2 - 4, -3, z_ring0 - 4]) cube([12, 6, ring_h + 24]);
        // janela do garfo eddy (+Y é da outra metade; janela do cabo -Y)
        translate([-10, -shell_od/2 - 1, z_lb1 + 2]) cube([20, 10, 12]);
    }
}
module shell() {
    for (m = [0, 1]) mirror([0, m, 0]) shell_half();
}

//==============================================================
// ROTOR — disco com 2 remos porta-ímãs (eixo do leme)
//==============================================================
module rotor() {
    difference() {
        union() {
            translate([0, 0, z_rotor - 12]) cylinder(d = 96, h = 12);
            // remos em ±Y até o raio dos ímãs
            for (sy = [0, 180]) rotate(sy) hull() {
                translate([0, 34, z_rotor - 12]) cylinder(d = 26, h = 12);
                translate([0, mag_r, z_rotor - 12]) cylinder(d = finger_w + 4, h = 12);
            }
        }
        translate([0, 0, z_rotor - 12 - EPS]) cylinder(d = shaft_d + 0.2, h = 14);
        // bolsos dos ímãs (empilha 2x Ø10x5, N para cima)
        for (sy = [0, 180]) rotate(sy)
            translate([0, mag_r, z_rotor - mag_h + 1])
                cylinder(d = mag_d + 0.3, h = mag_h + 1);
        // parafuso de aperto M4 no cubo
        translate([0, 0, z_rotor - 6]) rotate([0, 90, 30])
            cylinder(d = 4.2, h = 60);
    }
}
module rotor_magnets() {
    for (sy = [0, 180]) rotate(sy)
        translate([0, mag_r, z_rotor - mag_h + 1]) magnet_cyl();
}

//==============================================================
// ANEL DE FORÇA (estator) — 4 dedos com ímãs, sobe/desce
//==============================================================
module force_ring(lift = 0) {
    zr = z_ring0 + lift;
    color(C_PRINT) difference() {
        union() {
            translate([0, 0, zr]) difference() {
                cylinder(d = shell_id - 4, h = ring_h);
                translate([0, 0, -EPS]) cylinder(d = 124, h = ring_h + 2*EPS);
            }
            // 4 dedos descem até o plano do rotor
            for (a = [90 - stator_ang, 90 + stator_ang,
                      270 - stator_ang, 270 + stator_ang])
                rotate(a - 90) translate([-finger_w/2, mag_r - finger_w/2, zr - 17])
                    cube([finger_w, finger_w, 17 + EPS]);
            // 3 pinos guia (rasgo da carcaça + hélice do colar)
            for (a = [0, 120, 240]) rotate(a)
                translate([0, 0, zr + ring_h/2]) rotate([0, 90, 0])
                    cylinder(d = 5, h = collar_od/2 - 2);
        }
        // bolsos dos ímãs nos dedos (mesma polaridade dos do rotor)
        for (a = [90 - stator_ang, 90 + stator_ang,
                  270 - stator_ang, 270 + stator_ang])
            rotate(a - 90) translate([0, mag_r, zr - 17 - EPS])
                cylinder(d = mag_d + 0.3, h = mag_h + 1);
    }
    // ímãs
    for (a = [90 - stator_ang, 90 + stator_ang,
              270 - stator_ang, 270 + stator_ang])
        rotate(a - 90) translate([0, mag_r, zr - 17]) magnet_cyl();
}

//==============================================================
// COLAR DE AJUSTE — anel externo com rasgos helicoidais
// (girar 120° = anel de força sobe 18 mm => força 100% -> 0%)
//==============================================================
module force_collar() {
    color(C_ACCENT) {
        difference() {
            translate([0, 0, z_ring0 - 8]) cylinder(d = collar_od, h = collar_h);
            translate([0, 0, z_ring0 - 8 - EPS])
                cylinder(d = collar_id, h = collar_h + 2*EPS);
            // 3 rasgos helicoidais para os pinos
            for (a = [0, 120, 240]) rotate(a)
                translate([0, 0, z_ring0 + 2]) linear_extrude(22, twist = -120)
                    translate([collar_od/2 - 4, 0]) square([12, 6], center = true);
        }
        translate([0, 0, z_ring0 - 8]) knurl(collar_od, collar_h);
        // marcador de escala
        translate([0, -collar_od/2 - 1, z_ring0 - 8 + collar_h/2])
            sphere(d = 5);
    }
}

//==============================================================
// AMORTECEDOR EDDY — disco de cobre + garfo deslizante
//==============================================================
module eddy_hub() {
    difference() {
        union() {
            translate([0, 0, z_eddy - 8]) cylinder(d = 30, h = 16);
            translate([0, 0, z_eddy - 1.2]) cylinder(d = 46, h = 2.4 + eddy_t);
        }
        translate([0, 0, z_eddy - 8 - EPS]) cylinder(d = shaft_d + 0.2, h = 18);
        translate([0, 0, z_eddy]) rotate([0, 90, 0]) cylinder(d = 4.2, h = 30);
    }
}
module eddy_disc() {
    color(C_COPPER) translate([0, 0, z_eddy])
        difference() {
            cylinder(d = eddy_d, h = eddy_t);
            translate([0, 0, -EPS]) cylinder(d = 20, h = eddy_t + 2*EPS);
        }
}
module eddy_yoke(engage = 1) {
    // desliza radialmente em +Y sobre a guia do bloco inferior
    y0 = eddy_d/2 - 14*engage;   // profundidade de engajamento
    color(C_ACCENT) translate([0, y0, 0]) difference() {
        union() {
            // C que abraça o disco
            translate([-14, 0, z_eddy - 12]) cube([28, 34, 10]);       // baixo
            translate([-14, 0, z_eddy + eddy_t + 2]) cube([28, 34, 10]); // cima
            translate([-14, 24, z_eddy - 12]) cube([28, 10, 26]);      // costas
            // carrinho na guia
            translate([-10, 24, z_lb0 + 12]) cube([20, 60, z_eddy - 12 - (z_lb0 + 12)]);
            // manípulo
            translate([0, 92, z_lb0 + 20]) rotate([90, 0, 0]) cylinder(d = 18, h = 10);
        }
        // bolsos dos ímãs de bloco (faces N-S opostas através do disco)
        translate([-10, 2, z_eddy - 12 + 4]) cube([20, 20, 6.2]);
        translate([-10, 2, z_eddy + eddy_t + 2]) cube([20, 20, 6.2]);
    }
    color(C_MAG) translate([0, y0, 0]) {
        translate([-10, 2, z_eddy - 12 + 4]) cube([20, 20, 6]);
        translate([-10, 2, z_eddy + eddy_t + 2.2]) cube([20, 20, 6]);
    }
}

//==============================================================
// EIXO, SENSOR, CUBO DA BARRA
//==============================================================
module shaft() {
    color(C_STEEL) translate([0, 0, z_shaft0]) cylinder(d = shaft_d, h = z_shaft1 - z_shaft0);
    // ímã diametral do sensor na ponta inferior
    color(C_MAG) translate([0, 0, z_shaft0 - 2.5]) cylinder(d = 6, h = 2.5);
}
module sensor_pcb() {
    color(C_PCB) translate([-10, -12, z_lb0 + 7]) cube([20, 24, 1.6]);
}

module bar_hub() {
    difference() {
        union() {
            translate([0, 0, z_hub0 - 6]) cylinder(d = 44, h = 6);
            // berço que abraça a barra 2020
            translate([-30, -16, z_hub0]) cube([60, 32, 30]);
            // asas que tocam os batentes
            for (sy = [-1, 1]) hull() {
                translate([0, sy*16, z_hub0]) cube([40, 2, 8], center = true);
                translate([0, sy*52, z_hub0]) cube([16, 2, 8], center = true);
            }
        }
        translate([-31, -(ext + 0.4)/2, z_hub0 + 6]) cube([62, ext + 0.4, ext + 0.4]);
        translate([0, 0, z_hub0 - 6 - EPS]) cylinder(d = shaft_d + 0.2, h = 40);
        // parafusos de fechamento M5
        for (sx = [-1, 1]) translate([sx*24, 0, z_hub0 - 6 - EPS]) cylinder(d = 5.2, h = 40);
    }
}

module rudder_bar() {
    translate([-bar_len/2, 0, z_bar]) rotate([0, 90, 0]) rotate([0,0,90]) extrusion2020(bar_len);
    // tampas das pontas
    color(C_ACCENT) for (sx = [-1, 1])
        translate([sx*(bar_len/2 + 1.5), 0, z_bar]) cube([3, ext + 4, ext + 4], center = true);
}

//==============================================================
// PEDAL — poste, chapa com pivô de biqueira e célula de carga
//==============================================================
module loadcell() {
    color(C_ALU) cube(lc, center = true);
    color(C_PCB) translate([0, 0, lc[2]/2]) cube([20, lc[1], 1], center = true);
}

// Poste em "C": todo o suporte chega POR TRÁS da chapa —
// nada cruza a superfície de pisada.
module pedal_post() {
    difference() {
        union() {
            // garra na barra
            translate([-14, -16, z_bar - 26]) cube([28, 32, 52]);
            // braço superior: passa POR CIMA da borda da chapa
            hull() {
                translate([-14, 8, 172]) cube([28, 8, 30]);
                translate([-14, 112, 168]) cube([28, 22, 30]);
            }
            // coluna traseira, atrás da chapa
            translate([-14, 112, 36]) cube([28, 22, 138]);
            // braço inferior em cunha, SOB a rampa, até o pivô
            hull() {
                translate([-14, 108, 36]) cube([28, 26, 24]);
                for (sx = [-1, 1]) translate([sx*17, 10, z_plate0])
                    rotate([0, 90, 0]) cylinder(d = 16, h = 6, center = true);
            }
            // orelhas do pivô (charneira inferior)
            for (sx = [-1, 1]) translate([sx*17, 10, z_plate0]) rotate([0, 90, 0])
                cylinder(d = 16, h = 6, center = true);
            // bloco da célula de carga, aparafusado à coluna
            translate([-10, pcy + 12, pcz - 24])
                cube([20, 116 - (pcy + 12), 48]);
        }
        translate([-(ext + 0.4)/2, -(ext + 0.4)/2, z_bar - (ext + 0.4)/2])
            cube([ext + 0.4, ext + 0.4, ext + 0.4]);
        // pino do pivô M5
        translate([-25, 10, z_plate0]) rotate([0, 90, 0]) cylinder(d = 5.2, h = 50);
        // parafusos da célula
        translate([0, pcy + 30, pcz - 12]) rotate([90, 0, 0]) cylinder(d = 4.2, h = 24);
        translate([0, pcy + 30, pcz + 12]) rotate([90, 0, 0]) cylinder(d = 4.2, h = 24);
    }
}

module pedal_plate() {
    difference() {
        union() {
            cube([plate_w, plate_t, plate_l]);
            // nervuras (4 mm p/ não tocar a célula de carga)
            for (x = [8, plate_w/2 - 2, plate_w - 12])
                translate([x, plate_t, 4]) cube([4, 4, plate_l - 30]);
            // apoios do pivô
            for (sx = [0, 1]) translate([14 + sx*(plate_w - 28) - 5, plate_t + 2, 8])
                rotate([0, 90, 0]) cylinder(d = 16, h = 10);
        }
        // pino do pivô
        translate([-EPS, plate_t + 2, 8]) rotate([0, 90, 0])
            cylinder(d = 5.2, h = plate_w + 2*EPS);
        // grip: ranhuras
        for (z = [14 : 9 : plate_l - 10])
            translate([-EPS, -1, z]) cube([plate_w + 2*EPS, 2.2, 3]);
    }
    // batoque no dorso da chapa que pressiona a célula de carga
    color(C_ACCENT) translate([plate_w/2, plate_t, pc])
        rotate([-90, 0, 0]) cylinder(d = 12, h = 6);
}

module pedal_assembly(side = 1) {
    // side = +1 direita, -1 esquerda
    translate([side*pedal_x, 0, 0]) {
        color(C_PRINT) pedal_post();
        // chapa inclinada — rotação em torno do EIXO DO PINO:
        // o furo da chapa (local y=14, z=8) cai exatamente no
        // pino do poste em (y=10, z=z_plate0)
        translate([0, 10, z_plate0]) rotate([-plate_tilt, 0, 0])
            translate([-plate_w/2, -14, -8]) color(C_ACCENT) pedal_plate();
        // célula de carga atrás da chapa, no ponto de contato do batoque
        translate([0, pcy + 6, pcz]) loadcell();
    }
}

//==============================================================
// ELETRÔNICA — caixa RP2040 + 2x HX711 no trilho traseiro
//==============================================================
module electronics_box() {
    // na ponta dianteira do trilho Y direito, fora da varredura dos pedais
    color(C_PRINT) translate([rail_x - 23, -178, z_base]) difference() {
        cube([46, 70, 22]);
        translate([3, 3, 3]) cube([40, 64, 22]);
    }
    color(C_PCB) translate([rail_x - 16, -171, z_base + 4]) cube([18, 24, 1.6]); // RP2040-Zero
    color(C_PCB) translate([rail_x - 16, -143, z_base + 4]) cube([16, 21, 1.6]); // HX711 x2
    color(C_PCB) translate([rail_x + 4, -143, z_base + 4]) cube([16, 21, 1.6]);
}

//==============================================================
// MONTAGEM
//==============================================================
module moving_group(a) {
    rotate([0, 0, a]) {
        shaft();
        color(C_PRINT) rotor();
        rotor_magnets();
        color(C_PRINT) eddy_hub();
        eddy_disc();
        color(C_PRINT) bar_hub();
        rudder_bar();
        for (s = [-1, 1]) pedal_assembly(s);
    }
}

module assembly(a = bar_angle, ex = 0) {
    frame();
    translate([0, 0, 0])        { color(C_PRINT) lower_block(); sensor_pcb(); }
    translate([0, 0, 0.4*ex])   bearing608_at(z_lb1 - brg_h);
    translate([0, 0, 0.8*ex])   eddy_yoke(yoke_engage);
    translate([0, 0, 1.2*ex])   moving_group(a);
    translate([0, 0, 1.6*ex])   force_ring(ring_lift);
    translate([0, 0, 1.8*ex])   force_collar();
    translate([0, 0, 2.0*ex])   color(C_PRINT, 0.55) shell();
    translate([0, 0, 2.4*ex])   { bearing608_at(z_ub0); color(C_PRINT) upper_block(); }
    electronics_box();
}
module bearing608_at(z) translate([0, 0, z]) bearing608();

//==============================================================
// SELETOR DE PEÇAS
//==============================================================
if (part == "assembly")          assembly(bar_angle, 0);
else if (part == "cutaway")      difference() {
                                     assembly(bar_angle, 0);
                                     translate([0, -400, 10]) cube([400, 400, 300]);
                                 }
else if (part == "exploded")     assembly(bar_angle, explode == 0 ? 30 : explode);
else if (part == "lower_block")  lower_block();
else if (part == "upper_block")  upper_block();
else if (part == "shell_half")   rotate([0, 0, 0]) shell_half();
else if (part == "force_ring")   force_ring(0);
else if (part == "force_collar") force_collar();
else if (part == "rotor")        { rotor(); }
else if (part == "eddy_hub")     eddy_hub();
else if (part == "eddy_yoke")    eddy_yoke(0);
else if (part == "bar_hub")      bar_hub();
else if (part == "pedal_post")   pedal_post();
else if (part == "pedal_plate")  pedal_plate();
else echo("part desconhecida: use assembly/exploded ou nome de peça");
