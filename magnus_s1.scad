//==============================================================
// MAGNUS S1 — Manche (stick) com gimbal magnético
//--------------------------------------------------------------
// Irmão do MAGNUS R1. Gimbal cardan de 2 eixos onde nada que
// define o feel encosta em nada:
//  * Cartucho magnético por eixo: paddle no eixo com ímã N52
//    repelido por 2 ímãs de estator (mesma polaridade) a ±28°.
//    Força ajustável por engajamento axial via rodinha lateral —
//    pitch e roll independentes; 0% = modo helicóptero.
//  * Detent central por ATRAÇÃO: par pequeno de ímãs opostos dá
//    centro definido, dosável — repulsão dá o gradiente, atração
//    dá o "click" do centro.
//  * Amortecimento eddy: setor de cobre por eixo entre ímãs de
//    bloco — mata a oscilação do stick sem atrito estático.
//  * 2x AS5600 nas pontas OPOSTAS aos cartuchos (blindagem por
//    arruela de aço no meio do eixo).
//
// part = "assembly" | "cutaway" | peça imprimível:
//   "base_shell", "top_plate", "outer_frame", "inner_block",
//   "paddle", "stator_slider", "stick", "thumbwheel"
//==============================================================

part = "assembly";
pitch_angle = 0;        // -18..18 (visualização)
roll_angle  = 0;        // -18..18
pitch_engage = 1.0;     // 0..1 engajamento do cartucho de pitch
roll_engage  = 1.0;

$fn = 64;
EPS = 0.01;

//----------------------------------------------- parâmetros
travel   = 18;          // curso ±18° por eixo
bw       = 190;         // base (externa, quadrada)
bh       = 110;         // altura das paredes
wall     = 7;
zp       = 72;          // altura do centro do gimbal (pivô)

shaft_d  = 8;
brg_od   = 22; brg_h = 7;

frame_o  = 148;         // anel externo do gimbal (lado)
bar_w    = 16;          // seção das barras do anel
bar_h    = 24;

mag_d    = 10; mag_h = 10;   // ímãs de repulsão N52
pad_r    = 42;               // raio do ímã do paddle
stat_ang = 28;               // estator a ±28°

stick_d  = 22;
stick_l  = 150;         // do bloco interno ao punho
grip_l   = 66;

// cores (linguagem MAGNUS)
C_PRINT  = "#39424e";
C_ACCENT = "#ff7a1a";
C_ALU    = "#c9ced4";
C_STEEL  = "#8f98a3";
C_COPPER = "#c87533";
C_MAG    = "#4a4a52";
C_PCB    = "#1f7a4d";

module magnet_x(h = mag_h) color(C_MAG) rotate([0, 90, 0]) cylinder(d = mag_d, h = h);
module magnet_y(h = mag_h) color(C_MAG) rotate([-90, 0, 0]) cylinder(d = mag_d, h = h);
module bearing(axis = "x") color(C_STEEL)
    rotate(axis == "x" ? [0, 90, 0] : [-90, 0, 0]) difference() {
        cylinder(d = brg_od, h = brg_h);
        translate([0, 0, -EPS]) cylinder(d = shaft_d, h = brg_h + 2*EPS);
    }
module knurl_wheel(d, h) {
    cylinder(d = d, h = h);
    for (a = [0:20:340]) rotate(a) translate([d/2, 0, h/2])
        cube([1.4, 1.4, h], center = true);
}

