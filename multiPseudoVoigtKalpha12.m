function Y = multiPseudoVoigtKalpha12(p, x)
% Pseudo-Voigt mit gekoppeltem Ga Kalpha1/Kalpha2-Dublett
% Parameter pro Peak: [Amp_total, Pos_Kalpha1, FWHM, Eta]  (4 Parameter, wie normale PV)
% Kalpha2-Position und -Amplitude werden physikalisch abgeleitet, nicht gefittet.
%
% Ga Kalpha1 = 9.25174 keV  -> lambda1 = 1.339956 Angstrom
% Ga Kalpha2 = 9.22482 keV  -> lambda2 = 1.343984 Angstrom
% (Quelle: Standardtabellenwerte Roentgenemissionslinien)

lambda1_ang = 1.340121;
lambda2_ang = 1.344037;
ratio_I     = 0.52;     % I(Kalpha2)/I(Kalpha1)

nPeaks = numel(p) / 4;
Y = zeros(size(x));

for k = 1:nPeaks
    A    = p(4*(k-1)+1);
    pos1 = p(4*(k-1)+2);   % gefittete Position = Kalpha1-Position
    fwhm = p(4*(k-1)+3);
    eta  = p(4*(k-1)+4);

    % Kalpha2-Position aus Bragg-Gesetz ableiten:
    % sin(theta2) = (lambda2/lambda1) * sin(theta1)
    theta1    = deg2rad(pos1/2);
    sinTheta2 = (lambda2_ang/lambda1_ang) * sin(theta1);
    sinTheta2 = min(max(sinTheta2, -1), 1);   % numerische Absicherung
    theta2    = asin(sinTheta2);
    pos2      = 2*rad2deg(theta2);

    A1 = A / (1+ratio_I);            % Kalpha1-Anteil
    A2 = A * ratio_I / (1+ratio_I);  % Kalpha2-Anteil

    Y = Y + localPV(A1, pos1, fwhm, eta, x) + localPV(A2, pos2, fwhm, eta, x);
end
end

function y = localPV(A, x0, fwhm, eta, x)
sigma = fwhm / (2*sqrt(2*log(2)));
gamma = fwhm / 2;
G = exp(-((x-x0).^2)/(2*sigma^2));
L = gamma^2 ./ ((x-x0).^2 + gamma^2);
y = A * (eta*L + (1-eta)*G);
end