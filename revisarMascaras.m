function revisarMascaras(carpeta, varargin)
%REVISARMASCARAS Mosaico de todas las fotos con la máscara encima (magenta) para revisarla.
%   revisarMascaras("scan_20261125_0000")
%   revisarMascaras("scan_...", 0.06)      pasa el umbral fijo a mascaraObjeto
%   Guarda <carpeta>/revision_mascaras.png. Busca fotos donde falte figura o sobre fondo.
f = dir(fullfile(carpeta, "img_*.jpg"));
assert(~isempty(f), "No hay img_*.jpg en %s", carpeta);
tiles = cell(numel(f), 1);
for k = 1:numel(f)
    I = imresize(imread(fullfile(carpeta, f(k).name)), 0.25);   % ponytail: 1/4 basta para revisar
    tiles{k} = insertText(labeloverlay(I, mascaraObjeto(I, varargin{:}), ...
        Colormap=[1 0 1], Transparency=0.4), [5 5], k, FontSize=24);
end
salida = fullfile(carpeta, "revision_mascaras.png");
imwrite(imtile(tiles, GridSize=[NaN 12]), salida);
fprintf("Revisa: %s\n", salida);
end