//==============================================================
// BASE — casca com mancais de pitch, guias e eletrônica
//==============================================================
module base_shell() {
    difference() {
        union() {
            // paredes + piso
            difference() {
                translate([-bw/2, -bw/2, 0]) cube([bw, bw, bh]);
                translate([-bw/2 + wall, -bw/2 + wall, 6])
                    cube([bw - 2*wall, bw - 2*wall, bh]);
            }
            // bossas dos rolamentos de pitch (paredes ±X)
            for (sx = [-1, 1]) translate([sx*(bw/2 - wall - 8), 0, zp])
                rotate([0, sx*90, 0]) cylinder(d = 34, h = 8 + wall);
            // guia do carrinho estator (piso, lado +X)
            translate([44, -26, 6]) cube([46, 52, 8]);
            // guia do garfo eddy (piso, lado -X)
            translate([-88, -22, 6]) cube([40, 44, 8]);
        }
        // furos de eixo nas bossas
        for (sx = [-1, 1]) translate([sx*(bw/2 - wall - 18), 0, zp])
            rotate([0, sx*90, 0]) cylinder(d = 12, h = 30);
        // alojamentos 608
        for (sx = [-1, 1]) translate([sx*(bw/2 - 14.5), 0, zp])
            rotate([0, sx*90, 0]) cylinder(d = brg_od + 0.4, h = brg_h + 0.5);
        // nicho da PCB do sensor de pitch (face externa -X)
        translate([-bw/2 - EPS, -13, zp - 15]) cube([3, 26, 30]);
        // fenda da rodinha de ajuste (parede +X)
        translate([bw/2 - wall - EPS, -3, 22]) cube([wall + 2*EPS, 6, 26]);
        // USB-C (parede -Y)
        translate([-6, -bw/2 - EPS, 12]) cube([12, wall + 2*EPS, 5]);
        // canal do carrinho
        translate([48, -22, 8]) cube([44, 44, 8]);
    }
    // batentes de borracha do curso de pitch (topo das paredes ±Y)
    color(C_MAG) for (sy = [-1, 1])
        translate([0, sy*(bw/2 - wall - 5), zp + 30]) sphere(d = 10);
}

module top_plate() {
    color(C_PRINT) difference() {
        translate([-bw/2, -bw/2, bh]) cube([bw, bw, 6]);
        translate([0, 0, bh - EPS]) cylinder(d = 62, h = 8);
        for (sx = [-1, 1], sy = [-1, 1])
            translate([sx*(bw/2 - 12), sy*(bw/2 - 12), bh - EPS]) cylinder(d = 4.5, h = 8);
    }
    // fole (gaiter) decorativo
    color(C_MAG) for (i = [0:3]) translate([0, 0, bh + 4 + i*5])
        cylinder(d1 = 58 - i*9, d2 = 50 - i*9, h = 5);
}

//==============================================================
// GIMBAL — anel externo (pitch) e bloco interno (roll)
//==============================================================
module outer_frame() {
    difference() {
        union() {
            // anel: barras em Y (x ±66) e em X (y ±66)
            for (sx = [-1, 1]) translate([sx*66 - bar_w/2, -frame_o/2, zp - bar_h/2])
                cube([bar_w, frame_o, bar_h]);
            for (sy = [-1, 1]) translate([-frame_o/2, sy*66 - bar_w/2, zp - bar_h/2])
                cube([frame_o, bar_w, bar_h]);
            // tocos do eixo de pitch (±X) — aço passante no produto
            for (sx = [-1, 1]) translate([sx*62, 0, zp]) rotate([0, sx*90, 0])
                cylinder(d = 16, h = 14);
            // bossas dos rolamentos de roll (barras ±Y)
            for (sy = [-1, 1]) translate([0, sy*66, zp]) rotate([sy > 0 ? -90 : 90, 0, 0])
                cylinder(d = 30, h = bar_w/2 + 4);
            // suporte do estator de roll (pendura da barra +Y)
            translate([-26, 58, 28]) cube([52, 14, zp - bar_h/2 - 28 + EPS]);
            // suporte do garfo eddy de roll (barra -Y)
            translate([-16, -72, 24]) cube([32, 14, zp - bar_h/2 - 24 + EPS]);
        }
        // furo do eixo de roll
        translate([0, -frame_o/2 - 2, zp]) rotate([-90, 0, 0]) cylinder(d = 12, h = frame_o + 4);
        // alojamentos 608 de roll
        for (sy = [-1, 1]) translate([0, sy*(66 - brg_h/2 - 2), zp])
            rotate([sy > 0 ? -90 : 90, 0, 0]) cylinder(d = brg_od + 0.4, h = brg_h + 1, center = true);
    }
}

module inner_block() {
    difference() {
        union() {
            translate([-20, -20, zp - 12]) cube([40, 40, 24]);
            // tocos do eixo de roll
            for (sy = [-1, 1]) translate([0, sy*20, zp]) rotate([sy > 0 ? -90 : 90, 0, 0])
                cylinder(d = 14, h = 52);
            // cone de transição para o stick
            translate([0, 0, zp + 12]) cylinder(d1 = 36, d2 = stick_d, h = 16);
        }
        translate([0, 0, zp - 12 - EPS]) cylinder(d = 5.2, h = 60); // parafuso do stick
    }
}

