% Captura con OpenScan Classic + ESP32 + celular (IP Webcam).
% Corre sección por sección (Ctrl+Enter).

%% Configuración
puerto   = "COM6";                    % VERIFICA en Administrador de dispositivos
camUrl   = "http://192.168.1.10:8080";
ppgMesa  = 200*1*1/360;               % pasos por grado = 200 * microstep * engranes / 360 -> CALIBRA en sección 2
ppgRotor = -200*1*(64/12)/360;        % signo negativo = sentido de giro invertido
phis     = 0:15:345;                  % 24 posiciones de mesa
thetas   = [-20 0 20 40];             % 4 anillos  -> 96 fotos
espera   = 1;                         % s para que se calme la vibración antes de la foto (0.5 no alcanzaba: el león temblaba)
opt      = weboptions(Timeout=20);

%% 0. Fijar la cámara y enfocar (córrela cada vez que muevas el celular o reinicies IP Webcam)
% El autoenfoque continuo cambia la focal entre fotos y entre calibración y escaneo, así que
% se apaga y se busca el enfoque manual más nítido sobre lo que tengas montado (tablero o figura).
% Esto se manda solo al celular por la red; no hay que tocar la app.
for s = ["photo_size?set=2560x1440" "focusmode?set=off"], webread(camUrl + "/settings/" + s, opt); end
foco = buscarFoco(camUrl, 2:0.5:10, opt);                   % grueso
foco = buscarFoco(camUrl, max(0, foco-0.4):0.1:min(10, foco+0.4), opt);   % fino
webread(camUrl + "/settings/focus_distance?set=" + sprintf("%.2f", foco), opt);
fprintf("Enfoque fijo en %.2f dioptrías (~%.0f cm)\n", foco, 100/foco);
if foco >= 10, warning("Enfoque al límite (10): aleja un poco el celular, el objeto está más cerca de lo que enfoca."); end

%% 1. Conectar (abrir el puerto reinicia el ESP32)
clear esp                                  % suelta el puerto si esta sección ya se había corrido
esp = serialport(puerto, 115200, Timeout=30);
configureTerminator(esp, "CR/LF", "LF");   % Arduino responde con \r\n, nosotros mandamos \n
pause(2); flush(esp);                      % descarta los mensajes de arranque

%% 2. Prueba / calibración de pasos por grado
% Mesa: debe dar EXACTAMENTE 10 vueltas y caer en el mismo punto. Si da k -> ppgMesa = ppgMesa*10/k
enviar(esp, "Z");
enviar(esp, "T " + round(3600*ppgMesa));
% Rotor: mide el ángulo real con transportador o app de nivel. Si giró a° -> ppgRotor = ppgRotor*90/a
enviar(esp, "R " + round(45*ppgRotor));
pause(0.5);
enviar(esp, "R 0");
%% Foto de prueba a resolución completa
imshow(imread(camUrl + "/photo.jpg"))

%% 3. Captura
% Antes: deja el objeto en su posición cero (rotor horizontal) y corre la sección 0.
% No muevas el celular entre el tablero y las figuras (si lo mueves, re-escanea el tablero).
carpeta = "scan_" + string(datetime("now", Format="yyyyMMdd_HHmm"));
mkdir(carpeta);
enviar(esp, "Z");
reg = zeros(0, 3);
n = numel(phis)*numel(thetas);
for th = thetas
    enviar(esp, "R " + round(th*ppgRotor));
    for ph = phis
        enviar(esp, "T " + round(ph*ppgMesa));
        pause(espera);
        k = size(reg, 1) + 1;
        websave(fullfile(carpeta, sprintf("img_%03d.jpg", k)), camUrl + "/photo.jpg", opt);
        reg(k, :) = [k ph th];
        % se reescribe en cada foto: si algo truena a medio escaneo, no pierdes las poses
        writetable(array2table(reg, VariableNames=["id" "phi" "theta"]), fullfile(carpeta, "poses.csv"));
        fprintf("%3d/%d  phi=%4g  theta=%4g\n", k, n, ph, th);
    end
end
enviar(esp, "T 0"); enviar(esp, "R 0");
disp("Listo: " + carpeta)

%% Funciones
function mejor = buscarFoco(camUrl, focos, opt)
    % Toma una foto por enfoque y se queda con la de más detalle (varianza del laplaciano)
    % dentro de lo que no es verde.
    nit = zeros(size(focos));
    for k = 1:numel(focos)
        webread(camUrl + "/settings/focus_distance?set=" + sprintf("%.2f", focos(k)), opt);
        pause(1.5);                                         % que el lente termine de moverse
        I = webread(camUrl + "/photo.jpg", opt);            % imread no tiene timeout configurable
        M = imresize(mascaraObjeto(imresize(I, 0.25)), size(I, [1 2]), "nearest");
        L = imfilter(im2double(rgb2gray(I)), fspecial("laplacian"), "replicate");
        nit(k) = var(L(M));
    end
    [~, b] = max(nit); mejor = focos(b);
    figure(1); plot(focos, nit, "o-"); xlabel("focus\_distance (dioptrías)"); ylabel("nitidez");
    title(sprintf("Mejor: %.2f", mejor)); drawnow
end
function enviar(esp, cmd)
    writeline(esp, cmd);
    r = readline(esp);                     % [] si se agota el Timeout
    if ~strcmp(r, "OK")
        error("ESP32 no respondió OK a '%s' (respuesta: '%s')", cmd, string(r));
    end
end
