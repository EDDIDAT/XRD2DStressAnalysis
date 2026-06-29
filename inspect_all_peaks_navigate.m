function inspect_all_peaks_navigate(allRes, methodName)
%INSPECT_ALL_PEAKS_NAVIGATE
% Interaktive Inspektion über alle Peaks und gamma/chi-Punkte.
%
% INPUT
%   allRes     : Ergebnis von pyfai_peak_tracking_compare_methods_multi(...)
%   methodName : "centroid" | "gauss" | "pvoigt" (optional, default "pvoigt")
%
% BEDIENUNG
%   Maus links im SNR-Plot: Punkt auswählen
%   Pfeil rechts/links:     gamma-Index +/- 1
%   Pfeil hoch/runter:      gamma-Index +/- 10
%   PageUp/PageDown:        Peak -/+ 1
%   1 / 2 / 3:              centroid / gauss / pvoigt
%   Home / End:             erster / letzter gamma-Punkt
%   q oder Esc:             beenden
%
% BEISPIEL
%   inspect_all_peaks_navigate(allRes, "pvoigt")

if nargin < 2 || isempty(methodName)
    methodName = "pvoigt";
end
methodName = lower(string(methodName));

if ~isfield(allRes, 'results') || isempty(allRes.results)
    error("allRes enthält keine Ergebnisse.");
end
if ~isfield(allRes, 'peaksDeg') || isempty(allRes.peaksDeg)
    error("allRes enthält keine Peakliste.");
end

validMethods = ["centroid","gauss","pvoigt"];
if ~any(methodName == validMethods)
    error("Unbekannte Methode: %s", methodName);
end

nPeaks = numel(allRes.results);
peakIdx = 1;

while peakIdx <= nPeaks && ~has_method(allRes.results{peakIdx}, methodName)
    peakIdx = peakIdx + 1;
end
if peakIdx > nPeaks
    error("Keine Ergebnisse für Methode '%s' gefunden.", methodName);
end

res = allRes.results{peakIdx};
g = res.gamma_deg(:);
nGamma = numel(g);

M = res.(methodName);
snr = get_method_array(M, 'snr', nGamma);
valid = logical(get_method_array(M, 'valid', nGamma));

gammaIdx = find(valid, 1, 'first');
if isempty(gammaIdx)
    gammaIdx = 1;
end

fig = figure( ...
    'Name', 'All Peaks Navigator', ...
    'NumberTitle', 'off', ...
    'Color', 'w', ...
    'KeyPressFcn', @onKeyPress, ...
    'WindowButtonDownFcn', @onMouseClick);

tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
ax2 = nexttile(tl, 2);

draw_left_panel();
update_view();

