function [params, yfit, paramStats] = fitGaussiansWithBootstrap(x, y, peakPositions, bgOrder, nBootstrap, plotFit)
% FITGAUSSIANSWITHBOOTSTRAP Fit Gaussian peaks + nonlinear background
% mit Bootstrap-Konfidenzen für die Fitparameter
%
% Inputs:
%   x, y           : Daten
%   peakPositions  : Vektor der vorgegebenen Peak-Positionen
%   bgOrder        : Ordnung des polynomiellen Untergrunds
%   nBootstrap     : Anzahl der Bootstrap-Durchläufe
%   plotFit        : optional, true/false (default: true)
%
% Outputs:
%   params         : Fitparameter aus Originaldaten
%   yfit           : Fitkurve
%   paramStats     : Struktur mit:
%                     .mean  : Mittelwert jedes Parameters
%                     .std   : Standardabweichung
%                     .CI    : 2.5%-97.5% Konfidenzintervall

if nargin < 6, plotFit = true; end
if nargin < 5, nBootstrap = 100; end

x = x(:); y = y(:);
numPeaks = length(peakPositions);

% --- Original Fit ---
[params, yfit] = fitGaussiansWithNonlinearBackground_NoPlot(x, y, peakPositions, bgOrder);

% --- Bootstrap ---
paramMatrix = zeros(nBootstrap, length(params));

N = length(x);
for i = 1:nBootstrap
    idx = randi(N, N, 1); % Stichprobe mit Zurücklegen
    x_bs = x(idx);
    y_bs = y(idx);
    try
        p_bs = fitGaussiansWithNonlinearBackground_NoPlot(x_bs, y_bs, peakPositions, bgOrder);
        paramMatrix(i,:) = p_bs;
    catch
        paramMatrix(i,:) = NaN; % Bei Konvergenzproblemen
    end
end

% --- Statistik ---
paramStats.mean = nanmean(paramMatrix);
paramStats.std  = nanstd(paramMatrix);
paramStats.CI   = prctile(paramMatrix, [2.5 97.5]);

% --- Plot Original Fit + Bootstrap Samples ---
if plotFit
    figure; hold on;
    plot(x, y, 'bo', 'MarkerSize',3);
    plot(x, yfit, 'r-', 'LineWidth',1.5);
    for i = 1:min(nBootstrap,50) % max. 50 Bootstraps zeigen
        ybsfit = sumGaussiansWithPolyBG(x, paramMatrix(i,:), peakPositions, bgOrder);
        plot(x, ybsfit, 'Color',[0.7 0.7 0.7 0.3]); % leicht transparent
    end
    xlabel('x'); ylabel('y');
    title('Gaussian Fit with Polynomial Background + Bootstrap');
    legend('Data','Original Fit','Bootstrap Samples');
    grid on;
end

end

%% --- Hilfsfunktion: Original Fit ohne Plot ---
function [params, yfit] = fitGaussiansWithNonlinearBackground_NoPlot(x, y, peakPositions, bgOrder)
% Nur Fit ohne Plot
x = x(:); y = y(:);
numPeaks = length(peakPositions);

% Initialwerte
a0 = y(round(interp1(x,1:length(x),peakPositions))) - mean(y);
c0 = repmat((max(x)-min(x))/20, size(a0));
bg0 = polyfit(x, y, bgOrder);
bg0 = fliplr(bg0);

init = [a0(:); c0(:); bg0'];

% Modell & Residuen
model = @(p,xdata) sumGaussiansWithPolyBG(xdata, p, peakPositions, bgOrder);
resid = @(p) sum((y - model(p,x)).^2);

% Fit
opts = optimset('Display','off');
params = fminsearch(resid, init, opts);
yfit = model(params, x);
end