module stick() {
    color(C_PRINT) translate([0, 0, zp + 28]) cylinder(d = stick_d, h = stick_l);
    // punho
    color(C_PRINT) hull() {
        translate([0, 0, zp + 28 + stick_l]) cylinder(d = 30, h = 8);
        translate([0, -4, zp + 28 + stick_l + grip_l - 12]) rotate([12, 0, 0])
            cylinder(d = 26, h = 12);
    }
    // anel laranja + botões
    color(C_ACCENT) translate([0, 0, zp + 26 + stick_l]) cylinder(d = 31, h = 4);
    color(C_ACCENT) translate([0, -14, zp + 30 + stick_l + grip_l - 26])
        rotate([90, 0, 0]) cylinder(d = 9, h = 3);   // gatilho
    color(C_ACCENT) translate([8, -6, zp + 34 + stick_l + grip_l - 14])
        sphere(d = 7);                                // hat
}

//==============================================================
// CARTUCHO MAGNÉTICO (paddle + estator deslizante) — eixo pitch
//==============================================================
module paddle(axis = "x") {
    // braço no eixo com ímã na ponta, apontando para baixo
    rot = axis == "x" ? [0, 0, 0] : [0, 0, 90];
    rotate(rot) {
        color(C_PRINT) difference() {
            union() {
                translate([46, 0, zp]) rotate([0, 90, 0]) cylinder(d = 24, h = 14);
                hull() {
                    translate([46, 0, zp]) rotate([0, 90, 0]) cylinder(d = 20, h = 12);
                    translate([46, 0, zp - pad_r]) rotate([0, 90, 0]) cylinder(d = 16, h = 12);
                }
            }
            translate([44, 0, zp]) rotate([0, 90, 0]) cylinder(d = shaft_d + 0.2, h = 18);
            translate([45, 0, zp - pad_r]) rotate([0, 90, 0]) cylinder(d = mag_d + 0.3, h = 12);
        }
        translate([46, 0, zp - pad_r]) magnet_x();
        // ímã do detent central (atração) na face do braço
        color(C_MAG) translate([44.5, 0, zp - pad_r + 12]) rotate([0, 90, 0]) cylinder(d = 5, h = 2);
    }
}

module stator_slider(engage = 1, axis = "x") {
    // carrinho com 2 ímãs a ±28°; desliza axialmente p/ desengajar
    dx = 20*(1 - engage);      // 0 = engajado (mesmo plano do paddle)
    rot = axis == "x" ? [0, 0, 0] : [0, 0, 90];
    rotate(rot) translate([dx, 0, 0]) {
        color(C_ACCENT) difference() {
            union() {
                translate([56, -24, 8]) cube([16, 48, 10]);           // corpo no canal
                for (sy = [-1, 1]) hull() {                            // postes
                    translate([56, sy*24 - 6, 8]) cube([16, 12, 4]);
                    translate([56, sy*pad_r*sin(stat_ang) - 7,
                               zp - pad_r*cos(stat_ang) - 7]) cube([16, 14, 14]);
                }
            }
            for (sy = [-1, 1])
                translate([45, sy*pad_r*sin(stat_ang), zp - pad_r*cos(stat_ang)])
                    rotate([0, 90, 0]) cylinder(d = mag_d + 0.3, h = 12.5);
            translate([54, 0, 13]) rotate([0, 90, 0]) cylinder(d = 5.2, h = 20); // fuso M5
        }
        for (sy = [-1, 1])
            translate([46, sy*pad_r*sin(stat_ang), zp - pad_r*cos(stat_ang)]) magnet_x();
        // ímã do detent central (pólo oposto — atração)
        color(C_MAG) translate([46, 0, zp - pad_r + 12]) rotate([0, 90, 0]) cylinder(d = 5, h = 2);
    }
}

module thumbwheel(axis = "x") {
    rot = axis == "x" ? [0, 0, 0] : [0, 0, 90];
    rotate(rot) color(C_ACCENT) translate([bw/2 + 1, 0, 25]) rotate([0, 90, 0]) knurl_wheel(28, 8);
}

