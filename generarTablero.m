function generarTablero(archivo, filas, cols, ladoMm)
%GENERARTABLERO PDF tamaño carta con un tablero de ajedrez a escala real.
%   generarTablero()                              -> tablero_7x8_5mm.pdf
%   generarTablero("t.pdf", 7, 8, 5)              filas x cols cuadros de ladoMm
%   Un lado par y otro impar (detectCheckerboardPoints necesita eso para saber la orientación).
%   Imprime al 100% ("tamaño real", sin "ajustar a página") y mide la regla de 50 mm.
arguments
    archivo (1,1) string = "tablero_7x8_5mm.pdf"
    filas   (1,1) double = 7
    cols    (1,1) double = 8
    ladoMm  (1,1) double = 5
end
assert(mod(filas, 2) ~= mod(cols, 2), "Un lado debe ser par y el otro impar.");

hoja = [215.9 279.4];                     % carta, mm
f = figure(Visible="off", Color="w", Units="centimeters", PaperUnits="centimeters", ...
    PaperSize=hoja/10, PaperPosition=[0 0 hoja/10]);
ax = axes(f, Units="normalized", Position=[0 0 1 1]);
axis(ax, [0 hoja(1) 0 hoja(2)]); axis(ax, "off"); hold(ax, "on");

% 2 copias (repuesto), separadas y con margen blanco de sobra alrededor
anchoT = cols*ladoMm; altoT = filas*ladoMm;
for y0 = [hoja(2) - 60 - altoT, hoja(2) - 140 - altoT]
    x0 = (hoja(1) - anchoT)/2;
    for i = 0:filas-1
        for j = 0:cols-1
            if mod(i + j, 2) == 0
                rectangle(ax, Position=[x0 + j*ladoMm, y0 + i*ladoMm, ladoMm, ladoMm], ...
                    FaceColor="k", EdgeColor="none");
            end
        end
    end
end

% regla de verificación de escala
plot(ax, [30 80], [40 40], "k", LineWidth=1.5);
plot(ax, [30 30; 80 80]', [37 43; 37 43]', "k", LineWidth=1.5);
text(ax, 85, 40, "50 mm: mídela. Si no da 50 mm exactos, usa el cuadro medido con vernier.", FontSize=9);
text(ax, 30, 25, sprintf("Tablero %dx%d cuadros de %g mm. Imprimir al 100%% en papel mate, pegar en cartón rígido.", ...
    filas, cols, ladoMm), FontSize=9);

print(f, archivo, "-dpdf", "-vector");
close(f);
fprintf("Generado: %s\n", archivo);
end
