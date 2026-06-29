function [params, yfit] = fitGaussiansWithNonlinearBackground(x, y, peakPositions, bgOrder, plotFit)
% FITGAUSSIANSWITHNONLINEARBACKGROUND Fit Gaussian peaks with nonlinear background
%
% Inputs:
%   x, y           : Daten
%   peakPositions  : Vektor mit vorgegebenen Peak-Positionen
%   bgOrder        : Ordnung des Untergrundpolynoms (0=konstant, 1=linear, 2=quadratisch, ...)
%   plotFit        : optional, true/false (default: true)
%
% Outputs:
%   params         : Zellarray, jede Zelle = [a, b, c] für einen Peak
%   yfit           : Gesamter Fit über alle Peaks + Untergrund

if nargin < 5
    plotFit = true;
end

x = x(:); y = y(:);
numPeaks = length(peakPositions);

% --- Initialwerte ---
a0 = y(round(interp1(x,1:length(x),peakPositions))) - mean(y);
c0 = repmat(0.3, size(a0)); % Startwerte für Sigma
bg0 = polyfit(x, y, bgOrder);              % Startwerte Untergrundkoeffizienten
bg0 = fliplr(bg0); % polyfit gibt absteigend -> wir brauchen [p0 p1 ... pn]

% Parametervektor: [a1..an, c1..cn, bgParams]
params0 = [a0(:)', c0(:)', bg0];

% --- Modell ---
model = @(p, xdata) sumGaussiansWithPolyBG(xdata, p, peakPositions, bgOrder);

% --- Residuen ---
resid = @(p) sum((y - model(p,x)).^2);

% --- Fit ---
opts = optimset('Display','off');
pfit = fminsearch(resid, params0, opts);

% --- Extrahiere Parameter ---
params = cell(numPeaks,1);
for k = 1:numPeaks
    a = pfit(k);
    b = peakPositions(k);
    c = pfit(numPeaks + k);
    params{k} = [a, b, c];
end
bg_params = pfit(2*numPeaks + (1:(bgOrder+1))); % Untergrundkoeffizienten

% --- Gesamter Fit ---
yfit = model(pfit, x);

% --- Plot ---
if plotFit
    figure; hold on;
    plot(x, y, 'bo'); % Daten
    plot(x, yfit, 'r-', 'LineWidth',1.5); % Gesamtfit
    colors = lines(numPeaks);
    for k = 1:numPeaks
        a = params{k}(1);
        b = params{k}(2);
        c = params{k}(3);
        ypeak = a*exp(-(x-b).^2/(2*c^2)) + polyval(flip(bg_params), x);
        plot(x, ypeak, '--', 'Color', colors(k,:));
    end
    xlabel('x'); ylabel('y');
    title(sprintf('Gaussians with Polynomial Background (Order %d)', bgOrder));
    legend('Data','Total Fit','Individual Peaks');
    grid on;
end

end

% --- Hilfsfunktion: Summe der Peaks + polynomieller Untergrund ---
function ysum = sumGaussiansWithPolyBG(x, p, peakPositions, bgOrder)
numPeaks = length(peakPositions);
ysum = zeros(size(x));
for k = 1:numPeaks
    a = p(k);
    b = peakPositions(k);
    c = p(numPeaks + k);
    ysum = ysum + a*exp(-(x-b).^2/(2*c^2));
end
% Untergrund
bg_params = p(2*numPeaks + (1:(bgOrder+1)));
ysum = ysum + polyval(flip(bg_params), x); % flip, weil polyval absteigend erwartet
end