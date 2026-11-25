function mask = mascaraObjeto(I, umbral)
%MASCARAOBJETO Máscara binaria de todo lo que NO es verde (figura + plastilina + poste).
%   mask = mascaraObjeto(I)          umbral automático = 0.6 * mediana del exceso de verde
%   mask = mascaraObjeto(I, 0.06)    umbral fijo: súbelo si se pierde plastilina/sombras del objeto,
%                                    bájalo si entra fondo verde oscuro
%
%   Exceso de verde = G - max(R,B). Fondo (verde) ~0.10, su cola baja ~0.06;
%   plastilina negra ~0.02, figura y poste <= 0. La mediana es fondo porque el objeto
%   ocupa poco de la foto, así que el umbral se adapta a la luz de cada anillo.
arguments
    I
    umbral (1,1) double = NaN
end
I = im2double(I);
ex = I(:,:,2) - max(I(:,:,1), I(:,:,3));
if isnan(umbral)
    umbral = 0.6*median(ex(:));   % 0.4 pierde poste blanco/borde de plastilina, 0.75 ya mete fondo
    % ponytail: Otsu partía figura vs plastilina; esto parte objeto vs fondo
end
mask = ex < umbral;

r = max(1, round(min(size(mask))/300));            % escala la limpieza con la resolución
mask = imopen(mask, strel("disk", r));             % ruido suelto
mask = imclearborder(mask);                        % marco del escáner, cables, cosas en la orilla
cc = regionprops("table", mask, "Area");           % lo que gira = mancha grande (+ piezas
mask = bwareaopen(mask, round(0.1*max([cc.Area; 0])));  %  que se vean separadas, p. ej. una cola)
mask = ~bwareaopen(~mask, 20*r^2);                 % tapa huecos diminutos (brillos), NO los reales
% ponytail: sin imfill("holes"): el hueco entre cola y lomo es fondo real y el visual hull lo necesita
end
