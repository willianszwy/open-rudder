/*
 * Open Rudder - leme + 2 freios de biqueira como joystick USB
 * Arduino Pro Micro (ATmega32U4) + TCA9548A + 3x AS5600
 * Biblioteca Joystick (MHeironimus) 2.1.1
 *
 * POR QUE O MUX: o endereco I2C do AS5600 e fixo em 0x36 e nao e programavel,
 * entao tres sensores nao coexistem no mesmo barramento. O TCA9548A isola cada
 * um em seu canal; o mestre fala com um canal por vez.
 *
 * LIGACAO
 *   Pro Micro          TCA9548A            sensores
 *     SDA (2) --------- SDA    SD0/SC0 ---- AS5600 leme
 *     SCL (3) --------- SCL    SD1/SC1 ---- AS5600 freio esquerdo
 *     3.3V   --------- VIN    SD2/SC2 ---- AS5600 freio direito
 *     GND    --------- GND
 *                      A0,A1,A2 -> GND  (endereco 0x70)
 *   Cada AS5600: VCC 3.3V, GND, DIR em GND.
 *
 * Sem o mux ligado o firmware cai automaticamente para o modo de 1 sensor
 * (so o leme, AS5600 direto no barramento) - da para montar por partes.
 *
 * EIXOS HID
 *   Rz  leme            -16383..16383   (centro no zero)
 *   X   freio esquerdo       0..4095    (repouso no zero)
 *   Y   freio direito        0..4095
 *
 * CURSO MINIMO DOS FREIOS: o AS5600 da 0,088 graus por count. Para um freio
 * com resolucao decente mire 10-15 graus de giro no pivo da biqueira (~115-170
 * counts). Abaixo de ~5 graus a dosagem fica granulada.
 *
 * COMANDOS (uma linha cada). Comandos de eixo levam o numero do eixo na frente:
 *   0=leme  1=freio esq  2=freio dir
 *     0c      centro do leme (pedais soltos)
 *     0l      batente esquerdo        0r   batente direito
 *     1c      repouso do freio esq    1r   freio esq a fundo
 *     2c      repouso do freio dir    2r   freio dir a fundo
 *     0i      inverte os lados do leme
 *     1d4     deadzone do eixo 1 = 4 counts   (sem numero: cicla 0/2/4/8)
 *     0x30    expo do eixo 0 = 30%            (sem numero: cicla 0/15/30/45)
 *   Globais: w grava na EEPROM | e apaga | ? mostra tudo | s status dos imas
 *            p monitor legivel | > < liga/desliga a telemetria da pagina web
 *
 * PROTOCOLO da telemetria (uma linha por eixo, 25 Hz, apos o comando '>'):
 *   D,eixo,raw,rel,valor,statusIma,agc
 *        statusIma: 0=ok 1=sem ima 2=fraco 3=forte 4=erro I2C 5=canal vazio
 *   C,eixo,repouso,minRel,maxRel,invert,deadzone,expo
 *
 * NOTA para regravar: com HID ativo o Pro Micro as vezes nao entra em bootloader
 * sozinho. De dois toques rapidos no RESET e mande o upload na janela de ~8 s.
 */

#include <Wire.h>
#include <EEPROM.h>
#include <Joystick.h>

// ---------------------------------------------------------------- constantes
static const uint8_t MUX_ADDR        = 0x70;
static const uint8_t AS5600_ADDR     = 0x36;
static const uint8_t REG_STATUS      = 0x0B;
static const uint8_t REG_RAW_ANGLE_H = 0x0C;
static const uint8_t REG_AGC         = 0x1B;
static const uint8_t REG_MAGNITUDE_H = 0x1C;

static const uint8_t STATUS_MD = 0x20;
static const uint8_t STATUS_ML = 0x10;
static const uint8_t STATUS_MH = 0x08;

static const uint8_t AXIS_COUNT  = 3;
static const uint8_t AX_RUDDER   = 0;

// Faixa de saida de cada eixo no HID.
static const int32_t RUDDER_RANGE = 16383;   // simetrico: -RANGE..+RANGE
static const int32_t BRAKE_RANGE  = 4095;    // unidirecional: 0..RANGE

