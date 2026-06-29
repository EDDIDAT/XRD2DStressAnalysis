function [params, errors, fitResult] = fitCentroid(x, y, x0_init, opts)
% FITCENTROID  Schwerpunkt-basierte Peaklagen-Bestimmung mit Fehlerberechnung.
%
% Berechnet die Peaklage über den gewichteten Schwerpunkt (Centroid) der
% Intensitätsverteilung in einem ROI-Fenster um den Peak.
% Fehlerberechnung erfolgt via Bootstrap-Resampling.
%
% Analog zu fitPseudoVoigt – gleiche Ausgabe-Struktur für direkten Austausch.
%
% EINGABE:
%   x        - x-Daten (Vektor, z.B. 2theta in °)
%   y        - y-Daten (Vektor, Intensität)
%   x0_init  - Startwert / Näherung der Peaklage (wird für ROI verwendet)
%   opts     - (optional) Struktur mit Optionen:
%              .kBins        – Halbbreite der ROI in Datenpunkten (default: 8)
%              .baselineMode – 'minval' | 'linear' | 'none' (default: 'minval')
%              .nBootstrap   – Anzahl Bootstrap-Iterationen (default: 200)
%              .smoothPoints – Glättung vor Centroid (default: 1 = keine)
%              .verbose      – true/false Konsolenausgabe (default: true)
%
% AUSGABE:
%   params   - Struktur mit Ergebnissen:
%              .x0      – Centroid-Peaklage [°]
%              .amp     – Peakamplitude (max(y_roi - baseline))
%              .width   – effektive Breite = Σw / max(w) * dx  [°]
%              .offset  – Baseline-Niveau
%   errors   - Struktur mit 1-sigma Fehlern (Bootstrap):
%              .x0      – Standardabweichung der Centroid-Position
%              .amp     – Standardabweichung der Amplitude
%              .width   – Standardabweichung der effektiven Breite
%              .offset  – Standardabweichung des Offsets
%   fitResult - y-Werte der rekonstruierten Centroid-Kurve (Dreieck-Approx.)
%               auf dem x-Gitter (für Plot-Kompatibilität mit fitPseudoVoigt)
%
% BEISPIEL:
%   [p, e, yfit] = fitCentroid(x, y, 30.5);
%   fprintf('x0 = %.4f ± %.4f °\n', p.x0, e.x0);

% =====================================================================
% Defaults
% =====================================================================
if nargin < 4 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, 'kBins'),        opts.kBins        = 18;        end
if ~isfield(opts, 'baselineMode'), opts.baselineMode = 'minval'; end
if ~isfield(opts, 'nBootstrap'),   opts.nBootstrap   = 200;      end
if ~isfield(opts, 'smoothPoints'), opts.smoothPoints = 1;        end
if ~isfield(opts, 'verbose'),      opts.verbose      = true;     end

x = x(:);
y = y(:);

if numel(x) ~= numel(y)
    error('fitCentroid: x und y müssen gleich lang sein.');
end
if numel(x) < 5
    error('fitCentroid: Zu wenige Datenpunkte (mind. 5 nötig).');
end

% =====================================================================
% Glättung (optional)
% =====================================================================
if opts.smoothPoints > 1
    y_proc = movmean(y, opts.smoothPoints);
else
    y_proc = y;
end

% =====================================================================
% ROI bestimmen
% =====================================================================
[~, iMax_global] = max(y_proc);
[~, iGuess]      = min(abs(x - x0_init));

% Suche echtes Maximum in einem großzügigen Fenster um den Guess
searchHalf = opts.kBins * 3;   % 3x kBins als Suchbereich
lo_search  = max(1, iGuess - searchHalf);
hi_search  = min(numel(x), iGuess + searchHalf);

[~, iMaxLocal] = max(y_proc(lo_search:hi_search));
iMaxLocal      = lo_search + iMaxLocal - 1;

% Wenn lokales Maximum nahe genug am Guess → verwenden
% sonst globales Maximum als Fallback
distLocal  = abs(x(iMaxLocal)  - x0_init);
distGlobal = abs(x(iMax_global) - x0_init);

if distLocal <= distGlobal
    iCenter = iMaxLocal;
else
    iCenter = iMax_global;
end

lo = max(1,          iCenter - opts.kBins);
hi = min(numel(x),   iCenter + opts.kBins);

x_roi = x(lo:hi);
y_roi = y_proc(lo:hi);

if numel(x_roi) < 3
    error('fitCentroid: ROI zu schmal. kBins erhöhen oder x0_init anpassen.');
