function showCakedMaskOverBins(h, alphaGrpIdx)

if nargin < 2, alphaGrpIdx = 1; end

if ~isfield(h, 'pyfaiOutPerAlpha') || numel(h.pyfaiOutPerAlpha) < alphaGrpIdx
    errordlg('Keine pyFAI-Daten verfügbar.', 'Fehler');
    return
end

out_k = h.pyfaiOutPerAlpha{alphaGrpIdx};

if ~isfield(out_k, 'caked_mask') || isempty(out_k.caked_mask)
    errordlg('Keine caked_mask verfügbar. Bitte PONI-Dateien neu laden.', 'Fehler');
    return
end

% ── Daten vorbereiten ─────────────────────────────────────────────────
% I_k       = double(out_k.I);
% cakedMask = double(out_k.caked_mask);

I_k        = double(out_k.I);
cakedMask  = double(out_k.caked_mask);   % für binäre Darstellung
if isfield(out_k, 'valid_fraction') && ~isempty(out_k.valid_fraction)
    fracValid = double(out_k.valid_fraction);
else
    fracValid = cakedMask;
end
cakedMask = fracValid;   % ab hier cakedMask = kontinuierlicher frac_valid

radialAll = double(out_k.radial(:));
azimAll   = double(out_k.azimuthal(:));
alphaVal  = h.uniqueAlpha(alphaGrpIdx);

% γ-Bins und Validität
if isfield(h, 'BinnedGammaRaw') && numel(h.BinnedGammaRaw) >= alphaGrpIdx
    gammaRaw = h.BinnedGammaRaw{alphaGrpIdx};
    validBin = h.BinnedGammaValid{alphaGrpIdx};
else
    gammaRaw = [];
    validBin = [];
end

% genutzter 2theta-Bereich
if isfield(h, 'dataX') && numel(h.dataX) >= alphaGrpIdx
    tthMin  = min(h.dataX{alphaGrpIdx});
    tthMax  = max(h.dataX{alphaGrpIdx});
    idxTth  = find(radialAll >= tthMin & radialAll <= tthMax);
else
    tthMin  = min(radialAll);
    tthMax  = max(radialAll);
    idxTth  = 1:numel(radialAll);
end

nBins = numel(gammaRaw);

% chiFracValid pro Bin
chiFracAll = zeros(nBins, 1);
for bn = 1:nBins
    [~, chiIdx]    = min(abs(azimAll - gammaRaw(bn)));
    idxRange       = max(1, chiIdx-4) : min(numel(azimAll), chiIdx+4);
    chiFracAll(bn) = mean(mean(cakedMask(idxRange, idxTth), 2));
end

% ── Figure erstellen ──────────────────────────────────────────────────
fig = figure('Name', sprintf('Caked Mask Bin-Viewer  |  α=%.1f°', alphaVal), ...
    'NumberTitle', 'off', ...
    'Units',       'normalized', ...
    'Position',    [0.04 0.05 0.92 0.85], ...
    'Color',       [0.15 0.15 0.15]);

% ── Layout ───────────────────────────────────────────────────────────
% Steuerbereich oben
uicontrol(fig, 'Style', 'text', ...
    'Units', 'normalized', 'Position', [0.01 0.945 0.08 0.030], ...
    'String', 'γ-Bin:', 'FontSize', 10, ...
    'ForegroundColor', 'w', 'BackgroundColor', [0.15 0.15 0.15], ...
    'HorizontalAlignment', 'left');

txtBinInfo = uicontrol(fig, 'Style', 'text', ...
    'Units', 'normalized', 'Position', [0.09 0.945 0.50 0.030], ...
    'String', '', 'FontSize', 10, 'FontWeight', 'bold', ...
    'ForegroundColor', [1 0.85 0.3], 'BackgroundColor', [0.15 0.15 0.15], ...
    'HorizontalAlignment', 'left');

% Slider
sliderBin = uicontrol(fig, 'Style', 'slider', ...
    'Units',      'normalized', ...
    'Position',   [0.01 0.915 0.88 0.025], ...
    'Min',        1, ...
    'Max',        max(nBins, 2), ...
    'Value',      1, ...
    'SliderStep', [1/max(nBins-1,1)  5/max(nBins-1,1)]);

% Bin-Nummer Anzeige
txtBinNum = uicontrol(fig, 'Style', 'text', ...
    'Units', 'normalized', 'Position', [0.90 0.915 0.09 0.025], ...
    'String', '1', 'FontSize', 9, ...
    'ForegroundColor', 'w', 'BackgroundColor', [0.15 0.15 0.15]);

