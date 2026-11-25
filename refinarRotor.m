function rig = refinarRotor(carpeta, cal, T)
%REFINARROTOR Corrige los ángulos reales del rotor (y la escala de la mesa) de UN escaneo
%   usando la textura de la propia figura.
%   rig = refinarRotor("scan_xxx", cal, T)    cal = load(calib.mat), T = poses.csv (tabla)
%
%   Por qué: el rotor pierde pasos y su posición no se repite entre escaneos, así que los
%   ángulos que da la calibración del tablero no sirven tal cual para otra figura. Los ejes
%   (dirección y posición) y los intrínsecos sí se conservan; solo se reajustan
%   thetaReal (uno por anillo) y sphi.
%   Cómo: KAZE dentro de la máscara -> emparejamiento entre fotos vecinas (MSAC con la
%   matriz fundamental) -> lsqnonlin minimizando la distancia de Sampson, con pérdida
%   de Huber para que los emparejamientos falsos no jalen la solución. Después, ajuste por
%   haces restringido (ajustarHaces) que además corrige el ángulo de la mesa de cada foto
%   (rig.dphi) usando puntos vistos en >=3 fotos.
n = height(T);
intr = cal.intrinsics;
cache = fullfile(carpeta, "emparejamientos.mat");   % lo lento; bórralo si cambian fotos o calibración
if isfile(cache)
    load(cache, "usados", "m1", "m2");
    fprintf("Refinando rotor: emparejamientos de %s\n", cache);
else
    [usados, m1, m2] = emparejar(carpeta, T, intr);
    save(cache, "usados", "m1", "m2");
end
anillo = findgroups(T.theta);
vistas = unique(usados(:));
fprintf("  %d pares útiles, %d/%d fotos conectadas\n", size(usados, 1), numel(vistas), n);
assert(size(usados, 1) >= 20, "Muy pocos emparejamientos: ¿la figura tiene textura suficiente?");
for a = unique(anillo)'
    if ~any(ismember(find(anillo == a), vistas))
        warning("El anillo theta=%g no quedó conectado; se usa su ángulo de calibración.", T.theta(find(anillo == a, 1)));
    end
end

rig0 = cal.rig;
x0 = [rig0.thetaReal rig0.sphi];
Kinv = inv(intr.K);
res = @(x) sampson(x, rig0, T, usados, m1, m2, Kinv);
r0 = res(x0);
x = lsqnonlin(res, x0, [], [], optimoptions("lsqnonlin", Display="off"));
r1 = res(x);
rig = rig0; rig.thetaReal = x(1:end-1); rig.sphi = x(end);
fprintf("  error epipolar (mediana): %.2f px -> %.2f px\n", median(abs(r0)), median(abs(r1)));
fprintf("  rotor real: calibración %s -> este escaneo %s\n", mat2str(rig0.thetaReal, 3), mat2str(rig.thetaReal, 3));
fprintf("  mesa: sphi %.4f -> %.4f\n", rig0.sphi, rig.sphi);
rig = ajustarHaces(rig, T, usados, m1, m2, intr.K);
end

function rig = ajustarHaces(rig, T, usados, m1, m2, K)
% Bundle adjustment restringido: la epipolar casi no ve el ángulo de giro (en tornamesa los
% puntos se mueven A LO LARGO de su línea epipolar), la reproyección de puntos vistos en >=3
% fotos sí. Parámetros: dphi por foto (la mesa también pierde pasos), thetaReal por anillo
% y los puntos 3D. Ejes, sphi e intrínsecos fijos (refinar ejes no ayudó).
n = height(T); na = numel(rig.thetaReal); anillo = findgroups(T.theta);

% tracks: un keypoint es el mismo si tiene la misma (foto, x, y) en dos pares distintos
nodos = cell(numel(m1), 1); ea = nodos; eb = nodos; base = 0;
for q = 1:numel(m1)
    k = size(m1{q}, 1);
    nodos{q} = [repmat(usados(q, 1), k, 1) m1{q}(:, 1:2); repmat(usados(q, 2), k, 1) m2{q}(:, 1:2)];
    ea{q} = base + (1:k)'; eb{q} = base + k + (1:k)'; base = base + 2*k;
end
[nodos, ~, id] = unique(vertcat(nodos{:}), "rows");
comp = conncomp(graph(id(vertcat(ea{:})), id(vertcat(eb{:})), [], size(nodos, 1)))';
nObs = accumarray(comp, 1);
u = unique([comp nodos(:, 1)], "rows"); nVis = accumarray(u(:, 1), 1, size(nObs));
okT = nObs >= 3 & nVis == nObs;                  % >=3 fotos y sin dos puntos en la misma foto
sel = okT(comp);
vista = nodos(sel, 1); xy = nodos(sel, 2:3); trk = findgroups(comp(sel));
fprintf("Ajuste por haces: %d tracks de >=3 fotos (%d observaciones)\n", max(trk), numel(trk));
assert(max(trk) >= 50, "Muy pocos tracks para el ajuste por haces.");