// 400 kHz e seguro com os sensores na bancada. Com cabo longo ate as biqueiras
// (>30 cm) o barramento pode ficar marginal: caia para 100000 se aparecer
// "sem resposta no eixo" ou leitura pulando. Mesmo a 100 kHz cada leitura leva
// ~540 us, entao o round-robin de 1 ms continua cabendo.
static const uint32_t I2C_CLOCK = 400000;

static const uint16_t UPDATE_INTERVAL_US = 1000;   // 1 kHz (round-robin: 333 Hz/eixo)
static const uint16_t PRINT_INTERVAL_MS  = 100;
static const uint16_t TELEM_INTERVAL_MS  = 40;     // 25 Hz para a pagina web

// Filtro exponencial: 1.0 = sem filtro, menor = mais suave e mais lento.
static const float EMA_ALPHA = 0.35f;

// Cursos padrao antes de calibrar.
static const int16_t RUDDER_TRAVEL = 194;   // 17 graus
static const int16_t BRAKE_TRAVEL  = 170;   // 15 graus

// Curso minimo aceito numa captura de batente - abaixo disso e engano.
static const int16_t MIN_TRAVEL = 10;

static const uint32_t EEPROM_MAGIC = 0x4D315233UL;   // "Open Rudder v3 (3 eixos)"
static const int      EEPROM_ADDR  = 0;

// ------------------------------------------------------------------- config
struct AxisCal {
  uint16_t restRaw;   // leitura bruta no centro (leme) ou no repouso (freio)
  int16_t  minRel;    // batente negativo - so o leme usa
  int16_t  maxRel;    // batente positivo / fundo do freio
  uint8_t  invert;
  uint8_t  deadzone;
  uint8_t  expo;
};

struct Config {
  uint32_t magic;
  AxisCal  axis[AXIS_COUNT];
};

Config cfg;

// true = eixo bidirecional (leme), false = unidirecional (freio)
inline bool isRudder(uint8_t a) { return a == AX_RUDDER; }

const char *axisName(uint8_t a) {
  return a == 0 ? "leme" : a == 1 ? "freio esq" : "freio dir";
}

// ------------------------------------------------------------------- estado
Joystick_ Joystick(
  JOYSTICK_DEFAULT_REPORT_ID,
  JOYSTICK_TYPE_JOYSTICK,
  0, 0,                          // sem botoes, sem hat
  true,  true,  false,           // X (freio esq), Y (freio dir), Z
  false, false, true,            // Rx, Ry, Rz (leme)
  false, false, false, false, false);

float    filtered[AXIS_COUNT];     // saida normalizada ja filtrada
uint16_t lastRaw[AXIS_COUNT];
bool     present[AXIS_COUNT];      // sensor respondeu no boot
uint8_t  errors[AXIS_COUNT];

bool     muxPresent = false;
uint8_t  rrChannel  = 0;           // canal da vez no round-robin

bool     monitor    = false;
bool     telemetry  = false;
uint32_t lastUpdate = 0;
uint32_t lastPrint  = 0;
uint32_t lastTelem  = 0;

char     cmdBuf[16];
uint8_t  cmdLen = 0;
uint32_t lastCharMs = 0;

// -------------------------------------------------------------- I2C helpers
bool probe(uint8_t addr) {
  Wire.beginTransmission(addr);
  return Wire.endTransmission() == 0;
}

// Abre um unico canal do mux. Sem mux, so o canal 0 "existe".
bool muxSelect(uint8_t ch) {
  if (!muxPresent) return ch == 0;
  Wire.beginTransmission(MUX_ADDR);
  Wire.write((uint8_t)(1 << ch));
  return Wire.endTransmission() == 0;
}

bool readReg8(uint8_t reg, uint8_t &value) {
  Wire.beginTransmission(AS5600_ADDR);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom((uint8_t)AS5600_ADDR, (uint8_t)1) != 1) return false;
  value = Wire.read();
  return true;
}

bool readReg12(uint8_t regHigh, uint16_t &value) {
  Wire.beginTransmission(AS5600_ADDR);
  Wire.write(regHigh);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom((uint8_t)AS5600_ADDR, (uint8_t)2) != 2) return false;
  uint8_t hi = Wire.read();
  uint8_t lo = Wire.read();
  value = (((uint16_t)hi << 8) | lo) & 0x0FFF;
  return true;
}