//==============================================================
// AMORTECEDOR EDDY — setor de cobre + garfo
//==============================================================
module eddy_sector(axis = "x") {
    rot = axis == "x" ? [0, 0, 0] : [0, 0, 90];
    rotate(rot) {
        color(C_PRINT) difference() {
            translate([-58, 0, zp]) rotate([0, 90, 0]) cylinder(d = 24, h = 12);
            translate([-60, 0, zp]) rotate([0, 90, 0]) cylinder(d = shaft_d + 0.2, h = 16);
        }
        // setor de cobre 80°, r 20..46, apontando para baixo
        color(C_COPPER) translate([-53, 0, zp]) rotate([0, 90, 0]) rotate(90 - 40)
            linear_extrude(2) difference() {
                intersection() { circle(46); polygon([[0,0],[60,0],[60,60],[0,60]]); }
                circle(20);
            }
    }
}
module eddy_yoke(axis = "x") {
    rot = axis == "x" ? [0, 0, 0] : [0, 0, 90];
    rotate(rot) {
        color(C_ACCENT) difference() {
            translate([-60, -14, 8]) cube([14, 28, 34]);
            translate([-54.5, -15, 20]) cube([3.4, 30, 24]);   // garganta do setor
        }
        color(C_MAG) for (dxm = [-5.2, 2]) translate([-52 + dxm, -10, 22]) cube([3, 20, 18]);
    }
}

//==============================================================
// EIXOS, SENSORES, ELETRÔNICA
//==============================================================
module pitch_shaft() {
    color(C_STEEL) translate([-86, 0, zp]) rotate([0, 90, 0]) cylinder(d = shaft_d, h = 172);
    color(C_MAG) translate([-88.5, 0, zp]) rotate([0, 90, 0]) cylinder(d = 6, h = 2.5); // ímã do sensor
}
module roll_shaft() {
    color(C_STEEL) translate([0, -70, zp]) rotate([-90, 0, 0]) cylinder(d = shaft_d, h = 140);
    color(C_MAG) translate([0, -72.5, zp]) rotate([-90, 0, 0]) cylinder(d = 6, h = 2.5);
}
module sensors_fixed() {
    color(C_PCB) translate([-bw/2 - 2, -10, zp - 12]) cube([1.6, 20, 24]); // AS5600 pitch
}
module roll_sensor() {
    color(C_PCB) translate([-10, -75.5, zp - 12]) cube([20, 1.6, 24]);     // AS5600 roll
}
module electronics() {
    color(C_PCB) translate([-30, -bw/2 + wall + 4, 8]) cube([24, 18, 1.6]); // RP2040-Zero
}

//==============================================================
// MONTAGEM
//==============================================================
module roll_group(ra) {
    translate([0, 0, zp]) rotate([0, ra, 0]) translate([0, 0, -zp]) {
        color(C_PRINT) inner_block();
        stick();
        roll_shaft();
        paddle("y");
        eddy_sector("y");
    }
}

module pitch_group(pa, ra) {
    translate([0, 0, zp]) rotate([pa, 0, 0]) translate([0, 0, -zp]) {
        color(C_PRINT) outer_frame();
        pitch_shaft();
        paddle("x");
        eddy_sector("x");
        stator_slider(roll_engage, "y");
        eddy_yoke("y");
        roll_sensor();
        for (sy = [-1, 1]) translate([0, sy*61, zp]) bearing("y");
        roll_group(ra);
    }
}

module s1_assembly(pa = pitch_angle, ra = roll_angle) {
    color(C_PRINT) base_shell();
    top_plate();
    sensors_fixed();
    electronics();
    stator_slider(pitch_engage, "x");
    eddy_yoke("x");
    thumbwheel("x");
    for (sx = [-1, 1]) translate([sx*(bw/2 - 14.5) - (sx > 0 ? brg_h : 0), 0, zp]) bearing("x");
    pitch_group(pa, ra);
}

//==============================================================
// SELETOR
//==============================================================
if (part == "assembly")           s1_assembly();
else if (part == "cutaway")       difference() {
                                      s1_assembly();
                                      color(C_PRINT) translate([0, -300, -10]) cube([300, 300, 340]);
                                  }
else if (part == "base_shell")    base_shell();
else if (part == "top_plate")     top_plate();
else if (part == "outer_frame")   outer_frame();
else if (part == "inner_block")   inner_block();
else if (part == "paddle")        paddle("x");
else if (part == "stator_slider") stator_slider(1, "x");
else if (part == "stick")         stick();
else if (part == "thumbwheel")    thumbwheel("x");
else echo("part desconhecida");