x = [zeros(n, 1); rig.thetaReal(:)];
for ronda = 1:2                                  % triangular -> quitar outliers -> optimizar
    A = poses(x, rig, T, n, na);
    P = triangular(A, K, vista, xy, trk);
    e = errores(A, K, P, vista, xy, trk);
    umbral = [6 2]; malo = accumarray(trk, e, [], @max) > umbral(ronda);
    keep = ~malo(trk);
    vista = vista(keep); xy = xy(keep, :); [trk, ~] = findgroups(trk(keep)); P = P(~malo, :);
    fprintf("  ronda %d: %d tracks, reproyección mediana %.2f px", ronda, max(trk), median(e(keep)));
    nt = max(trk); no = numel(trk);
    xx = [x; reshape(P', [], 1)];
    J = sparse([2*(1:no)-1, 2*(1:no)]', repmat(vista, 2, 1), 1, 2*no + n + na, numel(xx));
    J = J + sparse([2*(1:no)-1, 2*(1:no)]', repmat(n + anillo(vista), 2, 1), 1, 2*no + n + na, numel(xx));
    for c = 1:3
        J = J + sparse([2*(1:no)-1, 2*(1:no)]', repmat(n + na + 3*(trk-1) + c, 2, 1), 1, 2*no + n + na, numel(xx));
    end
    J = J + sparse(2*no + (1:n+na), 1:n+na, 1, 2*no + n + na, numel(xx));
    th0 = rig.thetaReal(:);
    f = @(xx) residuos(xx, rig, T, n, na, K, vista, xy, trk, nt, th0);
    xx = lsqnonlin(f, xx, [], [], optimoptions("lsqnonlin", Display="off", ...
        JacobPattern=double(J ~= 0), MaxIterations=50));
    x = xx(1:n+na);
    A = poses(x, rig, T, n, na);
    e = errores(A, K, reshape(xx(n+na+1:end), 3, [])', vista, xy, trk);
    fprintf(" -> %.2f px\n", median(e));
end
rig.dphi = x(1:n);                               % se suma a T.phi en escanearAStl
rig.thetaReal = x(n+1:end)';
fprintf("  rotor real final: %s\n", mat2str(rig.thetaReal, 3));
fprintf("  corrección de mesa por foto: mediana |dphi| %.2f°, máx %.2f° (foto %d)\n", ...
    median(abs(rig.dphi)), max(abs(rig.dphi)), T.id(find(abs(rig.dphi) == max(abs(rig.dphi)), 1)));
end

function A = poses(x, rig, T, n, na)
rig.thetaReal = x(n+1:n+na)';
A = cell(n, 1);
for k = 1:n, A{k} = poseEscaner(rig, T.phi(k) + x(k), T.theta(k)); end
end

function P = triangular(A, K, vista, xy, trk)
% DLT lineal por track (coordenadas ya sin distorsión)
M = cellfun(@(a) K*a(1:3, :), A, UniformOutput=false);
grupos = accumarray(trk, (1:numel(trk))', [], @(i) {i});
P = zeros(numel(grupos), 3);
for t = 1:numel(grupos)
    i = grupos{t}; B = zeros(2*numel(i), 4);
    for j = 1:numel(i)
        Mk = M{vista(i(j))};
        B(2*j-1, :) = xy(i(j), 1)*Mk(3, :) - Mk(1, :);
        B(2*j, :)   = xy(i(j), 2)*Mk(3, :) - Mk(2, :);
    end
    [~, ~, V] = svd(B, 0); P(t, :) = V(1:3, 4)'/V(4, 4);
end
end

function d = proyectar(A, K, P, vista, xy, trk)
d = zeros(2, numel(trk));
for k = unique(vista)'
    o = vista == k;
    p = K*A{k}(1:3, :)*[P(trk(o), :)'; ones(1, nnz(o))];
    d(:, o) = p(1:2, :)./p(3, :) - xy(o, :)';
end
end

function e = errores(A, K, P, vista, xy, trk)
e = vecnorm(proyectar(A, K, P, vista, xy, trk))';
end

function r = residuos(xx, rig, T, n, na, K, vista, xy, trk, nt, th0)
A = poses(xx(1:n+na), rig, T, n, na);
d = proyectar(A, K, reshape(xx(n+na+1:n+na+3*nt), 3, [])', vista, xy, trk);
d = d(:); a = abs(d); delta = 1;              % Huber, px
d(a > delta) = sign(d(a > delta)).*sqrt(2*delta*a(a > delta) - delta^2);
% prior: dphi ~ 0 ± 3° (fija el giro global, que es libre) y theta cerca del epipolar ± 10°
r = [d; xx(1:n)/3; (xx(n+1:n+na) - th0)/10];
end

function [usados, m1, m2] = emparejar(carpeta, T, intr)
n = height(T);
fprintf("Refinando rotor: features KAZE en %d fotos...\n", n);
feat = cell(n, 1); pu = cell(n, 1);
for k = 1:n
    I = imread(fullfile(carpeta, sprintf("img_%03d.jpg", T.id(k))));
    M = imresize(mascaraObjeto(imresize(I, 0.5)), size(I, [1 2]), "nearest");
    bb = regionprops(M, "BoundingBox").BoundingBox;          % ponytail: recorte = KAZE 5x más rápido
    r = max(1, floor(bb(2)) - 10):min(size(I, 1), ceil(bb(2) + bb(4)) + 10);
    c = max(1, floor(bb(1)) - 10):min(size(I, 2), ceil(bb(1) + bb(3)) + 10);
    g = rgb2gray(I(r, c, :));
    Me = imerode(M(r, c), strel("disk", 6));                % el borde es silueta, no textura fija
    p = detectKAZEFeatures(g);
    p = p(Me(sub2ind(size(Me), round(p.Location(:, 2)), round(p.Location(:, 1)))));
    [feat{k}, v] = extractFeatures(g, p);
    pu{k} = undistortPoints(double(v.Location) + [c(1) - 1, r(1) - 1], intr);
end

% pares: vecinos en el mismo anillo (±30°) y entre anillos contiguos (±15°)
anillo = findgroups(T.theta);
pares = zeros(0, 2);
for i = 1:n
    for j = i+1:n
        dphi = abs(mod(T.phi(j) - T.phi(i) + 180, 360) - 180);
        da = abs(anillo(j) - anillo(i));
        if (da == 0 && dphi > 0 && dphi <= 30) || (da == 1 && dphi <= 15)
            pares(end+1, :) = [i j]; %#ok<AGROW>
        end
    end
end

fprintf("  emparejando %d pares...\n", size(pares, 1));
w = warning("off", "all"); limpiar = onCleanup(@() warning(w));   % MSAC avisa por cada par difícil
m1 = {}; m2 = {}; usados = zeros(0, 2);
for q = 1:size(pares, 1)
    i = pares(q, 1); j = pares(q, 2);
    m = matchFeatures(feat{i}, feat{j}, Unique=true, MaxRatio=0.8);
    if size(m, 1) < 15, continue; end
    [~, inl] = estimateFundamentalMatrix(pu{i}(m(:, 1), :), pu{j}(m(:, 2), :), ...
        Method="MSAC", DistanceThreshold=1.5, NumTrials=3000);
    if nnz(inl) < 15, continue; end
    m = m(inl, :);
    m1{end+1} = [pu{i}(m(:, 1), :) ones(size(m, 1), 1)]; %#ok<AGROW>
    m2{end+1} = [pu{j}(m(:, 2), :) ones(size(m, 1), 1)]; %#ok<AGROW>
    usados(end+1, :) = [i j]; %#ok<AGROW>
end
end

function r = sampson(x, rig, T, pares, m1, m2, Kinv)
rig.thetaReal = x(1:end-1); rig.sphi = x(end);
nv = height(T);
A = cell(nv, 1);
for k = unique(pares(:))'
    A{k} = poseEscaner(rig, T.phi(k), T.theta(k));
end
r = cell(size(pares, 1), 1);
delta = 1.5;                                    % px: hasta aquí cuadrático, después lineal (Huber)
for q = 1:size(pares, 1)
    M = A{pares(q, 2)} / A{pares(q, 1)};
    t = M(1:3, 4);
    F = Kinv' * [0 -t(3) t(2); t(3) 0 -t(1); -t(2) t(1) 0] * M(1:3, 1:3) * Kinv;
    Fx1 = m1{q} * F'; Ftx2 = m2{q} * F;
    d = sum(m2{q} .* Fx1, 2) ./ sqrt(Fx1(:, 1).^2 + Fx1(:, 2).^2 + Ftx2(:, 1).^2 + Ftx2(:, 2).^2);
    a = abs(d);
    h = d; h(a > delta) = sign(d(a > delta)) .* sqrt(2*delta*a(a > delta) - delta^2);
    r{q} = h;
end
r = vertcat(r{:});
end
