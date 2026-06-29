function inspect_peak_snr_click(res, methodName)
%INSPECT_PEAK_SNR_CLICK
% Interaktive Inspektion eines einzelnen Peaks:
% SNR-Plot -> Klick auf Punkt -> zugehöriger Fit / Peaklage anzeigen
%
% INPUT
%   res        : Ergebnis von pyfai_peak_tracking_compare_methods(...)
%   methodName : "centroid" | "gauss" | "pvoigt"
%
% BEISPIEL
%   inspect_peak_snr_click(res, "pvoigt")

if nargin < 2 || isempty(methodName)
    methodName = "pvoigt";
end
methodName = lower(string(methodName));

if ~isfield(res, char(methodName))
    error("Methode '%s' nicht in res vorhanden.", methodName);
end

M = res.(methodName);
g = res.gamma_deg(:);

if ~isfield(M, 'snr') || isempty(M.snr)
    error("res.%s enthält kein Feld 'snr'.", methodName);
end

snr = M.snr(:);
valid = false(size(snr));
if isfield(M, 'valid') && ~isempty(M.valid)
    valid = M.valid(:);
end

fig = figure('Name', sprintf('SNR inspection - %s', methodName), 'NumberTitle', 'off');
ax = axes(fig);
hold(ax, 'on');
grid(ax, 'on');

plot(ax, g, snr, 'k.-', 'DisplayName', 'SNR');
plot(ax, g(valid), snr(valid), 'ro', 'DisplayName', 'valid');

xlabel(ax, '\gamma / \chi (deg)');
ylabel(ax, 'SNR');
title(ax, sprintf('SNR für Methode: %s | Klick auf einen Punkt | ENTER beendet', methodName));
legend(ax, 'Location', 'best');

disp("Klick auf einen Punkt im SNR-Plot. ENTER beendet.");

while isvalid(fig)
    try
        [xClick, ~, button] = ginput(1);
    catch
        break; % z.B. Figure geschlossen
    end

    if isempty(button)
        break;
    end

    idx = nearest_index(g, xClick);

    show_selected_point(ax, g(idx), snr(idx));

    show_fit_for_index(res, idx, methodName);
end
end

% =====================================================================
% Anzeige eines ausgewählten Punkts
% =====================================================================

function show_selected_point(ax, x, y)
delete(findobj(ax, 'Tag', 'selected_snr_point'));
plot(ax, x, y, 'ms', 'MarkerSize', 10, 'LineWidth', 1.5, 'Tag', 'selected_snr_point');
drawnow;
end

% =====================================================================
% Fit / Peaklage für den gewählten Index anzeigen
% =====================================================================

function show_fit_for_index(res, idx, methodName)
M = res.(methodName);
fs = res.fitStore(idx);
gammaVal = res.gamma_deg(idx);

if isempty(fs.r) || isempty(fs.yproc)
    fprintf('\nIndex %d | gamma = %.3f°\n', idx, gammaVal);
    fprintf('Kein gespeichertes Fitprofil vorhanden.\n');
    return;
end

fig2 = figure('Name', sprintf('Fit inspection - %s - idx %d', methodName, idx), 'NumberTitle', 'off');
ax2 = axes(fig2);
hold(ax2, 'on');
grid(ax2, 'on');

plot(ax2, fs.r, fs.yproc, 'k.-', 'DisplayName', 'processed profile');

peakPos = nan;
peakErr = nan;
R2 = nan;
valid = false;
usedFallback = false;

switch methodName
    case "centroid"
        valid = get_logical_field(fs, 'valid_centroid');
        peakPos = get_numeric_field(M, 'tth_peak_deg', idx);
        peakErr = get_numeric_field(M, 'tth_peak_err_deg', idx);

        if valid && isfinite(fs.x_centroid)
            xline(ax2, fs.x_centroid, 'r-', 'LineWidth', 1.5, 'DisplayName', 'centroid');
        end

    case "gauss"
        valid = get_logical_field(fs, 'valid_gauss');
        peakPos = get_numeric_field(M, 'tth_peak_deg', idx);
        peakErr = get_numeric_field(M, 'tth_peak_err_deg', idx);
        R2 = get_numeric_field(M, 'R2', idx);

        if valid && ~isempty(fs.yfit_gauss)
            plot(ax2, fs.r, fs.yfit_gauss, 'r-', 'LineWidth', 1.5, 'DisplayName', 'gauss fit');
        end
        if valid && isfinite(fs.x_gauss)
            xline(ax2, fs.x_gauss, 'b-', 'LineWidth', 1.5, 'DisplayName', 'gauss center');
        end

    case "pvoigt"
        valid = get_logical_field(fs, 'valid_pvoigt');
        peakPos = get_numeric_field(M, 'tth_peak_deg', idx);
        peakErr = get_numeric_field(M, 'tth_peak_err_deg', idx);
        R2 = get_numeric_field(M, 'R2', idx);
        usedFallback = get_numeric_field(M, 'usedFallback', idx);

        if valid && ~fs.usedPvoigtFallback && ~isempty(fs.yfit_pvoigt)
            plot(ax2, fs.r, fs.yfit_pvoigt, 'r-', 'LineWidth', 1.5, 'DisplayName', 'pVoigt fit');
        end
        if valid && isfinite(fs.x_pvoigt)
            xline(ax2, fs.x_pvoigt, 'b-', 'LineWidth', 1.5, 'DisplayName', 'pVoigt center');
        end

    otherwise
        error("Unbekannte Methode: %s", methodName);
end

xlabel(ax2, '2\theta');
ylabel(ax2, 'Intensity');
title(ax2, sprintf('%s | \\chi = %.3f° | index = %d', methodName, gammaVal, idx));
legend(ax2, 'Location', 'best');

% ---- Ausgabe im Command Window
fprintf('\n----------------------------------------\n');
fprintf('Methode: %s\n', methodName);
fprintf('Index:   %d\n', idx);
fprintf('Gamma:   %.6f deg\n', gammaVal);

snrVal = get_numeric_field(M, 'snr', idx);
noiseVal = get_numeric_field(M, 'noise', idx);
ampVal = get_numeric_field(M, 'amp', idx);
fwhmVal = get_numeric_field(M, 'fwhm', idx);

fprintf('Valid:   %d\n', logical(valid));
fprintf('SNR:     %.6g\n', snrVal);
fprintf('Noise:   %.6g\n', noiseVal);
fprintf('Amp:     %.6g\n', ampVal);
fprintf('Peak:    %.6f deg\n', peakPos);
fprintf('Err:     %.6g deg\n', peakErr);

if isfinite(fwhmVal)
    fprintf('FWHM:    %.6g deg\n', fwhmVal);
end
if isfinite(R2)
    fprintf('R2:      %.6g\n', R2);
end
if methodName == "pvoigt"
    fprintf('Fallback centroid: %d\n', logical(usedFallback));
end
fprintf('----------------------------------------\n');
end

% =====================================================================
% helper
% =====================================================================

function idx = nearest_index(x, xq)
x = x(:);
[~, idx] = min(abs(x - xq));
end

function v = get_numeric_field(S, fieldName, idx)
v = nan;
if isfield(S, fieldName) && ~isempty(S.(fieldName))
    arr = S.(fieldName);
    if numel(arr) >= idx
        v = arr(idx);
    end
end
end

function v = get_logical_field(S, fieldName)
v = false;
if isfield(S, fieldName) && ~isempty(S.(fieldName))
    v = logical(S.(fieldName));
end
end