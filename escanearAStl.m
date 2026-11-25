function archivoStl = escanearAStl(carpeta, carpetaCalib, opts)
%ESCANEARASTL Visual hull de un escaneo OpenScan (fondo verde) -> STL en mm.
%   escanearAStl("scan_20261125_0054", "scan_20261125_0048")
%   escanearAStl(..., ResolucionMm=0.2, Tolerancia=1, Escala=0.5)
%
%   carpeta      : escaneo de la figura (img_###.jpg + poses.csv de captura.m)
%   carpetaCalib : escaneo del tablero ya procesado con calibrarEscaner (tiene calib.mat)
%   Opciones:
%     ResolucionMm : tamaño de voxel final (default 0.25). Menor = más detalle y más lento.
%     Tolerancia   : # de vistas que pueden "no ver" un voxel sin borrarlo (default 1).
%                    Súbela si al modelo le faltan pedazos finos (cola, patas).
%     Escala       : escala de las máscaras (default 0.5 de la foto original).
%     Umbral       : umbral fijo para mascaraObjeto (default: automático).
%     Vistas       : ids de fotos a usar (default: todas). Sirve para excluir fotos malas.
%     RefinarRotor : true (default) corrige los ángulos reales del rotor con la textura de
%                    la figura (refinarRotor) y lo guarda en <carpeta>/rig_refinado.mat;
%                    si ya existe se reutiliza (bórralo para recalcular).
%   Salida: <carpeta>/<carpeta>.stl  y  <carpeta>/vista_stl.png
%
%   Método: cada voxel se proyecta a todas las fotos con la pose calibrada (phi, theta);
%   si cae en fondo verde (o fuera de la foto) en más de Tolerancia vistas, se borra.
%   ponytail: visual hull no ve concavidades que ninguna silueta muestre (p. ej. el
%   interior de una oreja); para eso está el paso SfM/MVS cuando haga falta.
arguments
    carpeta (1,1) string
    carpetaCalib (1,1) string
    opts.ResolucionMm (1,1) double {mustBePositive} = 0.25
    opts.Tolerancia (1,1) double {mustBeInteger, mustBeNonnegative} = 1
    opts.Escala (1,1) double {mustBePositive} = 0.5
    opts.Umbral (1,1) double = NaN
    opts.Vistas double = []
    opts.RefinarRotor (1,1) logical = true
end
cal = load(fullfile(carpetaCalib, "calib.mat"));
T = readtable(fullfile(carpeta, "poses.csv"));
if opts.RefinarRotor                             % el rotor pierde pasos: cada escaneo tiene sus ángulos
    archRig = fullfile(carpeta, "rig_refinado.mat");
    if ~isfile(archRig)
        rig = refinarRotor(carpeta, cal, T);     % con todas las fotos, antes de filtrar Vistas
        save(archRig, "rig");
    end
    cal.rig = load(archRig).rig;
    if isfield(cal.rig, "dphi"), T.phi = T.phi + cal.rig.dphi; end   % ángulo real de la mesa por foto
end
if ~isempty(opts.Vistas), T = T(ismember(T.id, opts.Vistas), :); end
n = height(T);

% --- máscaras ---
fprintf("Máscaras de %d fotos...\n", n);
masks = cell(n, 1); A = cell(n, 1);
for k = 1:n
    I = imread(fullfile(carpeta, sprintf("img_%03d.jpg", T.id(k))));
    masks{k} = mascaraObjeto(imresize(I, opts.Escala), opts.Umbral);
    A{k} = rigidtform3d(poseEscaner(cal.rig, T.phi(k), T.theta(k)));
end
tamFoto = size(I, [1 2]);

% --- pasada gruesa en una caja grande alrededor del eje de la mesa ---
zc = cal.rig.W(1:3, 4);                         % origen del marco objeto (en cámara)
mitad = 1.1 * norm(zc) * max(tamFoto) / (2*cal.intrinsics.FocalLength(1));   % mm visibles a esa distancia
g = -mitad:2:mitad;
[X, Y, Z] = meshgrid(g, g, g);
vivo = tallar([X(:) Y(:) Z(:)], masks, A, cal.intrinsics, opts, tamFoto);
assert(any(vivo), "La pasada gruesa borró todo: revisa la calibración (¿se movió el celular?).");
P = [X(vivo) Y(vivo) Z(vivo)];
lo = min(P, [], 1) - 12; hi = max(P, [], 1) + 12; % margen amplio: partes finas (cola) mueren en la pasada gruesa de 2 mm

% --- pasada fina ---
r = opts.ResolucionMm;
xv = lo(1):r:hi(1); yv = lo(2):r:hi(2); zv = lo(3):r:hi(3);
fprintf("Pasada fina: %dx%dx%d voxeles de %.2f mm...\n", numel(xv), numel(yv), numel(zv), r);
[X, Y, Z] = meshgrid(single(xv), single(yv), single(zv));
[vivo, recall] = tallar([X(:) Y(:) Z(:)], masks, A, cal.intrinsics, opts, tamFoto);
clear X Y Z
V = reshape(vivo, numel(yv), numel(xv), numel(zv));
V = bwareafilt3(V);                              % un solo sólido
fprintf("Silueta explicada por el modelo: media %.1f%%, peor %.1f%% (foto %d)\n", ...
    100*mean(recall), 100*min(recall), find(recall == min(recall), 1));

% --- malla ---
V = padarray(V, [1 1 1]);                        % cerrada (watertight)
xv = [xv(1)-r xv xv(end)+r]; yv = [yv(1)-r yv yv(end)+r]; zv = [zv(1)-r zv zv(end)+r];
fv = isosurface(xv, yv, zv, smooth3(single(V), "gaussian", 3), 0.5);
TR = triangulation(fv.faces, double(fv.vertices));
[~, nombre] = fileparts(carpeta);
archivoStl = fullfile(carpeta, nombre + ".stl");
stlwrite(TR, archivoStl);
bb = max(fv.vertices) - min(fv.vertices);
fprintf("STL: %s  (%d triángulos, %.1f x %.1f x %.1f mm)\n", archivoStl, size(fv.faces, 1), bb);

f = figure(Visible="off", Color="w");
trisurf(TR, EdgeColor="none", FaceColor=[0.85 0.55 0.35]);
axis equal; camlight headlight; lighting gouraud; view(35, 20); xlabel x; ylabel y; zlabel z
exportgraphics(f, fullfile(carpeta, "vista_stl.png"), Resolution=150); close(f);
end

function bloque = bwareafilt3(V)
cc = bwconncomp(V, 26);
[~, i] = max(cellfun(@numel, cc.PixelIdxList));
bloque = false(size(V)); bloque(cc.PixelIdxList{i}) = true;
end

function [vivo, recall] = tallar(P, masks, A, intr, opts, tamFoto)
% Proyecta los voxeles a cada vista y cuenta fallas (fondo o fuera de foto).
n = numel(masks);
fallas = zeros(size(P, 1), 1, "uint8");
idx = (1:size(P, 1))';                           % voxeles aún vivos
for k = 1:n
    uv = worldToImage(intr, A{k}, P(idx, :));
    [dentro, lin] = aPixel(uv, opts.Escala, size(masks{k}), tamFoto);
    ok = false(numel(idx), 1); ok(dentro) = masks{k}(lin);
    fallas(idx(~ok)) = fallas(idx(~ok)) + 1;
    idx = idx(fallas(idx) <= opts.Tolerancia);   % ponytail: tallado progresivo, cada vista proyecta menos
end
vivo = false(size(P, 1), 1); vivo(idx) = true;

if nargout > 1                                   % cuánto de cada silueta cubre el modelo final
    recall = zeros(n, 1);
    for k = 1:n
        uv = worldToImage(intr, A{k}, P(idx, :));
        [dentro, lin] = aPixel(uv, opts.Escala, size(masks{k}), tamFoto);
        hit = false(size(masks{k})); hit(lin) = true;
        hit = imclose(hit, strel("disk", 2));
        recall(k) = nnz(hit & masks{k}) / nnz(masks{k});
    end
end
end

function [dentro, lin] = aPixel(uv, s, tamMask, tamFoto)
u = round((uv(:, 1) - 0.5)*s + 0.5); v = round((uv(:, 2) - 0.5)*s + 0.5);
dentro = find(uv(:,1) >= 0.5 & uv(:,1) <= tamFoto(2) + 0.5 & uv(:,2) >= 0.5 & uv(:,2) <= tamFoto(1) + 0.5 ...
    & u >= 1 & u <= tamMask(2) & v >= 1 & v <= tamMask(1));
lin = sub2ind(tamMask, v(dentro), u(dentro));
end
