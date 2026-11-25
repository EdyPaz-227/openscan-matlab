# Guía paso a paso: escanear una figura y sacar su STL

OpenScan Classic + ESP32 + celular con IP Webcam + MATLAB.
Última actualización: **2026-11-25** (ver [Historial de cambios](#historial-de-cambios) al final).

---

## Vista general

```
 A. Preparar (una vez por sesión)          B. Calibrar (cada vez que se mueva el celular)
 ─────────────────────────────────         ───────────────────────────────────────────────
 Paso 1  Escáner y firmware                Paso 5  Montar el tablero
 Paso 2  Celular e IP Webcam               Paso 6  Enfocar (captura.m, sección 0)
 Paso 3  Abrir MATLAB                      Paso 7  Escanear el tablero (sección 3)
 Paso 4  Conectar el ESP32 (sección 1)     Paso 8  calibrarEscaner

 C. Cada figura                            D. Revisar
 ─────────────────────────────────         ───────────────────────────────────────────────
 Paso 9   Montar la figura (¡rígida!)      Paso 12  Revisar el STL
 Paso 10  Escanear la figura (sección 3)
 Paso 11  revisarMascaras + escanearAStl
```

### La regla de oro
Desde que enfocas (paso 6) hasta la última figura de la sesión, **el celular no se toca**:
no se mueve, no se cambia zoom, enfoque ni resolución.
Si algo de eso pasa, regresa al **paso 5** (nuevo enfoque + nuevo tablero + nueva calibración).
Si solo se cerró IP Webcam, no hace falta: regresa al enfoque anotado (paso 6, punto 3).
Lo que sí puedes hacer sin recalibrar: cambiar de figura, apagar y prender el ESP32.

### Tiempos aproximados
| Paso | Tiempo |
|---|---|
| Enfocar (sección 0) | ~1 min |
| Escanear (96 fotos) | ~7 min |
| Calibrar | ~2 min |
| STL, primera vez por figura | ~20–25 min (casi todo es buscar puntos en las fotos) |
| STL, siguientes veces de la misma figura | ~2 min |

---

## A. Preparar

### Paso 1 — Escáner y firmware

1. Fondo y base verdes, bien iluminados y **sin sol directo** (la luz no debe cambiar
   durante el escaneo). Sin sombras duras sobre el fondo.
2. El poste blanco bien apretado en la mesa. Muévelo con el dedo: no debe tener juego.
3. Gira a mano (con el ESP32 apagado) la mesa y el rotor: deben girar libres, sin trabarse.
4. Firmware: `esp32_escaner/esp32_escaner.ino` debe tener
   `setAcceleration(100)` en mesa y rotor (arranques suaves para que la figura no tiemble).
   Si alguna vez lo cambias, vuelve a cargarlo al ESP32 desde Arduino IDE.
5. Conecta el ESP32 por USB. En el **Administrador de dispositivos → Puertos (COM y LPT)**
   anota el número de puerto (por ejemplo `COM6`).

### Paso 2 — Celular e IP Webcam

1. Pon el celular en su soporte, apuntando al centro de giro (donde va la figura).
   La figura debe quedar completa en la foto en todas las posiciones, con margen.
2. Conéctalo a **cargador** y a la **misma red Wi-Fi** que la computadora.
3. Abre IP Webcam → baja hasta el final → **Iniciar servidor**.
4. Anota la IP que aparece en la pantalla del celular (ejemplo `http://192.168.1.10:8080`).
5. Que la pantalla no se apague: en las opciones de energía de IP Webcam activa que el
   teléfono no entre en suspensión, o súbele el tiempo de apagado de pantalla al máximo.
   Si el celular se suspende a media captura, MATLAB marca error de conexión.
6. Comprueba desde la computadora: abre la IP en el navegador; debes ver la imagen en vivo.

> No hace falta configurar enfoque ni resolución en la app: MATLAB lo manda solo por la
> red en el paso 6. (IP Webcam olvida esos ajustes cada vez que se reinicia.)

### Paso 3 — Abrir MATLAB

1. Abre **MATLAB R2026a** (no R2026b: esa no tiene instalados los toolboxes de
   Image Processing, Computer Vision y Optimization que usa el proyecto).
2. Ve a la carpeta del proyecto:
   ```matlab
   cd("C:\Users\minie\OneDrive\Documentos\MATLAB\Scanner")
   ```
3. Abre `captura.m`. Arriba, en `%% Configuración`, revisa:
   - `puerto = "COM6";` → el que anotaste en el paso 1.
   - `camUrl = "http://192.168.1.10:8080";` → la IP del paso 2.
4. Corre la sección `%% Configuración`: pon el cursor dentro y presiona **Ctrl+Enter**.
   (Así se corre cada sección de `captura.m`: cursor dentro + Ctrl+Enter.)

### Paso 4 — Conectar el ESP32

1. Corre la **sección 1** (Conectar). Tarda ~2 s (el ESP32 se reinicia al abrir el puerto).
2. Si da error de puerto ocupado: cierra el Monitor Serie de Arduino IDE y vuelve a correrla.
3. **Sección 2 (opcional):** solo si cambiaste motores, engranes o micropasos.
   - La mesa debe dar exactamente **10 vueltas** y caer en el mismo punto.
     Si da `k` vueltas, cambia `ppgMesa = ppgMesa*10/k` en Configuración.
   - El rotor debe inclinarse 45° y regresar. Si mides `a` grados con transportador,
     cambia `ppgRotor = ppgRotor*45/a`.

---

## B. Calibrar (cada vez que se mueva el celular)

### Paso 5 — Montar el tablero

1. Si no lo tienes: `generarTablero()` crea `tablero_7x8_5mm.pdf`. Imprímelo al **100 %**
   ("tamaño real", nunca "ajustar a página"), en papel mate.
2. Mide con vernier la regla de 50 mm y un cuadro. Si el cuadro no mide 5.00 mm, usa tu
   medida en el paso 8.
3. Pégalo en cartón rígido y plano. Mejor con **una copia en cada cara**.
4. Móntalo como **bandera** sobre el poste con plastilina: el plano del tablero contiene el
   eje del poste, centrado donde irá la figura y de frente a la cámara.
5. Que quede firme (mismo criterio que la figura, paso 9).

### Paso 6 — Enfocar (sección 0)

1. Con el tablero montado, corre la **sección 0** de `captura.m`.
2. MATLAB hace solo esto:
   - pone la foto en 2560×1440 y **apaga el autoenfoque**;
   - toma una foto por cada enfoque (de 2 a 10, luego fino de 0.1 en 0.1) y mide la nitidez;
   - deja fijo el más nítido y te muestra la gráfica.
3. Lee el mensaje: `Enfoque fijo en X dioptrías (~Y cm)`.
   - Si sale el **aviso de enfoque al límite (10)**: el objeto está más cerca de lo que el
     lente alcanza a enfocar. Aleja un poco el celular y repite este paso.
   - **Anota el valor X.** Si a media sesión IP Webcam se cierra o se reinicia, NO vuelvas
     a correr la sección 0 (podría escoger otro enfoque y la calibración ya no serviría).
     Abre IP Webcam, inicia el servidor y en la ventana de comandos regresa al mismo valor:
     ```matlab
     for s = ["photo_size?set=2560x1440" "focusmode?set=off" "focus_distance?set=X"]
         webread(camUrl + "/settings/" + s, opt);
     end
     ```
     (cambia `X` por tu número, por ejemplo `focus_distance?set=9.70`).
4. Corre la sección `%% Foto de prueba` (después de la sección 2) y revisa que el tablero
   se vea nítido.

### Paso 7 — Escanear el tablero (sección 3)

1. Deja el rotor horizontal (posición cero). Si no lo está, mándalo a cero en la ventana
   de comandos: `writeline(esp, "R 0"); readline(esp)` (debe responder `"OK"`).
2. Corre la **sección 3** (Captura). Se crea una carpeta `scan_AAAAMMDD_HHMM` y verás
   `1/96 phi=0 theta=-20`, `2/96 ...` hasta `96/96`. Tarda ~7 min.
3. **Anota el nombre de la carpeta**: es tu *carpeta del tablero* para toda la sesión.
4. No toques la mesa ni el celular mientras escanea.

### Paso 8 — Calibrar

```matlab
cal = calibrarEscaner("scan_DEL_TABLERO", 5);   % 5 = lado del cuadro en mm (tu medida)
```

Guarda `calib.mat` dentro de esa carpeta. Revisa lo que imprime:

| Mensaje | Bien | Si sale mal |
|---|---|---|
| `detectado en N/96` | ≥ 30 | Reflejos, tablero desenfocado o muy de canto |
| `intrínsecos: error de reproyección` | < 1.5 px | Tablero no plano, desenfocado, o el enfoque cambió (¿paso 6?) |
| `error final del modelo del escáner` | < 4 px | Algo se movió durante el escaneo o el tablero estaba flojo |
| `ángulo entre ejes mesa-rotor` | ~90° | Montaje torcido (no es grave) |

Si algo sale mal, corrige la causa y repite desde el paso 7.

---

## C. Cada figura

### Paso 9 — Montar la figura (lo más importante para que salgan colas y patas)

1. Quita el tablero **sin mover el celular**.
2. Fija la figura al poste con plastilina **negra** (nunca verde: lo verde se borra).
3. **Prueba de rigidez:** dale un golpecito con el dedo. **No debe balancearse ni quedarse
   movida.** Si se mueve: más plastilina, apóyala más cerca del poste, o una plastilina más
   dura. Si la figura se mueve aunque sea 1 mm durante el escaneo, las partes delgadas
   desaparecen del STL y ningún ajuste lo arregla. (Esto le pasó al león el 2026-11-25.)
4. Centrada lo más posible sobre el eje del poste.
5. Revisa que quepa en la foto en las inclinaciones extremas. En la ventana de comandos:
   ```matlab
   writeline(esp, "R " + round(40*ppgRotor)); readline(esp); imshow(imread(camUrl + "/photo.jpg"))
   writeline(esp, "R " + round(-20*ppgRotor)); readline(esp); imshow(imread(camUrl + "/photo.jpg"))
   writeline(esp, "R 0"); readline(esp);
   ```
   La figura completa debe verse en ambas fotos.

**Qué figuras funcionan bien:**

| Funciona | Da problemas |
|---|---|
| Opaca, mate o satinada | Transparente o tipo espejo |
| Con textura o pintura irregular | Un solo color liso (no hay puntos para corregir ángulos) |
| Cualquier color **excepto verde** | Partes verdes: desaparecen |
| Que quepa completa en todas las posiciones | Que se salga del cuadro al inclinarse |

### Paso 10 — Escanear la figura

1. Rotor en cero (`writeline(esp, "R 0"); readline(esp)` si hace falta).
2. Corre la **sección 3**. Se crea otra carpeta `scan_...` (la *carpeta de la figura*).
3. Mira la figura durante las primeras fotos de cada anillo: si la ves temblar o
   recorrerse, detén con **Ctrl+C**, fíjala mejor (paso 9) y vuelve a escanear.
4. Para más figuras en la misma sesión: repite pasos 9 y 10 (sin recalibrar).

### Paso 11 — Máscaras y STL

**11a. Revisar máscaras**

```matlab
revisarMascaras("scan_DE_LA_FIGURA")
```

Abre `scan_DE_LA_FIGURA/revision_mascaras.png`. En cada foto, todo lo que gira (figura,
plastilina y poste) debe quedar **completo en magenta**, y el fondo sin manchas magenta.
- Se pierden partes oscuras → `revisarMascaras("scan_...", 0.07)` y usa `Umbral=0.07` en 11b.
- Entra fondo → prueba un número menor (`0.05`).
- Una foto mala (movida, borrosa) → anota su número para excluirla con `Vistas`.

**11b. Generar el STL**

```matlab
escanearAStl("scan_DE_LA_FIGURA", "scan_DEL_TABLERO", Tolerancia=3)
```

Lo que hace, en orden (vas a ver estos mensajes):
1. `Refinando rotor: features KAZE...` — busca puntos de la figura en las 96 fotos.
   **Es lo lento (~20 min) y solo pasa la primera vez**; queda guardado en
   `emparejamientos.mat`.
2. `error epipolar` y `Ajuste por haces` — corrige el ángulo real del rotor por anillo y
   el de la mesa por foto. Queda en `rig_refinado.mat`.
3. `Pasada fina` — talla el modelo con las siluetas.
4. `Silueta explicada por el modelo: media X%` — **el número para juzgar la calidad**:

   | Media | Significa |
   |---|---|
   | ≥ 95 % | Muy bien |
   | 90–95 % | Aceptable; partes muy finas pueden perderse |
   | < 90 % | Algo se movió (figura floja, celular) o la calibración no corresponde |

5. `STL: ...` — tamaño en mm. Compáralo con la figura real medida con regla.

Opciones (se agregan dentro del paréntesis, separadas por comas):

| Opción | Para qué |
|---|---|
| `Tolerancia=3` | Cuántas fotos pueden "no ver" un punto sin borrarlo. Más alto = conserva partes finas pero el modelo engorda un poco. Default 1; recomendado 3 |
| `ResolucionMm=0.2` | Más detalle (más lento). Default 0.25 |
| `Vistas=[1:20 22:96]` | Excluir fotos malas (aquí, la 21) |
| `Umbral=0.07` | El mismo umbral que usaste en 11a |
| `RefinarRotor=false` | No corregir ángulos (solo para comparar) |

**11c. Volver a generar el STL (rápido, ~2 min)**

Corre **exactamente el mismo comando** otra vez, cambiando solo las opciones que quieras:

```matlab
escanearAStl("scan_DE_LA_FIGURA", "scan_DEL_TABLERO", Tolerancia=2, ResolucionMm=0.2)
```

Como la carpeta de la figura ya tiene `rig_refinado.mat`, se salta la parte lenta y va
directo a `Máscaras...` / `Pasada fina`. Puedes cambiar `Tolerancia`, `ResolucionMm`,
`Vistas` y `Umbral` las veces que quieras sin recalcular nada.

⚠ Cada corrida **sobrescribe** `scan_DE_LA_FIGURA.stl` y `vista_stl.png`. Si te gustó uno,
renómbralo antes (por ejemplo `scan_..._tol3.stl`).

Cuándo borrar los archivos guardados (en la carpeta de la figura):

| Borras | Pasa | Cuándo |
|---|---|---|
| nada | ~2 min | Solo cambias opciones del STL |
| `rig_refinado.mat` | ~3 min (recalcula ángulos con los puntos guardados) | Recalibraste con otro tablero pero las fotos de la figura son las mismas |
| `rig_refinado.mat` y `emparejamientos.mat` | ~25 min (todo de nuevo) | Cambiaste o volviste a tomar las fotos en esa carpeta |

---

## D. Revisar

### Paso 12 — Revisar el STL

1. Mira `scan_DE_LA_FIGURA/vista_stl.png` (vista rápida).
2. Abre `scan_DE_LA_FIGURA/scan_DE_LA_FIGURA.stl` en tu slicer o en Meshmixer.
3. El STL incluye la plastilina y el poste: córtalos ahí.
4. Limitación normal: los huecos que ninguna foto ve de perfil (dentro de una oreja, bajo
   la panza) salen rellenos.

---

## Problemas y soluciones

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| `ESP32 no respondió OK` | Puerto equivocado, cable, o Monitor Serie abierto | Revisa `puerto`, cierra Arduino IDE, repite sección 1 |
| `Can't read URL` / `Failed to connect ... 8080` | IP Webcam cerrado, celular suspendido o cambió de IP | Abre IP Webcam → Iniciar servidor, revisa `camUrl`; si se cerró la app, regresa al enfoque anotado (paso 6, punto 3) |
| `strel requires Image Processing Toolbox` | Abriste MATLAB R2026b | Usa R2026a |
| Calibración: pocas detecciones | Reflejos o desenfoque en el tablero | Luz más difusa; repite paso 6 |
| Faltan colas, patas, partes finas | Figura se movió, o ángulos sin corregir | Paso 9 (rigidez) y `Tolerancia=3` |
| Modelo deforme / "doble" | Celular movido después de calibrar | Recalibrar (pasos 5–8) |
| Manchas de fondo pegadas al modelo | Umbral de verde | Paso 11a con umbral menor |
| `La pasada gruesa borró todo` | Calibración de otra posición del celular | Usa el tablero de esta sesión o recalibra |

### Cosas que ya sabemos del hardware
- **Rotor:** al pedirle 40° gira unos 27° (holgura/carga), y cambia entre escaneos.
  `escanearAStl` lo corrige solo con la textura de la figura.
- **Mesa:** después de 10 vueltas cae en el mismo punto (no pierde pasos).
- **Figura:** si tiembla al girar, queda movida → siluetas que no coinciden → se pierden
  partes finas. Por eso `espera = 2` s en `captura.m` y aceleración 100 en el firmware.

---

## Archivos

| Archivo | Qué hace |
|---|---|
| `captura.m` | Sección 0: fija y enfoca la cámara. 1: conecta. 2: prueba motores. 3: toma las 96 fotos + `poses.csv` |
| `esp32_escaner/esp32_escaner.ino` | Firmware: comandos `T`, `R`, `Z` por serial |
| `generarTablero.m` | PDF del tablero a escala real |
| `calibrarEscaner.m` | Intrínsecos del celular + ejes de mesa y rotor → `calib.mat` |
| `revisarMascaras.m` | Mosaico para revisar las máscaras |
| `escanearAStl.m` | Corrige ángulos (vía `refinarRotor`) y talla el STL |
| `refinarRotor.m` | Ángulo real del rotor por anillo y de la mesa por foto |
| `mascaraObjeto.m` | Separa todo lo que no es verde |
| `poseEscaner.m` | Convierte (φ, θ) en la pose de la cámara |

Archivos que aparecen dentro de cada carpeta `scan_...`:

| Archivo | Qué es |
|---|---|
| `img_001.jpg` … `img_096.jpg` | Las fotos |
| `poses.csv` | Ángulos pedidos de cada foto |
| `calib.mat` | (solo carpeta del tablero) la calibración |
| `emparejamientos.mat`, `rig_refinado.mat` | (carpeta de figura) correcciones guardadas |
| `revision_mascaras.png` | Resultado del paso 11a |
| `scan_....stl`, `vista_stl.png` | El modelo y su vista rápida |

---

## Historial de cambios

- **2026-11-25**
  - `captura.m`, sección 0: fija resolución y **busca el enfoque solo** (barrido de
    nitidez); ya no se enfoca a mano en la app.
  - `captura.m`: `espera` 0.5 → 2 s (la figura temblaba); comentario de la prueba de mesa
    corregido (10 vueltas).
  - `escanearAStl`: corrige ángulos automáticamente (`refinarRotor` + ajuste por haces:
    rotor por anillo y mesa por foto). Margen de la pasada fina 4 → 12 mm.
  - Recomendado `Tolerancia=3`. Paso de rigidez de la figura agregado.
  - Usar MATLAB R2026a (R2026b no tiene los toolboxes).
  - Paso 11c: cómo regenerar el STL rápido y cuándo borrar los archivos guardados.
