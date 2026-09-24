/*
 * AS5600 - leitura de angulo com Arduino Pro Micro (ATmega32U4)
 *
 * Ligacao (Pro Micro):
 *   AS5600 SDA -> pino 2  (D2 / SDA)
 *   AS5600 SCL -> pino 3  (D3 / SCL)
 *   AS5600 VCC -> VCC     (5V - ver nota abaixo)
 *   AS5600 GND -> GND
 *   AS5600 DIR -> GND     (sentido horario = angulo crescente)
 *
 * TENSAO: tudo em 5V, sem regulador e sem conversor de nivel. O AS5600 tem
 * dois modos de alimentacao - VDD5V (4,5 a 5,5V, com LDO interno) ou VDD3V3
 * (3,0 a 3,6V). Com modulos da variante 5V o barramento inteiro roda no VCC
 * do Pro Micro. Confirme qual e o seu antes de ligar: num modulo 3,3V os 5V
 * passam do limite e queimam o sensor.
 *
 * Ima: diametral (magnetizado de lado a lado), 6x2.5mm ou 6x3mm,
 * centrado no eixo, a ~0.5-3mm da face marcada do chip.
 *
 * Saida no Serial Monitor (115200): angulo bruto, em graus e acumulado
 * (multivoltas), mais o status do ima.
 */

#include <Wire.h>

// ---------------------------------------------------------------- constantes
static const uint8_t AS5600_ADDR       = 0x36;

static const uint8_t REG_STATUS        = 0x0B;  // MH / ML / MD
static const uint8_t REG_RAW_ANGLE_H   = 0x0C;  // 12 bits, sem filtro de zero
static const uint8_t REG_ANGLE_H       = 0x0E;  // 12 bits, com ZPOS/MPOS
static const uint8_t REG_AGC           = 0x1B;
static const uint8_t REG_MAGNITUDE_H   = 0x1C;

static const uint8_t STATUS_MD         = 0x20;  // ima detectado
static const uint8_t STATUS_ML         = 0x10;  // ima muito fraco / longe
static const uint8_t STATUS_MH         = 0x08;  // ima muito forte / perto

static const float   COUNTS_TO_DEG     = 360.0f / 4096.0f;
static const uint16_t PRINT_INTERVAL_MS = 100;

// ------------------------------------------------------------------ estado
int16_t  lastRaw       = 0;      // ultima leitura bruta (0..4095)
int32_t  turns         = 0;      // voltas completas acumuladas
uint16_t zeroOffset    = 0;      // zero por software (comando 'z')
uint32_t lastPrint     = 0;

// -------------------------------------------------------------- I2C helpers
// Le um registrador de 8 bits. Retorna false em caso de erro de barramento.
bool readReg8(uint8_t reg, uint8_t &value) {
  Wire.beginTransmission(AS5600_ADDR);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return false;   // repeated start

  if (Wire.requestFrom((uint8_t)AS5600_ADDR, (uint8_t)1) != 1) return false;
  value = Wire.read();
  return true;
}

// Le um par de registradores (high, high+1) e devolve os 12 bits uteis.
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

// ------------------------------------------------------------------ dominio
// Acumula voltas detectando o salto 4095 -> 0 (e vice-versa).
void updateTurns(int16_t raw) {
  int16_t delta = raw - lastRaw;
  if (delta > 2048)       turns--;   // passou de 0 para 4095 (sentido negativo)
  else if (delta < -2048) turns++;   // passou de 4095 para 0 (sentido positivo)
  lastRaw = raw;
}

// Angulo 0..360 relativo ao zero por software.
float angleDeg(uint16_t raw) {
  int16_t rel = (int16_t)raw - (int16_t)zeroOffset;
  if (rel < 0) rel += 4096;
  return rel * COUNTS_TO_DEG;
}

// Angulo continuo (pode passar de 360 ou ficar negativo).
float totalAngleDeg(uint16_t raw) {
  return turns * 360.0f + raw * COUNTS_TO_DEG - zeroOffset * COUNTS_TO_DEG;
}

void printStatus() {
  uint8_t status = 0, agc = 0;
  uint16_t magnitude = 0;

  if (!readReg8(REG_STATUS, status)) {
    Serial.println(F("STATUS: falha na leitura I2C"));
    return;
  }
  readReg8(REG_AGC, agc);
  readReg12(REG_MAGNITUDE_H, magnitude);

  Serial.print(F("STATUS: "));
  if (!(status & STATUS_MD))     Serial.print(F("SEM IMA detectado"));
  else if (status & STATUS_ML)   Serial.print(F("ima FRACO (afaste menos / aproxime)"));
  else if (status & STATUS_MH)   Serial.print(F("ima FORTE (afaste um pouco)"));
  else                           Serial.print(F("ima OK"));

  Serial.print(F(" | AGC="));       Serial.print(agc);
  Serial.print(F(" | MAG="));       Serial.print(magnitude);
  Serial.println();
}

// -------------------------------------------------------------------- setup
void setup() {
  Serial.begin(115200);
  while (!Serial && millis() < 3000) { /* Pro Micro: espera USB, com timeout */ }

  Wire.begin();
  // Pull-ups internos do ATmega32U4 ficam LIGADOS (padrao do Wire.begin).
  // O barramento todo e 5V, entao eles nao agridem o AS5600 e ainda mantem
  // SDA/SCL definidos quando nenhum sensor esta ligado. Sem eles a lib Wire
  // do AVR trava esperando um nivel alto que nunca chega, e a placa some da
  // USB com os LEDs acesos.

  Wire.setClock(400000);   // fast mode; use 100000 se o cabo for longo

  Serial.println(F("=== AS5600 - leitor de angulo ==="));
  Serial.println(F("Comandos: 'z' zera no angulo atual | 's' status do ima"));

  printStatus();

  uint16_t raw;
  if (readReg12(REG_RAW_ANGLE_H, raw)) {
    lastRaw = raw;
  } else {
    Serial.println(F("ERRO: AS5600 nao respondeu. Confira SDA=2, SCL=3, GND e alimentacao."));
  }
}

// --------------------------------------------------------------------- loop
void loop() {
  uint16_t raw;
  if (!readReg12(REG_RAW_ANGLE_H, raw)) {
    Serial.println(F("ERRO de leitura I2C"));
    delay(500);
    return;
  }

  updateTurns((int16_t)raw);

  // comandos pelo Serial Monitor
  while (Serial.available()) {
    char c = Serial.read();
    if (c == 'z' || c == 'Z') {
      zeroOffset = raw;
      turns = 0;
      Serial.println(F(">> zero ajustado na posicao atual"));
    } else if (c == 's' || c == 'S') {
      printStatus();
    }
  }

  uint32_t now = millis();
  if (now - lastPrint >= PRINT_INTERVAL_MS) {
    lastPrint = now;

    Serial.print(F("raw="));    Serial.print(raw);
    Serial.print(F("\tang="));  Serial.print(angleDeg(raw), 2);
    Serial.print(F(" deg\tacum=")); Serial.print(totalAngleDeg(raw), 2);
    Serial.print(F(" deg\tvoltas=")); Serial.println(turns);
  }
}