disp("Navigation: Klick links | ←/→ +/-1 | ↑/↓ +/-10 | PgUp/PgDn Peak | 1/2/3 Methode | q/Esc beendet");

    function onMouseClick(~, ~)
        clickedObj = hittest(fig);
        if isempty(clickedObj) || ~isgraphics(clickedObj)
            return;
        end

        clickedAx = ancestor(clickedObj, 'axes');
        if isempty(clickedAx) || clickedAx ~= ax1
            return;
        end

        cp = ax1.CurrentPoint;
        xClick = cp(1,1);

        gammaIdx = nearest_index(g, xClick);
        gammaIdx = clamp_index(gammaIdx, numel(g));
        update_view();
    end

    function onKeyPress(~, evt)
        switch evt.Key
            case 'rightarrow'
                gammaIdx = clamp_index(gammaIdx + 1, numel(g));
                update_view();

            case 'leftarrow'
                gammaIdx = clamp_index(gammaIdx - 1, numel(g));
                update_view();

            case 'uparrow'
                gammaIdx = clamp_index(gammaIdx + 10, numel(g));
                update_view();

            case 'downarrow'
                gammaIdx = clamp_index(gammaIdx - 10, numel(g));
                update_view();

            case 'pageup'
                peakIdx = clamp_index(peakIdx - 1, nPeaks);
                switch_peak_keep_method();

            case 'pagedown'
                peakIdx = clamp_index(peakIdx + 1, nPeaks);
                switch_peak_keep_method();

            case 'home'
                gammaIdx = 1;
                update_view();

            case 'end'
                gammaIdx = numel(g);
                update_view();

            case '1'
                methodName = "centroid";
                switch_method();

            case '2'
                methodName = "gauss";
                switch_method();

            case '3'
                methodName = "pvoigt";
                switch_method();

            case {'q','escape'}
                if isvalid(fig)
                    close(fig);
                end
        end
    end

    function switch_peak_keep_method()
        resNew = allRes.results{peakIdx};

        if ~has_method(resNew, methodName)
            fallbackOrder = ["pvoigt","centroid","gauss"];
            found = false;
            for mm = fallbackOrder
                if has_method(resNew, mm)
                    methodName = mm;
                    found = true;
                    break;
                end
            end
            if ~found
                return;
            end
        end

        res = resNew;
        g = res.gamma_deg(:);
        M = res.(methodName);
        snr = get_method_array(M, 'snr', numel(g));
        valid = logical(get_method_array(M, 'valid', numel(g)));

        gammaIdx = clamp_index(gammaIdx, numel(g));
        draw_left_panel();
        update_view();
    end

    function switch_method()
        if ~has_method(res, methodName)
            return;
        end

        M = res.(methodName);
        snr = get_method_array(M, 'snr', numel(g));
        valid = logical(get_method_array(M, 'valid', numel(g)));

        gammaIdx = clamp_index(gammaIdx, numel(g));
        draw_left_panel();
        update_view();
    end

    function draw_left_panel()
        cla(ax1);
        hold(ax1, 'on');
        grid(ax1, 'on');

        plot(ax1, g, snr, 'k.-', 'DisplayName', 'SNR');
        plot(ax1, g(valid), snr(valid), 'ro', 'DisplayName', 'valid');

        xlabel(ax1, '\gamma / \chi (deg)');
        ylabel(ax1, 'SNR');

        peakDeg = allRes.peaksDeg(peakIdx);
        title(ax1, sprintf('Peak %d / %d | %.4f° | %s', ...
            peakIdx, nPeaks, peakDeg, methodName));

        legend(ax1, 'Location', 'best');
    end

    function update_view()
        delete(findobj(ax1, 'Tag', 'selected_snr_point'));
        plot(ax1, g(gammaIdx), snr(gammaIdx), 'ms', ...
            'MarkerSize', 10, ...
            'LineWidth', 1.5, ...
            'Tag', 'selected_snr_point');

        cla(ax2);
        hold(ax2, 'on');
        grid(ax2, 'on');

        fs = res.fitStore(gammaIdx);
        gammaVal = g(gammaIdx);

        if isempty(fs.r) || isempty(fs.yproc)
            title(ax2, sprintf('Kein Profil vorhanden | \\chi = %.3f°', gammaVal));
            drawnow;
            return;
        end

        plot(ax2, fs.r, fs.yproc, 'k.-', 'DisplayName', 'processed profile');

        peakPos = nan;
        peakErr = nan;
        R2 = nan;
        validLoc = false;
        usedFallback = false;
        usedAdaptive = false;
        usedAuto = false;
        windowUsed = nan;

        switch methodName
            case "centroid"
                validLoc = get_fitstore_logical(fs, 'valid_centroid');
                peakPos = get_method_value(M, 'tth_peak_deg', gammaIdx);
                peakErr = get_method_value(M, 'tth_peak_err_deg', gammaIdx);

                if validLoc && isfinite(fs.x_centroid)
                    xline(ax2, fs.x_centroid, 'r-', 'LineWidth', 1.5, 'DisplayName', 'centroid');
                end

            case "gauss"
                validLoc = get_fitstore_logical(fs, 'valid_gauss');
                peakPos = get_method_value(M, 'tth_peak_deg', gammaIdx);
                peakErr = get_method_value(M, 'tth_peak_err_deg', gammaIdx);
                R2 = get_method_value(M, 'R2', gammaIdx);

                if validLoc && ~isempty(fs.yfit_gauss)
                    if ~isempty(fs.xfit_gauss) && numel(fs.xfit_gauss) == numel(fs.yfit_gauss)
                        plot(ax2, fs.xfit_gauss, fs.yfit_gauss, 'r-', 'LineWidth', 1.5, 'DisplayName', 'gauss fit');
                    end
                end
                if validLoc && isfinite(fs.x_gauss)
                    xline(ax2, fs.x_gauss, 'b-', 'LineWidth', 1.5, 'DisplayName', 'gauss center');
                end

            case "pvoigt"
                validLoc = get_fitstore_logical(fs, 'valid_pvoigt');
                peakPos = get_method_value(M, 'tth_peak_deg', gammaIdx);
                peakErr = get_method_value(M, 'tth_peak_err_deg', gammaIdx);
                R2 = get_method_value(M, 'R2', gammaIdx);
                usedFallback = logical(get_method_value(M, 'usedFallback', gammaIdx));
                usedAdaptive = logical(get_method_value(M, 'usedAdaptiveWindow', gammaIdx));
                usedAuto = logical(get_method_value(M, 'usedAutoWindow', gammaIdx));
                windowUsed = get_method_value(M, 'windowDegUsed', gammaIdx);

                if validLoc && ~usedFallback && ~isempty(fs.yfit_pvoigt)
                    if ~isempty(fs.xfit_pvoigt) && numel(fs.xfit_pvoigt) == numel(fs.yfit_pvoigt)
                        plot(ax2, fs.xfit_pvoigt, fs.yfit_pvoigt, 'r-', 'LineWidth', 1.5, 'DisplayName', 'pVoigt fit');
                    end
                end
                if validLoc && isfinite(fs.x_pvoigt)
                    xline(ax2, fs.x_pvoigt, 'b-', 'LineWidth', 1.5, 'DisplayName', 'pVoigt center');
                end
        end

        legend(ax2, 'Location', 'best');
        xlabel(ax2, '2\theta');
        ylabel(ax2, 'Intensity');

        snrVal = get_method_value(M, 'snr', gammaIdx);
        noiseVal = get_method_value(M, 'noise', gammaIdx);
        ampVal = get_method_value(M, 'amp', gammaIdx);
        fwhmVal = get_method_value(M, 'fwhm', gammaIdx);
        peakDeg = allRes.peaksDeg(peakIdx);

        modeTag = "";
        if methodName == "pvoigt"
            if usedFallback
                modeTag = " | fallback";
            elseif usedAuto
                modeTag = sprintf(" | auto w=%.3f", windowUsed);
            elseif usedAdaptive
                modeTag = sprintf(" | adapt w=%.3f", windowUsed);
            elseif isfinite(windowUsed)
                modeTag = sprintf(" | w=%.3f", windowUsed);
            end
        end

        titleStr = sprintf('Peak %.4f° | %s | idx=%d/%d | \\chi=%.3f° | peak=%.6f° | err=%.4g° | SNR=%.3g%s', ...
            peakDeg, methodName, gammaIdx, numel(g), gammaVal, peakPos, peakErr, snrVal, modeTag);
        title(ax2, titleStr);

        sgtitle(tl, sprintf('Peak %d/%d | guess = %.4f° | Methode: %s', ...
            peakIdx, nPeaks, peakDeg, methodName));

        fprintf('\n=================================================\n');
        fprintf('Peak index:      %d / %d\n', peakIdx, nPeaks);
        fprintf('Peak guess:      %.6f deg\n', peakDeg);
        fprintf('Methode:         %s\n', methodName);
        fprintf('Gamma index:     %d / %d\n', gammaIdx, numel(g));
        fprintf('Gamma:           %.6f deg\n', gammaVal);
        fprintf('Valid:           %d\n', logical(validLoc));
        fprintf('SNR:             %.6g\n', snrVal);
        fprintf('Noise:           %.6g\n', noiseVal);
        fprintf('Amp:             %.6g\n', ampVal);
        fprintf('Peak:            %.6f deg\n', peakPos);
        fprintf('Err:             %.6g deg\n', peakErr);
        if isfinite(fwhmVal)
            fprintf('FWHM:            %.6g deg\n', fwhmVal);
        end
        if isfinite(R2)
            fprintf('R2:              %.6g\n', R2);
        end
        if methodName == "pvoigt"
            fprintf('Fallback:        %d\n', logical(usedFallback));
            fprintf('Adaptive window: %d\n', logical(usedAdaptive));
            fprintf('Auto window:     %d\n', logical(usedAuto));
            if isfinite(windowUsed)
                fprintf('windowDegUsed:   %.6f\n', windowUsed);
            else
                fprintf('windowDegUsed:   NaN\n');
            end
        end
        fprintf('=================================================\n');

        drawnow;
    end
end

% =====================================================================
% helper
% =====================================================================

function tf = has_method(res, methodName)
tf = isfield(res, char(methodName)) && ~isempty(res.(char(methodName)));
end

function arr = get_method_array(S, fieldName, n)
if isfield(S, fieldName) && ~isempty(S.(fieldName))
    arr = S.(fieldName)(:);
else
    arr = nan(n,1);
end
if numel(arr) < n
    arr(end+1:n,1) = nan;
end
end

function idx = nearest_index(x, xq)
x = x(:);
[~, idx] = min(abs(x - xq));
end

function idx = clamp_index(idx, n)
idx = max(1, min(n, idx));
end

function v = get_method_value(S, fieldName, idx)
v = nan;
if isfield(S, fieldName) && ~isempty(S.(fieldName))
    arr = S.(fieldName);
    if numel(arr) >= idx
        v = arr(idx);
    end
end
end

function v = get_fitstore_logical(S, fieldName)
v = false;
if isfield(S, fieldName) && ~isempty(S.(fieldName))
    v = logical(S.(fieldName));
end
end