% ── Axes ──────────────────────────────────────────────────────────────
% Links oben: Caked Image gesamt mit Bin-Markierung
ax1 = axes('Parent', fig, 'Units', 'normalized', ...
    'Position', [0.01 0.50 0.30 0.40]);

% Mitte oben: Maske für aktuellen Bin (1D-Profil über 2theta)
ax2 = axes('Parent', fig, 'Units', 'normalized', ...
    'Position', [0.35 0.50 0.30 0.40]);

% Rechts oben: Overlay Caked Image + Maske für aktuellen Bin
ax3 = axes('Parent', fig, 'Units', 'normalized', ...
    'Position', [0.68 0.50 0.30 0.40]);

% Unten links: chiFracValid über alle Bins
ax4 = axes('Parent', fig, 'Units', 'normalized', ...
    'Position', [0.01 0.06 0.44 0.37]);

% Unten rechts: Intensitätsprofil des aktuellen Bins
ax5 = axes('Parent', fig, 'Units', 'normalized', ...
    'Position', [0.54 0.06 0.44 0.37]);

% ── Caked Image (einmal zeichnen) ─────────────────────────────────────
I_log = log10(1 + max(I_k, 0));
v     = I_log(isfinite(I_log) & I_log > 0);
clims = prctile(v, [1 99]);

imagesc(ax1, radialAll, azimAll, I_log);
clim(ax1, clims);
colormap(ax1, 'hot');
colorbar(ax1);
ax1.YDir             = 'normal';
ax1.Color            = [0.1 0.1 0.1];
ax1.XColor           = [0.8 0.8 0.8];
ax1.YColor           = [0.8 0.8 0.8];
ax1.Title.Color      = [0.9 0.9 0.9];
xlabel(ax1, '2\theta (°)', 'Color', [0.8 0.8 0.8]);
ylabel(ax1, '\chi (°)',    'Color', [0.8 0.8 0.8]);
title(ax1, sprintf('Caked Image  |  α=%.1f°', alphaVal), ...
    'Color', [0.9 0.9 0.9]);
hold(ax1, 'on');

% Genutzten 2theta-Bereich markieren
xline(ax1, tthMin, '--w', 'LineWidth', 1.0, 'Alpha', 0.6);
xline(ax1, tthMax, '--w', 'LineWidth', 1.0, 'Alpha', 0.6);

% Alle γ-Bin-Linien grau
for bn = 1:nBins
    if validBin(bn)
        yline(ax1, gammaRaw(bn), '-', ...
            'Color', [0.3 0.7 0.3], 'LineWidth', 0.4, 'Alpha', 0.3);
    else
        yline(ax1, gammaRaw(bn), '-', ...
            'Color', [0.8 0.2 0.2], 'LineWidth', 0.8, 'Alpha', 0.5);
    end
end

% Aktuelle Bin-Linie (wird bei Slider-Update neu gesetzt)
hBinLine = yline(ax1, gammaRaw(1), '-', ...
    'Color', [1 0.9 0.1], 'LineWidth', 2.0);

% ── chiFracValid Profil (einmal zeichnen) ─────────────────────────────
plot(ax4, 1:nBins, chiFracAll, '-b', 'LineWidth', 1.5);
hold(ax4, 'on');

% Ungültige Bins rot markieren
for bn = 1:nBins
    if ~validBin(bn)
        plot(ax4, bn, chiFracAll(bn), 'rv', ...
            'MarkerFaceColor', 'r', 'MarkerSize', 7);
    else
        plot(ax4, bn, chiFracAll(bn), 'g^', ...
            'MarkerFaceColor', 'g', 'MarkerSize', 4);
    end
end

% Aktueller Bin-Marker
hFracMarker = plot(ax4, 1, chiFracAll(1), 'yo', ...
    'MarkerFaceColor', 'y', 'MarkerSize', 10, 'LineWidth', 1.5);

% γ-Labels auf X-Achse
xticks(ax4, round(linspace(1, nBins, min(nBins, 12))));
xticklabels(ax4, arrayfun(@(bn) sprintf('%.0f°', gammaRaw(bn) + 90), ...
    round(linspace(1, nBins, min(nBins, 12))), 'UniformOutput', false));
ax4.XTickLabelRotation = 45;
xlabel(ax4, '\gamma (°)');
ylabel(ax4, 'frac\_valid');
title(ax4, sprintf('Anteil valider Pixel pro \\gamma-Bin  |  2\\theta=[%.1f°, %.1f°]', ...
    tthMin, tthMax));