end

% =====================================================================
% Centroid auf den ROI-Daten berechnen
% =====================================================================
[x0, amp, width, offset] = computeCentroid(x_roi, y_roi, opts.baselineMode);

params.x0     = x0;
params.amp    = amp;
params.width  = width;
params.offset = offset;

% =====================================================================
% Fehlerberechnung via Bootstrap
% =====================================================================
n      = numel(x_roi);
bsX0     = zeros(opts.nBootstrap, 1);
bsAmp    = zeros(opts.nBootstrap, 1);
bsWidth  = zeros(opts.nBootstrap, 1);
bsOffset = zeros(opts.nBootstrap, 1);

for b = 1:opts.nBootstrap
    % Resample mit Zurücklegen
    idx_bs = randi(n, n, 1);
    x_bs   = x_roi(idx_bs);
    y_bs   = y_roi(idx_bs);

    % Sortieren (Centroid braucht keine Sortierung, aber für Konsistenz)
    [x_bs, sortIdx] = sort(x_bs);
    y_bs = y_bs(sortIdx);

    try
        [bsX0(b), bsAmp(b), bsWidth(b), bsOffset(b)] = ...
            computeCentroid(x_bs, y_bs, opts.baselineMode);
    catch
        bsX0(b)     = x0;
        bsAmp(b)    = amp;
        bsWidth(b)  = width;
        bsOffset(b) = offset;
    end
end

errors.x0     = std(bsX0);
errors.amp    = std(bsAmp);
errors.width  = std(bsWidth);
errors.offset = std(bsOffset);

% =====================================================================
% fitResult: Dreieck-Approximation auf vollem x-Gitter
% Kompatibel mit fitPseudoVoigt-Ausgabe für Plot
% =====================================================================
% Gaussian-Näherung mit amp, x0, width als sigma
sigma    = width / (2 * sqrt(2 * log(2)));   % FWHM → sigma
if sigma <= 0, sigma = (max(x) - min(x)) / 20; end
fitResult = amp .* exp(-0.5 .* ((x - x0) ./ sigma).^2) + offset;

% =====================================================================
% Konsolenausgabe
% =====================================================================
r2 = rsquared(y, fitResult);

if opts.verbose
    fprintf('\n===== Centroid Fit Ergebnisse =====\n');
    fprintf('  Peaklage  x0 : %.4f  ± %.4f\n', params.x0,     errors.x0);
    fprintf('  Amplitude  A : %.4f  ± %.4f\n', params.amp,    errors.amp);
    fprintf('  Eff. Breite  : %.4f  ± %.4f\n', params.width,  errors.width);
    fprintf('  Offset       : %.4f  ± %.4f\n', params.offset, errors.offset);
    fprintf('  R² (approx.) : %.6f\n', r2);
    fprintf('===================================\n\n');
end

end % fitCentroid


% =========================================================================
% Lokale Hilfsfunktion: Centroid berechnen
% =========================================================================
function [x0, amp, width, offset] = computeCentroid(x, y, baselineMode)

switch lower(baselineMode)
    case 'minval'
        baseline = min(y);
        w = max(y - baseline, 0);

    case 'linear'
        % Lineare Baseline zwischen erstem und letztem Punkt
        baseline_vec = linspace(y(1), y(end), numel(y))';
        w = max(y - baseline_vec, 0);
        baseline = mean(baseline_vec);

    case 'none'
        w = max(y, 0);
        baseline = 0;

    otherwise
        baseline = min(y);
        w = max(y - baseline, 0);
end

if sum(w) <= 0
    % Fallback: Maximum-Position
    [~, iMax] = max(y);
    x0 = x(iMax);
    amp = max(y) - min(y);
    width = (max(x) - min(x)) / 4;
    offset = min(y);
    return
end

% Schwerpunkt
x0 = sum(x .* w) / sum(w);

% Amplitude
amp = max(w);

% Effektive Breite: Σw / max(w) * mittlerer Punktabstand
dx    = mean(diff(x));
if dx <= 0, dx = (max(x) - min(x)) / max(numel(x)-1, 1); end
width = (sum(w) / max(w)) * dx;

% Offset
offset = baseline;

end


% =========================================================================
% Lokale Hilfsfunktion: R²
% =========================================================================
function r2 = rsquared(y, yhat)
y    = y(:);
yhat = yhat(:);
ssr  = sum((y - yhat).^2);
sst  = sum((y - mean(y)).^2);
if sst <= 0
    r2 = NaN;
else
    r2 = 1 - ssr / sst;
end
end