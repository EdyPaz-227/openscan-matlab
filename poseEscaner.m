function A = poseEscaner(rig, phi, theta)
%POSEESCANER Matriz 4x4 objeto -> cámara para la pose (phi, theta) del OpenScan Classic.
%   A = poseEscaner(rig, phi, theta)    rig viene de calibrarEscaner (calib.mat)
%   Modelo físico: el objeto gira con la mesa (eje at, punto pt) y la mesa gira con el
%   rotor (eje ar, punto pr). Ambos ejes en coordenadas de cámara con phi = theta = 0.
%   sphi corrige pasos-por-grado de la mesa (ideal: 1). El rotor no es lineal (holgura/
%   carga: pedir 40° da ~27°), así que se usa el ángulo real medido por anillo
%   (rig.thetaNom -> rig.thetaReal), interpolado para thetas que no estaban en la calibración.
%   El "marco objeto" es el de rig.W (z = eje de la mesa, en mm).
thR = interp1(rig.thetaNom, rig.thetaReal, theta, "linear", "extrap");
A = girar(rig.ar, rig.pr, thR) * girar(rig.at, rig.pt, rig.sphi*phi) * rig.W;
end

function M = girar(a, p, ang)
R = axang2rotm([a(:)'/norm(a) deg2rad(ang)]);
M = [R, p(:) - R*p(:); 0 0 0 1];
end