// Le o angulo bruto do sensor de um eixo, cuidando do mux.
bool readAngle(uint8_t a, uint16_t &raw) {
  if (!muxSelect(a)) return false;
  return readReg12(REG_RAW_ANGLE_H, raw);
}

// 0=ok 1=sem ima 2=fraco 3=forte 4=erro I2C 5=canal vazio
uint8_t magnetCode(uint8_t a) {
  if (!present[a]) return 5;
  if (!muxSelect(a)) return 4;
  uint8_t status = 0;
  if (!readReg8(REG_STATUS, status)) return 4;
  if (!(status & STATUS_MD))         return 1;
  if (status & STATUS_ML)            return 2;
  if (status & STATUS_MH)            return 3;
  return 0;
}

uint8_t readAgc(uint8_t a) {
  uint8_t agc = 0;
  if (present[a] && muxSelect(a)) readReg8(REG_AGC, agc);
  return agc;
}

// ------------------------------------------------------------------ dominio
// Posicao relativa ao repouso, resolvendo a volta do circulo: o resultado fica
// sempre em -2048..2047, entao o zero pode cair em qualquer ponto do giro.
int16_t relativeToRest(uint8_t a, uint16_t raw) {
  int16_t rel = (int16_t)raw - (int16_t)cfg.axis[a].restRaw;
  if (rel >  2048) rel -= 4096;
  if (rel < -2048) rel += 4096;
  return rel;
}

// Converte counts relativos na saida normalizada do eixo:
//   leme  -> -1..1, com os dois batentes escalados separadamente
//   freio ->  0..1, so o sentido de acionamento
float normalize(uint8_t a, int16_t rel) {
  const AxisCal &c = cfg.axis[a];
  if (c.invert) rel = -rel;

  int16_t dz = c.deadzone;
  if (!isRudder(a)) {
    // Freio: qualquer coisa antes da deadzone e repouso. Sem isso, um drift de
    // 2 counts vira freio arrastando o tempo todo.
    if (rel <= dz) return 0.0f;
    int16_t span = c.maxRel - dz;
    if (span <= 0) return 0.0f;
    float n = (float)(rel - dz) / span;
    return n > 1.0f ? 1.0f : n;
  }

  if (rel > -dz && rel < dz) return 0.0f;
  rel += (rel > 0) ? -dz : dz;

  float n;
  if (rel >= 0) {
    int16_t span = c.maxRel - dz;
    n = (span > 0) ? (float)rel / span : 0.0f;
  } else {
    int16_t span = -c.minRel - dz;   // minRel e negativo
    n = (span > 0) ? (float)rel / span : 0.0f;
  }

  if (n >  1.0f) n =  1.0f;
  if (n < -1.0f) n = -1.0f;
  return n;
}

// Expo: suaviza o inicio do curso e mantem o ganho no fim. e=0 -> linear.
float applyExpo(uint8_t a, float n) {
  uint8_t e8 = cfg.axis[a].expo;
  if (e8 == 0) return n;
  float e = e8 / 100.0f;
  return (1.0f - e) * n + e * n * n * n;
}

void pushToHid(uint8_t a) {
  float v = filtered[a];
  switch (a) {
    case 0: Joystick.setRzAxis((int32_t)(v * RUDDER_RANGE)); break;
    case 1: Joystick.setXAxis((int32_t)(v * BRAKE_RANGE));   break;
    case 2: Joystick.setYAxis((int32_t)(v * BRAKE_RANGE));   break;
  }
}

int32_t hidValue(uint8_t a) {
  return (int32_t)(filtered[a] * (isRudder(a) ? RUDDER_RANGE : BRAKE_RANGE));
}

// -------------------------------------------------------------- persistencia
void loadDefaults() {
  cfg.magic = EEPROM_MAGIC;
  for (uint8_t a = 0; a < AXIS_COUNT; a++) {
    AxisCal &c = cfg.axis[a];
    c.restRaw  = 0;
    c.invert   = 0;
    c.expo     = 0;
    if (isRudder(a)) {
      c.minRel   = -RUDDER_TRAVEL;
      c.maxRel   =  RUDDER_TRAVEL;
      c.deadzone = 0;
    } else {
      c.minRel   = 0;
      c.maxRel   = BRAKE_TRAVEL;
      c.deadzone = 4;      // freio sempre com folga no repouso
    }
  }
}

