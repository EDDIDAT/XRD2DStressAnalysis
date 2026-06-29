function y = multiPseudoVoigt(p, xdata)
% p = [A1, mu1, fwhm1, eta1,  A2, mu2, fwhm2, eta2, ...]
nPeaks = numel(p) / 4;
y      = zeros(size(xdata));
for i = 1:nPeaks
    A    = p(4*(i-1)+1);
    mu   = p(4*(i-1)+2);
    fwhm = p(4*(i-1)+3);
    eta  = p(4*(i-1)+4);
    y    = y + A .* ( ...
        eta    .* (1 ./ (1 + ((xdata - mu)./(fwhm/2)).^2)) + ...
        (1-eta).* exp(-log(2) .* ((xdata - mu)./(fwhm/2)).^2));
end