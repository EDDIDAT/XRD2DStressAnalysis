function Y = multiPseudoVoigtAsym(p, x)
% Split-Pseudo-Voigt: asymmetrische Peakform
% Parameter pro Peak: [Amplitude, Position, FWHM_L, FWHM_R, Eta]
nPeaks = numel(p) / 5;
Y = zeros(size(x));
for k = 1:nPeaks
    A    = p(5*(k-1)+1);
    x0   = p(5*(k-1)+2);
    fL   = p(5*(k-1)+3);  % FWHM linke Flanke
    fR   = p(5*(k-1)+4);  % FWHM rechte Flanke
    eta  = p(5*(k-1)+5);  % 0=Gauss, 1=Lorentz

    sigL = fL / (2*sqrt(2*log(2)));
    sigR = fR / (2*sqrt(2*log(2)));
    gL   = fL / 2;
    gR   = fR / 2;

    leftIdx  = x <= x0;
    rightIdx = x >  x0;

    G = zeros(size(x));
    L = zeros(size(x));

    G(leftIdx)  = exp(-((x(leftIdx)  - x0).^2) / (2*sigL^2));
    G(rightIdx) = exp(-((x(rightIdx) - x0).^2) / (2*sigR^2));

    L(leftIdx)  = gL^2 ./ ((x(leftIdx)  - x0).^2 + gL^2);
    L(rightIdx) = gR^2 ./ ((x(rightIdx) - x0).^2 + gR^2);

    Y = Y + A * (eta*L + (1-eta)*G);
end
end