bool configValid() {
  if (cfg.magic != EEPROM_MAGIC) return false;
  for (uint8_t a = 0; a < AXIS_COUNT; a++) {
    if (cfg.axis[a].maxRel < MIN_TRAVEL) return false;
    if (isRudder(a) && cfg.axis[a].minRel > -MIN_TRAVEL) return false;
  }
  return true;
}

void loadConfig() {
  EEPROM.get(EEPROM_ADDR, cfg);
  if (!configValid()) {
    loadDefaults();
    Serial.println(F("EEPROM vazia/invalida - usando padrao. Calibre e grave com 'w'."));
  }
}

void saveConfig() {
  cfg.magic = EEPROM_MAGIC;
  EEPROM.put(EEPROM_ADDR, cfg);
  Serial.println(F(">> calibracao gravada na EEPROM"));
}

// -------------------------------------------------------------- saida serial
void sendConfigLine(uint8_t a) {
  const AxisCal &c = cfg.axis[a];
  Serial.print(F("C,"));
  Serial.print(a);          Serial.print(',');
  Serial.print(c.restRaw);  Serial.print(',');
  Serial.print(c.minRel);   Serial.print(',');
  Serial.print(c.maxRel);   Serial.print(',');
  Serial.print(c.invert);   Serial.print(',');
  Serial.print(c.deadzone); Serial.print(',');
  Serial.println(c.expo);
}

void sendAllConfig() {
  for (uint8_t a = 0; a < AXIS_COUNT; a++) sendConfigLine(a);
}

void sendTelemetry() {
  for (uint8_t a = 0; a < AXIS_COUNT; a++) {
    Serial.print(F("D,"));
    Serial.print(a);                       Serial.print(',');
    Serial.print(lastRaw[a]);              Serial.print(',');
    Serial.print(relativeToRest(a, lastRaw[a])); Serial.print(',');
    Serial.print(hidValue(a));             Serial.print(',');
    Serial.print(magnetCode(a));           Serial.print(',');
    Serial.println(readAgc(a));
  }
}

void printConfig() {
  Serial.print(F("mux: "));
  Serial.println(muxPresent ? F("TCA9548A em 0x70") : F("ausente (modo 1 sensor)"));
  for (uint8_t a = 0; a < AXIS_COUNT; a++) {
    const AxisCal &c = cfg.axis[a];
    Serial.print('[');  Serial.print(a); Serial.print(F("] "));
    Serial.print(axisName(a));
    Serial.print(present[a] ? F("  ") : F(" (SEM SENSOR) "));
    Serial.print(F(" repouso=")); Serial.print(c.restRaw);
    if (isRudder(a)) { Serial.print(F(" esq=")); Serial.print(c.minRel); }
    Serial.print(F(" max="));     Serial.print(c.maxRel);
    Serial.print(F(" curso="));
    Serial.print((c.maxRel - (isRudder(a) ? c.minRel : 0)) * 360.0f / 4096.0f, 1);
    Serial.print(F("deg inv="));  Serial.print(c.invert);
    Serial.print(F(" dz="));      Serial.print(c.deadzone);
    Serial.print(F(" expo="));    Serial.print(c.expo);
    Serial.println('%');
  }
}

void printMagnetStatus() {
  for (uint8_t a = 0; a < AXIS_COUNT; a++) {
    uint8_t code = magnetCode(a);
    Serial.print('[');  Serial.print(a); Serial.print(F("] "));
    Serial.print(axisName(a)); Serial.print(F(": "));
    switch (code) {
      case 0: Serial.print(F("ima OK"));            break;
      case 1: Serial.print(F("SEM IMA detectado")); break;
      case 2: Serial.print(F("ima FRACO"));         break;
      case 3: Serial.print(F("ima FORTE"));         break;
      case 5: Serial.print(F("canal vazio"));       break;
      default: Serial.print(F("erro I2C"));         break;
    }
    if (code <= 3) {
      uint16_t magnitude = 0;
      Serial.print(F(" | AGC=")); Serial.print(readAgc(a));
      if (muxSelect(a) && readReg12(REG_MAGNITUDE_H, magnitude)) {
        Serial.print(F(" | MAG=")); Serial.print(magnitude);
      }
    }
    Serial.println();
  }
}

