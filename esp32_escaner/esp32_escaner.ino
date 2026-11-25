// Firmware mínimo del escáner: obedece comandos por serial (115200, terminados en '\n').
//   T <pasos>  -> mueve la mesa (phi) a esa posición ABSOLUTA en pasos
//   R <pasos>  -> mueve el rotor (theta) a esa posición ABSOLUTA en pasos
//   Z          -> la posición actual de ambos motores pasa a ser 0
// Responde "OK" al terminar cada comando, o "ERR ..." si no lo entiende.
// ponytail: la conversión grados->pasos vive en MATLAB, así calibras sin volver a flashear.

#include <AccelStepper.h>   // Library Manager: "AccelStepper" de Mike McCauley

AccelStepper mesa (AccelStepper::DRIVER, 25, 32);  // STEP1, DIR1  (VERIFICA que sea la mesa)
AccelStepper rotor(AccelStepper::DRIVER, 26, 33);  // STEP2, DIR2  (VERIFICA que sea el rotor)

void setup() {
  Serial.begin(115200);
  // Pasos/s y pasos/s². Valores para paso completo (MS1-3 desconectados).
  // Si cambias a 1/16 de paso, multiplica ambos por 16.
  mesa.setMaxSpeed(100);   mesa.setAcceleration(100);
  rotor.setMaxSpeed(100);  rotor.setAcceleration(100);
  Serial.println("LISTO");
}

void loop() {
  if (!Serial.available()) return;
  String cmd = Serial.readStringUntil('\n');
  cmd.trim();
  if (cmd.length() == 0) return;

  char eje = cmd.charAt(0);
  long pasos = cmd.substring(1).toInt();

  if (eje == 'T')      mesa.runToNewPosition(pasos);   // bloquea hasta llegar
  else if (eje == 'R') rotor.runToNewPosition(pasos);
  else if (eje == 'Z') { mesa.setCurrentPosition(0); rotor.setCurrentPosition(0); }
  else { Serial.println("ERR " + cmd); return; }

  Serial.println("OK");
}
