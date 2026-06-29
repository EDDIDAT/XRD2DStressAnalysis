function [params, yfit] = fitGaussianWithBackground_NoCFT(x, y, plotFit)
% FITGAUSSIANWITHBACKGROUND_NOCFT Fit Gaussian peaks with variable background
% ohne Curve Fitting Toolbox (nur MATLAB-Bordfunktionen)
%
%   [params, yfit] = fitGaussianWithBackground_NoCFT(x, y)
%   x, y         : Daten
%   plotFit      : optional, true/false (default: true)
%
%   Outputs:
%       params : [a, b, c, d, e] -> amplitude, peak pos, sigma, linear bg slope, intercept
%       yfit   : gefittete Werte

if nargin < 3
    plotFit = true;
end

x = x(:); y = y(:); % Spaltenvektoren

% --- Initialwerte ---
[~, imax] = max(y);
a0 = y(imax) - mean(y);
b0 = x(imax);
c0 = (max(x)-min(x))/10;
p_bg = polyfit(x, y, 1);
d0 = p_bg(1);
e0 = p_bg(2);

init = [a0, b0, c0, d0, e0];

% --- Gauss + linear background ---
gauss_bg = @(p,x) p(1)*exp(-(x-p(2)).^2/(2*p(3)^2)) + p(4)*x + p(5);

% --- Residuen ---
resid = @(p) sum((y - gauss_bg(p,x)).^2);

% --- Minimierung ---
opts = optimset('Display','off'); % keine Ausgabe
params = fminsearch(resid, init, opts);

% --- Gefittete Werte ---
yfit = gauss_bg(params, x);

% --- Plot ---
if plotFit
    figure;
    plot(x, y, 'bo'); hold on;
    plot(x, yfit, 'r-', 'LineWidth',1.5);
    xlabel('x'); ylabel('y');
    title('Gaussian Fit with Linear Background (No Curve Fitting Toolbox)');
    legend('Data','Fit');
    grid on;
end

end