// ---------------------------------------------------------------- comandos
// Comando de eixo: "<n><letra>[valor]"  ex.: 0c, 1r, 2d4, 0x30
// Comando global:  "<letra>"            ex.: w, e, ?, s, p, >, <
void handleAxisCommand(uint8_t a, char c, bool hasArg, int arg) {
  AxisCal &cal = cfg.axis[a];
  int16_t  raw = lastRaw[a];
  bool changed = true;

  switch (c) {
    case 'c':
      cal.restRaw = raw;
      Serial.print(F(">> ")); Serial.print(axisName(a));
      Serial.print(isRudder(a) ? F(": centro = ") : F(": repouso = "));
      Serial.println(raw);
      break;

    case 'l': {
      if (!isRudder(a)) { Serial.println(F("!! 'l' so vale para o leme")); changed = false; break; }
      int16_t rel = relativeToRest(a, raw);
      if (cal.invert) rel = -rel;
      if (rel > -MIN_TRAVEL) {
        Serial.println(F("!! curso pequeno demais ou lado trocado - use 0i e repita"));
        changed = false; break;
      }
      cal.minRel = rel;
      Serial.print(F(">> batente esquerdo = ")); Serial.println(rel);
      break;
    }

    case 'r': {
      int16_t rel = relativeToRest(a, raw);
      if (isRudder(a)) {
        if (cal.invert) rel = -rel;
        if (rel < MIN_TRAVEL) {
          Serial.println(F("!! curso pequeno demais ou lado trocado - use 0i e repita"));
          changed = false; break;
        }
      } else {
        // Freio: o sentido de acionamento e deduzido, sem passo de inversao.
        if (rel < 0) { cal.invert = 1; rel = -rel; }
        else         { cal.invert = 0; }
        if (rel < MIN_TRAVEL) {
          Serial.println(F("!! curso pequeno demais - o freio precisa de ~10 graus"));
          changed = false; break;
        }
      }
      cal.maxRel = rel;
      Serial.print(F(">> ")); Serial.print(axisName(a));
      Serial.print(isRudder(a) ? F(": batente direito = ") : F(": fundo = "));
      Serial.println(rel);
      break;
    }

    case 'i':
      cal.invert = !cal.invert;
      Serial.print(F(">> ")); Serial.print(axisName(a));
      Serial.print(F(": inversao ")); Serial.println(cal.invert ? F("sim") : F("nao"));
      break;

    case 'd':
      cal.deadzone = hasArg ? constrain(arg, 0, 64)
                            : (cal.deadzone == 0) ? 2 : (cal.deadzone == 2) ? 4
                            : (cal.deadzone == 4) ? 8 : 0;
      Serial.print(F(">> ")); Serial.print(axisName(a));
      Serial.print(F(": deadzone = ")); Serial.println(cal.deadzone);
      break;

    case 'x':
      cal.expo = hasArg ? constrain(arg, 0, 90) : (cal.expo + 15) % 60;
      Serial.print(F(">> ")); Serial.print(axisName(a));
      Serial.print(F(": expo = ")); Serial.print(cal.expo); Serial.println('%');
      break;

    default:
      changed = false;
      break;
  }

  if (changed) sendConfigLine(a);
}

void handleLine(char *line) {
  // prefixo numerico = comando de eixo
  if (line[0] >= '0' && line[0] <= '9') {
    uint8_t a = line[0] - '0';
    if (a >= AXIS_COUNT || line[1] == '\0') {
      Serial.println(F("!! eixo invalido (use 0=leme 1=freio esq 2=freio dir)"));
      return;
    }
    bool hasArg = (line[2] != '\0');
    handleAxisCommand(a, line[1], hasArg, hasArg ? atoi(line + 2) : 0);
    return;
  }

  switch (line[0]) {
    case 'w': case 'W': saveConfig(); break;

    case 'e': case 'E':
      loadDefaults();
      EEPROM.put(EEPROM_ADDR, cfg);
      Serial.println(F(">> EEPROM apagada, valores padrao restaurados"));
      sendAllConfig();
      break;

    case '?': printConfig();       sendAllConfig(); break;
    case '>': telemetry = true;    sendAllConfig(); break;
    case '<': telemetry = false;   break;

    case 's': case 'S': printMagnetStatus(); break;

    case 'p': case 'P':
      monitor = !monitor;
      Serial.println(monitor ? F(">> monitor ON") : F(">> monitor OFF"));
      break;

    default: break;
  }
}

