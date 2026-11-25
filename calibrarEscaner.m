function cal = calibrarEscaner(carpeta, ladoMm)
%CALIBRARESCANER Calibra cámara + ejes de mesa/rotor con un escaneo del tablero.
%   cal = calibrarEscaner("scan_20261125_0048", 5)
%   carpeta: escaneo hecho con captura.m con el tablero (una o dos caras) en vez de figura.
%   ladoMm : lado de un cuadro medido con vernier.
%   Guarda <carpeta>/calib.mat (intrinsics + rig) que usa escanearAStl.
%
%   1) detectCheckerboardPoints en todas las fotos (las de canto/espaldas se descartan solas)
%   2) estimateCameraParameters -> intrínsecos + pose del tablero en cada vista
%   3) lsqnonlin: ejes de mesa y rotor + pose de cada cara del tablero, minimizando la
%      reproyección de TODAS las esquinas con las poses (phi, theta) de poses.csv.
%   Ese error final es la prueba de que el modelo del escáner es bueno (< ~1.5 px).
arguments
    carpeta (1,1) string
    ladoMm  (1,1) double {mustBePositive}
end
T = readtable(fullfile(carpeta, "poses.csv"));
files = fullfile(carpeta, compose("img_%03d.jpg", T.id));
info = imfinfo(files(1)); tam = [info.Height info.Width];

fprintf("Detectando tablero en %d fotos...\n", numel(files));
[P, boardSize, usada] = detectCheckerboardPoints(files, PartialDetections=false);
fprintf("  detectado en %d/%d\n", nnz(usada), numel(files));
assert(nnz(usada) >= 15, "Muy pocas detecciones: revisa enfoque/reflejos del tablero.");
W = patternWorldPoints("checkerboard", boardSize, ladoMm);

cp = estimateCameraParameters(P, W, ImageSize=tam, NumRadialDistortionCoefficients=2);
fprintf("  intrínsecos: error de reproyección %.2f px\n", cp.MeanReprojectionError);

ph = T.phi(usada); th = T.theta(usada); E = cp.PatternExtrinsics;
% ponytail: cara por hemisferio de phi; con una sola cara todo cae en una y da igual
cara = 1 + (cosd(ph - ph(1)) < 0);

% --- inicialización de los ejes con movimientos relativos entre vistas ---
[at, pt] = ejeDesde(E, ph, th, cara, "phi");
[ar, pr] = ejeDesde(E, th, ph, cara, "theta");
tn = unique(th)';
assert(numel(tn) >= 2, "Se necesitan al menos 2 anillos (thetas) para calibrar el rotor.");
[~, iref] = min(abs(tn)); tr = tn;   % ángulo real de cada anillo vs. el de referencia
for i = setdiff(1:numel(tn), iref)
    a = [];
    for k = find(th == tn(i))'
        j = find(th == tn(iref) & ph == ph(k) & cara == cara(k));
        if isempty(j), continue; end
        M = E(k).A / E(j).A; aa = rotm2axang(M(1:3, 1:3));
        a(end+1) = rad2deg(aa(4))*sign(dot(aa(1:3), ar)); %#ok<AGROW>
    end
    if ~isempty(a), tr(i) = tn(iref) + median(a); end
end
rig0 = struct(at=at, pt=pt, ar=ar, pr=pr, sphi=1, thetaNom=tn, thetaReal=tr, W=eye(4));
G = zeros(4, 4, 2);
for c = unique(cara)'
    k = find(cara == c, 1);   % pose de esa cara llevada a phi = theta = 0
    G(:, :, c) = poseEscaner(rig0, ph(k), th(k)) \ E(k).A;
end