ylim(ax4, [0 1.05]);
grid(ax4, 'on');
xlim(ax4, [1 nBins]);

% ── Erste Anzeige ─────────────────────────────────────────────────────
updatePlots(1);

% ── Slider Callback ───────────────────────────────────────────────────
addlistener(sliderBin, 'Value', 'PostSet', @(~,~) onSlider());

% =====================================================================
% Nested Functions
% =====================================================================

    function onSlider()
        binIdx = max(1, min(nBins, round(get(sliderBin, 'Value'))));
        set(sliderBin, 'Value', binIdx);
        set(txtBinNum, 'String', num2str(binIdx));
        updatePlots(binIdx);
    end

    function updatePlots(binIdx)
        if binIdx < 1 || binIdx > nBins, return; end

        % chi-Index für diesen Bin
        [~, chiIdx] = min(abs(azimAll - gammaRaw(binIdx)));
        halfWin     = 4;
        idxRange    = max(1, chiIdx-halfWin) : min(numel(azimAll), chiIdx+halfWin);

        % Maskenzeile für diesen Bin
        maskRow = mean(cakedMask(idxRange, :), 1);   % [1 x npt_rad]
        maskROI = maskRow(idxTth);
        radROI  = radialAll(idxTth);
        I_row   = mean(I_k(idxRange, :), 1);         % mittleres Intensitätsprofil
        I_ROI   = I_row(idxTth);

        % Schwellenwert aus GUI lesen
        if isfield(h, 'peakMaskThreshEdit') && isvalid(h.peakMaskThreshEdit)
            maskThresh = str2double(get(h.peakMaskThreshEdit, 'String'));
            if isnan(maskThresh) || maskThresh <= 0 || maskThresh > 1
                maskThresh = 0.99;
            end
        else
            maskThresh = 0.99;
        end

        % Bin-Info Text
        isValid  = validBin(binIdx);
        validStr = 'VALIDE';
        if ~isValid, validStr = 'UNGÜLTIG'; end
        set(txtBinInfo, 'String', sprintf(...
            'Bin %d/%d  |  γ=%.2f°  |  χ=%.2f°  |  frac_valid=%.3f  |  %s', ...
            binIdx, nBins, gammaRaw(binIdx)+90, gammaRaw(binIdx), ...
            chiFracAll(binIdx), validStr));

        % Bin-Linie in Caked Image aktualisieren
        set(hBinLine, 'Value', gammaRaw(binIdx));
        if isValid
            set(hBinLine, 'Color', [1 0.9 0.1]);
        else
            set(hBinLine, 'Color', [1 0.3 0.3]);
        end

        % Marker in chiFracValid Plot
        set(hFracMarker, 'XData', binIdx, 'YData', chiFracAll(binIdx));

        % ── ax2: Masken-Profil dieses Bins über 2theta ────────────────
        cla(ax2);
        hold(ax2, 'on');

        % Hintergrundfarbe nach Validität
        if isValid
            ax2.Color = [0.08 0.15 0.08];
        else
            ax2.Color = [0.18 0.06 0.06];
        end

        % Maske als Fläche
        area(ax2, radROI, maskROI, ...
            'FaceColor', [0.3 0.7 0.3], 'FaceAlpha', 0.5, ...
            'EdgeColor', [0.3 0.7 0.3], 'LineWidth', 0.8);

        % Maskierte Bereiche rot hervorheben
        isMasked = maskROI < maskThresh;
        if any(isMasked)
            changes  = diff([false, isMasked, false]);
            blkStart = find(changes ==  1);
            blkEnd   = find(changes == -1) - 1;
            yLims2   = [0 1.1];
            for bb = 1:numel(blkStart)
                xL = radROI(blkStart(bb));
                xR = radROI(blkEnd(bb));
                patch(ax2, [xL xR xR xL], ...
                    [yLims2(1) yLims2(1) yLims2(2) yLims2(2)], ...
                    [0.9 0.2 0.2], 'FaceAlpha', 0.4, 'EdgeColor', 'none');
            end
        end

        xline(ax2, tthMin, '--w', 'LineWidth', 1.0, 'Alpha', 0.7);
        xline(ax2, tthMax, '--w', 'LineWidth', 1.0, 'Alpha', 0.7);
        xlim(ax2, [min(radialAll) max(radialAll)]);
        ylim(ax2, [0 1.1]);
        ax2.XColor = [0.8 0.8 0.8];
        ax2.YColor = [0.8 0.8 0.8];
        xlabel(ax2, '2\theta (°)', 'Color', [0.8 0.8 0.8]);
        ylabel(ax2, 'frac\_valid', 'Color', [0.8 0.8 0.8]);
        title(ax2, sprintf('Maske: γ=%.2f°  (χ=%.2f°)', ...
            gammaRaw(binIdx)+90, gammaRaw(binIdx)), ...
            'Color', [0.9 0.9 0.9]);
        grid(ax2, 'on');

        % ── ax3: Overlay Intensität + Maske ───────────────────────────
        cla(ax3);
        hold(ax3, 'on');
        ax3.Color = [0.1 0.1 0.1];

        % Intensitätsprofil
        I_log_row = log10(1 + max(I_ROI, 0));
        yyaxis(ax3, 'left');
        plot(ax3, radROI, I_log_row, '-', ...
            'Color', [1.0 0.7 0.2], 'LineWidth', 1.5);
        ax3.YColor = [1.0 0.7 0.2];
        ylabel(ax3, 'log_{10}(1+I)', 'Color', [1.0 0.7 0.2]);

        % Masken-Profil
        yyaxis(ax3, 'right');
        plot(ax3, radROI, maskROI, '-', ...
            'Color', [0.3 0.8 1.0], 'LineWidth', 1.5);
        ax3.YColor = [0.3 0.8 1.0];
        ylabel(ax3, 'frac\_valid', 'Color', [0.3 0.8 1.0]);
        ylim(ax3, [-0.05 1.15]);

        % Maskierte Bereiche rot
        if any(isMasked)
            for bb = 1:numel(blkStart)
                xL = radROI(blkStart(bb));
                xR = radROI(blkEnd(bb));
                yyaxis(ax3, 'left');
                yLims3 = ax3.YLim;
                patch(ax3, [xL xR xR xL], ...
                    [yLims3(1) yLims3(1) yLims3(2) yLims3(2)], ...
                    [0.9 0.2 0.2], 'FaceAlpha', 0.25, 'EdgeColor', 'none');
            end
        end

        xline(ax3, tthMin, '--w', 'LineWidth', 1.0, 'Alpha', 0.7);
        xline(ax3, tthMax, '--w', 'LineWidth', 1.0, 'Alpha', 0.7);
        xlim(ax3, [min(radialAll) max(radialAll)]);
        ax3.XColor = [0.8 0.8 0.8];
        xlabel(ax3, '2\theta (°)', 'Color', [0.8 0.8 0.8]);
        title(ax3, 'Intensität + Maske', 'Color', [0.9 0.9 0.9]);
        grid(ax3, 'on');

        % ── ax5: Intensitätsprofil des Bins ───────────────────────────
        cla(ax5);
        hold(ax5, 'on');
        ax5.Color = [0.1 0.1 0.1];

        plot(ax5, radROI, I_ROI, '-', ...
            'Color', [1.0 0.7 0.2], 'LineWidth', 1.5);

        % Detektorlücken grau markieren
        if any(isMasked)
            yLims5 = [0, max(I_ROI(isfinite(I_ROI))) * 1.1];
            if yLims5(2) <= 0, yLims5(2) = 1; end
            for bb = 1:numel(blkStart)
                xL = radROI(blkStart(bb));
                xR = radROI(blkEnd(bb));
                patch(ax5, [xL xR xR xL], ...
                    [yLims5(1) yLims5(1) yLims5(2) yLims5(2)], ...
                    [0.6 0.6 0.6], 'FaceAlpha', 0.35, 'EdgeColor', 'none');
            end
        end

        xline(ax5, tthMin, '--w', 'LineWidth', 1.0, 'Alpha', 0.7);
        xline(ax5, tthMax, '--w', 'LineWidth', 1.0, 'Alpha', 0.7);
        xlim(ax5, [min(radialAll) max(radialAll)]);
        ax5.XColor = [0.8 0.8 0.8];
        ax5.YColor = [0.8 0.8 0.8];
        xlabel(ax5, '2\theta (°)', 'Color', [0.8 0.8 0.8]);
        ylabel(ax5, 'Intensität [a.u.]', 'Color', [0.8 0.8 0.8]);
        title(ax5, sprintf('Intensitätsprofil  γ=%.2f°', gammaRaw(binIdx)+90), ...
            'Color', [0.9 0.9 0.9]);
        grid(ax5, 'on');

        drawnow limitrate;
    end

end