// Acumula caracteres ate \n ou \r e entrega a linha completa. Se o Serial
// Monitor estiver em "sem fim de linha", o timeout abaixo executa mesmo assim.
void pumpSerial() {
  while (Serial.available()) {
    char c = Serial.read();
    lastCharMs = millis();
    if (c == '\n' || c == '\r') {
      if (cmdLen > 0) { cmdBuf[cmdLen] = '\0'; handleLine(cmdBuf); cmdLen = 0; }
    } else if (cmdLen < sizeof(cmdBuf) - 1) {
      cmdBuf[cmdLen++] = c;
    }
  }

  if (cmdLen > 0 && millis() - lastCharMs > 100) {
    cmdBuf[cmdLen] = '\0';
    handleLine(cmdBuf);
    cmdLen = 0;
  }
}

// -------------------------------------------------------------------- setup
void setup() {
  Serial.begin(115200);

  Wire.begin();
  digitalWrite(SDA, LOW);   // desliga pull-ups internos de 5V (AS5600 e 3.3V)
  digitalWrite(SCL, LOW);
  Wire.setClock(I2C_CLOCK);

  muxPresent = probe(MUX_ADDR);

  loadConfig();

  for (uint8_t a = 0; a < AXIS_COUNT; a++) {
    filtered[a] = 0.0f;
    lastRaw[a]  = 0;
    errors[a]   = 0;
    uint16_t raw;
    present[a] = readAngle(a, raw);
    if (present[a]) {
      lastRaw[a]  = raw;
      filtered[a] = applyExpo(a, normalize(a, relativeToRest(a, raw)));
    }
  }

  Joystick.setRzAxisRange(-RUDDER_RANGE, RUDDER_RANGE);
  Joystick.setXAxisRange(0, BRAKE_RANGE);
  Joystick.setYAxisRange(0, BRAKE_RANGE);
  Joystick.begin(false);          // envio manual, para controlar a taxa
  for (uint8_t a = 0; a < AXIS_COUNT; a++) pushToHid(a);
  Joystick.sendState();
}

// --------------------------------------------------------------------- loop
void loop() {
  uint32_t nowUs = micros();
  if (nowUs - lastUpdate < UPDATE_INTERVAL_US) return;
  lastUpdate = nowUs;

  // Round-robin: um sensor por tick de 1 ms -> 333 Hz por eixo, de sobra para
  // um pedal e sem estourar o orcamento de tempo do barramento.
  uint8_t a = rrChannel;
  rrChannel = (rrChannel + 1) % AXIS_COUNT;

  if (present[a]) {
    uint16_t raw;
    if (readAngle(a, raw)) {
      errors[a] = 0;
      lastRaw[a] = raw;

      float target = applyExpo(a, normalize(a, relativeToRest(a, raw)));
      filtered[a] += EMA_ALPHA * (target - filtered[a]);

      pushToHid(a);
      Joystick.sendState();
    } else if (errors[a] < 255) {
      // Falha de leitura: segura o ultimo valor em vez de mandar lixo ao sim.
      if (++errors[a] == 60) {
        Serial.print(F("ERRO: sem resposta no eixo ")); Serial.print(a);
        Serial.print(' '); Serial.println(axisName(a));
      }
    }
  }

  pumpSerial();

  uint32_t nowMs = millis();

  // Telemetria so quando alguem abriu a porta (evita encher o buffer CDC).
  if (telemetry && Serial && nowMs - lastTelem >= TELEM_INTERVAL_MS) {
    lastTelem = nowMs;
    sendTelemetry();
  }

  if (monitor && nowMs - lastPrint >= PRINT_INTERVAL_MS) {
    lastPrint = nowMs;
    for (uint8_t i = 0; i < AXIS_COUNT; i++) {
      Serial.print(axisName(i));
      Serial.print(F(" raw="));  Serial.print(lastRaw[i]);
      Serial.print(F(" ang="));  Serial.print(relativeToRest(i, lastRaw[i]) * 360.0f / 4096.0f, 2);
      Serial.print(F("deg val=")); Serial.print(hidValue(i));
      Serial.print(i == AXIS_COUNT - 1 ? '\n' : '\t');
    }
  }
}