% --- ajuste fino ---
Pu = P;
for k = 1:size(P, 3), Pu(:, :, k) = undistortPoints(P(:, :, k), cp.Intrinsics); end
x0 = [at pt ar pr 1 tr tf2vec(G(:,:,1)) tf2vec(G(:,:,2))];
K = cp.Intrinsics.K;
res = @(x) residuo(x, tn, Pu, W, ph, th, cara, K);
fprintf("  error inicial con poses nominales: %.2f px\n", rms(res(x0)));
opts = optimoptions("lsqnonlin", Algorithm="levenberg-marquardt", Display="off", MaxFunctionEvaluations=2e4);
x = lsqnonlin(res, x0, [], [], opts);
r = res(x); r = reshape(r(1:end-1), [], 2);   % sin el término de gauge
e = vecnorm(r, 2, 2);
fprintf("  error final del modelo del escáner: RMS %.2f px, máx %.2f px\n", rms(e), max(e));
rig = vec2rig(x, tn);
fprintf("  mesa: pasos reales/nominales %.4f\n", rig.sphi);
fprintf("  rotor: theta pedida %s -> real %s\n", mat2str(tn), mat2str(rig.thetaReal, 3));
fprintf("  ángulo entre ejes mesa-rotor: %.1f° (ideal 90)\n", acosd(abs(rig.at*rig.ar')));

% --- marco objeto: origen en el eje de la mesa (punto más cercano al eje del rotor),
%     z a lo largo del eje de la mesa apuntando hacia donde estaba el tablero (= figura) ---
z = rig.at;
c = cara(1); centroTablero = G(1:3, :, c) * [mean(W) 0 1]';
o = puntoMasCercano(rig.pt, rig.at, rig.pr, rig.ar);
if dot(centroTablero - o, z) < 0, z = -z; end
xax = cross([0 1 0], z); xax = xax/norm(xax); yax = cross(z, xax);
rig.W = [xax' yax' z' o; 0 0 0 1];

cal = struct(intrinsics=cp.Intrinsics, rig=rig, ladoMm=ladoMm, rmsPx=rms(e), carpeta=carpeta);
save(fullfile(carpeta, "calib.mat"), "-struct", "cal");
fprintf("Guardado: %s\n", fullfile(carpeta, "calib.mat"));
end

function r = residuo(x, tn, Pu, W, ph, th, cara, K)
rig = vec2rig(x, tn);
nR = numel(tn);
G = cat(3, vec2tf(x(14+nR:19+nR)), vec2tf(x(20+nR:25+nR)));
n = size(W, 1); r = zeros(n, 2, numel(ph));
Wh = [W zeros(n, 1) ones(n, 1)]';
for k = 1:numel(ph)
    Xc = poseEscaner(rig, ph(k), th(k)) * G(:, :, cara(k)) * Wh;
    uv = K * Xc(1:3, :);
    r(:, :, k) = (uv(1:2, :) ./ uv(3, :))' - Pu(:, :, k);
end
% gauge: el anillo más cercano a theta=0 se queda en su valor nominal (si no, la pose del
% tablero y todos los ángulos del rotor podrían girar juntos sin cambiar el error)
[~, iref] = min(abs(tn));
r = [r(:); 100*(rig.thetaReal(iref) - tn(iref))];
end

function rig = vec2rig(x, tn)
nR = numel(tn);
rig = struct(at=x(1:3)/norm(x(1:3)), pt=x(4:6), ar=x(7:9)/norm(x(7:9)), pr=x(10:12), ...
    sphi=x(13), thetaNom=tn, thetaReal=x(14:13+nR), W=eye(4));
end

function v = tf2vec(A), v = [rotvec(A(1:3,1:3)), A(1:3,4)']; end
function A = vec2tf(v), A = [rotvecInv(v(1:3)), v(4:6)'; 0 0 0 1]; end

function v = rotvec(R)
aa = rotm2axang(R); v = aa(1:3)*aa(4);
end
function R = rotvecInv(v)
a = norm(v);
if a < 1e-12, R = eye(3); else, R = axang2rotm([v/a a]); end
end

function [a, p] = ejeDesde(E, angMov, angFijo, cara, nombre)
% Eje de giro a partir de pares de vistas que solo difieren en el ángulo angMov.
ejes = []; pts = [];
for c = unique(cara)'
    for f = unique(angFijo)'
        idx = find(cara == c & angFijo == f);
        for i = 1:numel(idx)
            for j = i+1:numel(idx)
                d = angMov(idx(j)) - angMov(idx(i));
                if abs(d) < 1 || abs(d) > 90, continue; end
                M = E(idx(j)).A / E(idx(i)).A;
                aa = rotm2axang(M(1:3, 1:3));
                s = sign(d);
                ejes(end+1, :) = aa(1:3)*s; %#ok<AGROW>
                pts(end+1, :) = (pinv(eye(3) - M(1:3,1:3)) * M(1:3, 4))'; %#ok<AGROW>
            end
        end
    end
end
assert(~isempty(ejes), "No hay vistas suficientes para estimar el eje de %s.", nombre);
a = median(ejes, 1); a = a/norm(a);
p = median(pts, 1);
end

function o = puntoMasCercano(p1, d1, p2, d2)
% punto de la recta 1 más cercano a la recta 2
n = cross(d1, d2);
if norm(n) < 1e-9, o = p1(:); return; end
t = dot(cross(p2 - p1, d2), n) / dot(n, n);
o = (p1 + t*d1)';
end
