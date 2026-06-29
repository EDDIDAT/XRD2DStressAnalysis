function h = markInvalidGammaRegions(h, peakIdx, clearFirst)
% MARKINVALIDGAMMAREGIONS
% Teil 1: BinnedGammaValid-Lücken (grau)
% Teil 2: Detektorlücken am Peak-2theta (orange) — valid_fraction-basiert

% ── Alte Marker löschen ───────────────────────────────────────────────
if nargin < 3
    clearFirst = true;
end

if clearFirst
    delete(findobj(h.axes, 'Tag', 'maskregion'));
    delete(findobj(h.axes, 'Tag', 'peakmask'));
end

if ~isfield(h, 'BinnedGammaValid') || isempty(h.BinnedGammaValid)
    return
end

% ── Alpha-Gruppe bestimmen ────────────────────────────────────────────
if isfield(h, 'DEKdataMatchedPeaks') && ...
   size(h.DEKdataMatchedPeaks, 1) >= peakIdx
    alphaVal = h.DEKdataMatchedPeaks(peakIdx, 7);
    if isfield(h, 'uniqueAlpha')
        [~, alphaGrpIdx] = min(abs(h.uniqueAlpha - alphaVal));
    else
        alphaGrpIdx = 1;
    end
else
    alphaGrpIdx = 1;
end

if alphaGrpIdx > numel(h.BinnedGammaValid) || ...
   isempty(h.BinnedGammaValid{alphaGrpIdx})
    return
end

validMask = h.BinnedGammaValid{alphaGrpIdx};
gammaVec  = h.BinnedGamma{alphaGrpIdx};      % +90° verschoben
yLims     = h.axes.YLim;

hold(h.axes, 'on');

% =====================================================================
% TEIL 1: Graue Patches für BinnedGammaValid-Lücken
% =====================================================================
invalidMask = ~validMask;

if any(invalidMask)
    changes    = diff([false; invalidMask(:); false]);
    blockStart = find(changes ==  1);
    blockEnd   = find(changes == -1) - 1;

    for b = 1:numel(blockStart)
        xLeft  = gammaVec(blockStart(b));
        xRight = gammaVec(blockEnd(b));

        if blockStart(b) > 1
            xLeft = xLeft - abs(gammaVec(blockStart(b)) - ...
                                 gammaVec(blockStart(b)-1)) * 0.5;
        end
        if blockEnd(b) < numel(gammaVec)
            xRight = xRight + abs(gammaVec(blockEnd(b)+1) - ...
                                   gammaVec(blockEnd(b))) * 0.5;
        end

        patch(h.axes, ...
            [xLeft xRight xRight xLeft], ...
            [yLims(1) yLims(1) yLims(2) yLims(2)], ...
            [0.85 0.85 0.85], ...
            'FaceAlpha', 0.45, ...
            'EdgeColor', [0.7 0.2 0.2], ...
            'LineWidth', 1.2, ...
            'LineStyle', '--', ...
            'Tag',       'maskregion');

        text(h.axes, (xLeft+xRight)/2, ...
            yLims(2) - (yLims(2)-yLims(1))*0.04, ...
            'mask', ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment',   'top', ...
            'FontSize', 7, ...
            'Color',    [0.7 0.2 0.2], ...
            'Tag',      'maskregion');
    end
end

% =====================================================================
% TEIL 2: Orange Patches für Detektorlücken AM PEAK
% Basiert auf valid_fraction an der Peak-2theta-Position
% =====================================================================

% Alle nötigen Felder prüfen
if ~isfield(h, 'pyfaiOutPerAlpha') || ...
   numel(h.pyfaiOutPerAlpha) < alphaGrpIdx || ...
   ~isfield(h, 'FitDataMod') || ...
   numel(h.FitDataMod) < peakIdx || ...
   ~isfield(h, 'BinnedGammaRaw') || ...
   numel(h.BinnedGammaRaw) < alphaGrpIdx
    uistack(findobj(h.axes, 'Tag', 'maskregion'), 'bottom');
    return
end

out_k = h.pyfaiOutPerAlpha{alphaGrpIdx};

% valid_fraction bevorzugen, Fallback auf caked_mask
if isfield(out_k, 'valid_fraction') && ~isempty(out_k.valid_fraction)
    validFrac = double(out_k.valid_fraction);
elseif isfield(out_k, 'caked_mask') && ~isempty(out_k.caked_mask)
    validFrac = double(out_k.caked_mask);
else
    uistack(findobj(h.axes, 'Tag', 'maskregion'), 'bottom');
    return
end

if ~isfield(out_k, 'radial')    || isempty(out_k.radial) || ...
   ~isfield(out_k, 'azimuthal') || isempty(out_k.azimuthal)
    uistack(findobj(h.axes, 'Tag', 'maskregion'), 'bottom');
    return
end

radialAll = double(out_k.radial(:));
azimAll   = double(out_k.azimuthal(:));
gammaRaw  = h.BinnedGammaRaw{alphaGrpIdx};  % unverschoben

% ── FitDataMod für diesen Peak ────────────────────────────────────────
pv      = h.FitDataMod{peakIdx};
pvGamma = pv(:, 1);   % +90° verschoben

% yCol und peakTth aus noch vorhandenen 2theta-Werten bestimmen
[yCol, ~, idxFinPv2theta] = getPlausibleCol(pv);

% idxFinPv: ALLE Zeilen mit gültigem γ-Wert (auch bereits gelöschte)
idxFinPv = isfinite(pvGamma);

if ~any(idxFinPv)
    uistack(findobj(h.axes, 'Tag', 'maskregion'), 'bottom');
    return
end

% peakTth bestimmen
if any(idxFinPv2theta)
    peakTth = median(pv(idxFinPv2theta, yCol));
elseif isfield(h,'DEKdataMatchedPeaks') && ...
       size(h.DEKdataMatchedPeaks,1) >= peakIdx && ...
       size(h.DEKdataMatchedPeaks,2) >= 4
    peakTth = h.DEKdataMatchedPeaks(peakIdx, 4);
else
    uistack(findobj(h.axes, 'Tag', 'maskregion'), 'bottom');
    return
end

if ~isfinite(peakTth)
    uistack(findobj(h.axes, 'Tag', 'maskregion'), 'bottom');
    return
end

% 2theta-Fenster um Peak
if isfield(h, 'peakMaskTthWinEdit') && isvalid(h.peakMaskTthWinEdit)
    tthWin = str2double(get(h.peakMaskTthWinEdit, 'String'));
    if isnan(tthWin) || tthWin <= 0, tthWin = 0.3; end
else
    tthWin = 0.3;
end

idxTthPk = radialAll >= peakTth - tthWin & ...
           radialAll <= peakTth + tthWin;
if ~any(idxTthPk)
    [~, iTmp]      = min(abs(radialAll - peakTth));
    idxTthPk       = false(size(radialAll));
    idxTthPk(iTmp) = true;
end

% Schwellenwert aus GUI
if isfield(h, 'peakMaskThreshEdit') && isvalid(h.peakMaskThreshEdit)
    peakMaskThresh = str2double(get(h.peakMaskThreshEdit, 'String'));
    if isnan(peakMaskThresh) || peakMaskThresh <= 0 || ...
       peakMaskThresh > 1
        peakMaskThresh = 0.99;
    end
else
    peakMaskThresh = 0.99;
end

% ── Pro FitDataMod-Zeile: valid_fraction am Peak prüfen ──────────────
halfWin   = 2;
nRows     = size(pv, 1);
rowFracOk = true(nRows, 1);

for ri = 1:nRows
    if ~idxFinPv(ri), continue; end

    gammaPV_ri = pvGamma(ri);   % +90° verschoben

    % Schritt 1: Index in gammaVec → binIdx
    [~, binIdx] = min(abs(gammaVec - gammaPV_ri));
    if binIdx > numel(gammaRaw), continue; end

    % Schritt 2: gammaRaw → chiIdx in azimAll
    gammaRaw_ri       = gammaRaw(binIdx);
    gammaRaw_for_azim = gammaRaw_ri;
    if gammaRaw_for_azim < -180, gammaRaw_for_azim = gammaRaw_for_azim + 360; end
    if gammaRaw_for_azim >  180, gammaRaw_for_azim = gammaRaw_for_azim - 360; end
    [~, chiIdx] = min(abs(azimAll - gammaRaw_for_azim));

    % Schritt 3: valid_fraction im chi- und 2theta-Fenster
    idxChi     = max(1, chiIdx-halfWin) : min(size(validFrac,1), chiIdx+halfWin);
    fracAtPeak = mean(mean(validFrac(idxChi, idxTthPk)));

    rowFracOk(ri) = fracAtPeak >= peakMaskThresh;

    if fracAtPeak < peakMaskThresh
        fprintf('    markInvalid: γ=%6.1f°  gammaRaw=%.1f°  frac=%.4f  < %.4f → orange\n', ...
            gammaPV_ri, gammaRaw_ri, fracAtPeak, peakMaskThresh);
    end
end

% Betroffene Zeilen: gültiger γ UND niedrige valid_fraction
isAffectedRow = idxFinPv & ~rowFracOk;

fprintf('  markInvalid: Peak %d  2theta=%.3f°  Schwelle=%.4f  %d/%d Zeilen betroffen\n', ...
    peakIdx, peakTth, peakMaskThresh, sum(isAffectedRow), sum(idxFinPv));

if ~any(isAffectedRow)
    allMaskObjs = [findobj(h.axes, 'Tag', 'maskregion'); ...
                   findobj(h.axes, 'Tag', 'peakmask')];
    for mo = 1:numel(allMaskObjs)
        uistack(allMaskObjs(mo), 'bottom');
    end
    return
end

% ── Zusammenhängende Blöcke betroffener γ-Werte finden ───────────────
affGamma   = sort(pvGamma(isAffectedRow));
validGamma = sort(pvGamma(idxFinPv));
if numel(validGamma) > 1
    gammaStep = median(diff(validGamma));
else
    gammaStep = 2.0;
end
if isnan(gammaStep) || gammaStep <= 0, gammaStep = 2.0; end

if numel(affGamma) == 1
    blkStarts = affGamma;
    blkEnds   = affGamma;
else
    gaps      = diff(affGamma) > gammaStep * 2.5;
    blkStarts = [affGamma(1);          affGamma(find(gaps)+1)];
    blkEnds   = [affGamma(find(gaps)); affGamma(end)];
end

% ── Orange Patches zeichnen ───────────────────────────────────────────
for b = 1:numel(blkStarts)
    xLeft  = blkStarts(b) - gammaStep * 0.5;
    xRight = blkEnds(b)   + gammaStep * 0.5;

    patch(h.axes, ...
        [xLeft xRight xRight xLeft], ...
        [yLims(1) yLims(1) yLims(2) yLims(2)], ...
        [1.0 0.7 0.3], ...
        'FaceAlpha', 0.35, ...
        'EdgeColor', [0.8 0.4 0.0], ...
        'LineWidth', 1.2, ...
        'LineStyle', '-', ...
        'Tag',       'peakmask');

    % Minimale frac_valid für Label berechnen
    idxBlock    = isAffectedRow & ...
                  pvGamma >= blkStarts(b) - gammaStep & ...
                  pvGamma <= blkEnds(b)   + gammaStep;
    rowsInBlock = find(idxBlock);
    fracVals    = zeros(numel(rowsInBlock), 1);

    for bi = 1:numel(rowsInBlock)
        ri_b        = rowsInBlock(bi);
        [~, binIdx] = min(abs(gammaVec - pvGamma(ri_b)));
        if binIdx > numel(gammaRaw), continue; end

        gammaRaw_bi = gammaRaw(binIdx);
        if gammaRaw_bi < -180, gammaRaw_bi = gammaRaw_bi + 360; end
        if gammaRaw_bi >  180, gammaRaw_bi = gammaRaw_bi - 360; end

        [~, chiIdx]  = min(abs(azimAll - gammaRaw_bi));
        idxChi       = max(1,chiIdx-halfWin) : min(size(validFrac,1),chiIdx+halfWin);
        fracVals(bi) = mean(mean(validFrac(idxChi, idxTthPk)));
    end

    posVals = fracVals(fracVals > 0);
    minFrac = 0;
    if ~isempty(posVals), minFrac = min(posVals); end

    text(h.axes, (xLeft+xRight)/2, ...
        yLims(2) - (yLims(2)-yLims(1))*0.10, ...
        sprintf('det\n%.0f%%', minFrac*100), ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment',   'top', ...
        'FontSize', 6, ...
        'Color',    [0.8 0.4 0.0], ...
        'Tag',      'peakmask');
end

% ── Alle Patches in den Hintergrund ──────────────────────────────────
allMaskObjs = [findobj(h.axes, 'Tag', 'maskregion'); ...
               findobj(h.axes, 'Tag', 'peakmask')];
for mo = 1:numel(allMaskObjs)
    uistack(allMaskObjs(mo), 'bottom');
end

end

% function h = markInvalidGammaRegions(h, peakIdx)
% % MARKINVALIDGAMMAREGIONS
% % Teil 1: BinnedGammaValid-Lücken (grau)
% % Teil 2: Detektorlücken am Peak-2theta (orange) — valid_fraction-basiert
% 
% % ── Alte Marker löschen ───────────────────────────────────────────────
% delete(findobj(h.axes, 'Tag', 'maskregion'));
% delete(findobj(h.axes, 'Tag', 'peakmask'));
% 
% if ~isfield(h, 'BinnedGammaValid') || isempty(h.BinnedGammaValid)
%     return
% end
% 
% % ── Alpha-Gruppe bestimmen ────────────────────────────────────────────
% if isfield(h, 'DEKdataMatchedPeaks') && ...
%    size(h.DEKdataMatchedPeaks, 1) >= peakIdx
%     alphaVal = h.DEKdataMatchedPeaks(peakIdx, 7);
%     if isfield(h, 'uniqueAlpha')
%         [~, alphaGrpIdx] = min(abs(h.uniqueAlpha - alphaVal));
%     else
%         alphaGrpIdx = 1;
%     end
% else
%     alphaGrpIdx = 1;
% end
% 
% if alphaGrpIdx > numel(h.BinnedGammaValid) || ...
%    isempty(h.BinnedGammaValid{alphaGrpIdx})
%     return
% end
% 
% validMask = h.BinnedGammaValid{alphaGrpIdx};
% gammaVec  = h.BinnedGamma{alphaGrpIdx};      % +90° verschoben
% yLims     = h.axes.YLim;
% 
% hold(h.axes, 'on');
% 
% % =====================================================================
% % TEIL 1: Graue Patches für BinnedGammaValid-Lücken
% % =====================================================================
% invalidMask = ~validMask;
% 
% if any(invalidMask)
%     changes    = diff([false; invalidMask(:); false]);
%     blockStart = find(changes ==  1);
%     blockEnd   = find(changes == -1) - 1;
% 
%     for b = 1:numel(blockStart)
%         xLeft  = gammaVec(blockStart(b));
%         xRight = gammaVec(blockEnd(b));
% 
%         if blockStart(b) > 1
%             xLeft = xLeft - abs(gammaVec(blockStart(b)) - ...
%                                  gammaVec(blockStart(b)-1)) * 0.5;
%         end
%         if blockEnd(b) < numel(gammaVec)
%             xRight = xRight + abs(gammaVec(blockEnd(b)+1) - ...
%                                    gammaVec(blockEnd(b))) * 0.5;
%         end
% 
%         patch(h.axes, ...
%             [xLeft xRight xRight xLeft], ...
%             [yLims(1) yLims(1) yLims(2) yLims(2)], ...
%             [0.85 0.85 0.85], ...
%             'FaceAlpha', 0.45, ...
%             'EdgeColor', [0.7 0.2 0.2], ...
%             'LineWidth', 1.2, ...
%             'LineStyle', '--', ...
%             'Tag',       'maskregion');
% 
%         text(h.axes, (xLeft+xRight)/2, ...
%             yLims(2) - (yLims(2)-yLims(1))*0.04, ...
%             'mask', ...
%             'HorizontalAlignment', 'center', ...
%             'VerticalAlignment',   'top', ...
%             'FontSize', 7, ...
%             'Color',    [0.7 0.2 0.2], ...
%             'Tag',      'maskregion');
%     end
% end
% 
% % =====================================================================
% % TEIL 2: Orange Patches für Detektorlücken AM PEAK
% % Basiert auf valid_fraction an der Peak-2theta-Position
% % =====================================================================
% 
% % Alle nötigen Felder prüfen
% if ~isfield(h, 'pyfaiOutPerAlpha') || ...
%    numel(h.pyfaiOutPerAlpha) < alphaGrpIdx || ...
%    ~isfield(h, 'FitDataMod') || ...
%    numel(h.FitDataMod) < peakIdx || ...
%    ~isfield(h, 'BinnedGammaRaw') || ...
%    numel(h.BinnedGammaRaw) < alphaGrpIdx
%     uistack(findobj(h.axes, 'Tag', 'maskregion'), 'bottom');
%     return
% end
% 
% out_k = h.pyfaiOutPerAlpha{alphaGrpIdx};
% 
% % valid_fraction bevorzugen, Fallback auf caked_mask
% if isfield(out_k, 'valid_fraction') && ~isempty(out_k.valid_fraction)
%     validFrac = double(out_k.valid_fraction);   % [npt_azim x npt_rad]
% elseif isfield(out_k, 'caked_mask') && ~isempty(out_k.caked_mask)
%     validFrac = double(out_k.caked_mask);
% else
%     uistack(findobj(h.axes, 'Tag', 'maskregion'), 'bottom');
%     return
% end
% 
% if ~isfield(out_k, 'radial')    || isempty(out_k.radial) || ...
%    ~isfield(out_k, 'azimuthal') || isempty(out_k.azimuthal)
%     uistack(findobj(h.axes, 'Tag', 'maskregion'), 'bottom');
%     return
% end
% 
% radialAll = double(out_k.radial(:));
% azimAll   = double(out_k.azimuthal(:));
% gammaRaw  = h.BinnedGammaRaw{alphaGrpIdx};  % unverschoben
% 
% % FitDataMod für diesen Peak
% % pv = h.FitDataMod{peakIdx};
% % [yCol, ~, idxFinPv] = getPlausibleCol(pv);
% % 
% % if ~any(idxFinPv)
% %     uistack(findobj(h.axes, 'Tag', 'maskregion'), 'bottom');
% %     return
% % end
% % 
% % peakTth = median(pv(idxFinPv, yCol));
% % ── Teil 2: Für die Prüfung ALLE Zeilen mit gültigem γ verwenden ─────
% % Auch bereits gelöschte Zeilen (NaN in Spalte 2) sollen geprüft werden
% % da ihre Detektorlücken weiterhin angezeigt werden sollen
% pv      = h.FitDataMod{peakIdx};
% pvGamma = pv(:, 1);
% 
% % Alle Zeilen mit gültigem γ-Wert — nicht nur plausible 2theta-Zeilen
% idxFinPv = isfinite(pvGamma);   % ← statt getPlausibleCol
% 
% if ~any(idxFinPv)
%     uistack(findobj(h.axes, 'Tag', 'maskregion'), 'bottom');
%     return
% end
% 
% peakTth = median(pv(idxFinPv & isfinite(pv(:,2)), yCol));
% 
% pvGamma = pv(:, 1);   % +90° verschoben
% 
% % 2theta-Fenster um Peak
% if isfield(h, 'peakMaskTthWinEdit') && isvalid(h.peakMaskTthWinEdit)
%     tthWin = str2double(get(h.peakMaskTthWinEdit, 'String'));
%     if isnan(tthWin) || tthWin <= 0, tthWin = 0.3; end
% else
%     tthWin = 0.3;
% end
% 
% idxTthPk = radialAll >= peakTth - tthWin & ...
%            radialAll <= peakTth + tthWin;
% if ~any(idxTthPk)
%     [~, iTmp]      = min(abs(radialAll - peakTth));
%     idxTthPk       = false(size(radialAll));
%     idxTthPk(iTmp) = true;
% end
% 
% % Schwellenwert aus GUI
% if isfield(h, 'peakMaskThreshEdit') && isvalid(h.peakMaskThreshEdit)
%     peakMaskThresh = str2double(get(h.peakMaskThreshEdit, 'String'));
%     if isnan(peakMaskThresh) || peakMaskThresh <= 0 || ...
%        peakMaskThresh > 1
%         peakMaskThresh = 0.99;
%     end
% else
%     peakMaskThresh = 0.99;
% end
% 
% % ── Pro FitDataMod-Zeile: valid_fraction am Peak prüfen ──────────────
% halfWin     = 2;
% nRows       = size(pv, 1);
% rowFracOk   = true(nRows, 1);
% 
% for ri = 1:nRows
%     if ~idxFinPv(ri), continue; end
% 
%     gammaPV_ri = pvGamma(ri);   % +90° verschoben
% 
%     % Schritt 1: Index in gammaVec (beide +90°) → binIdx
%     [~, binIdx] = min(abs(gammaVec - gammaPV_ri));
%     if binIdx > numel(gammaRaw), continue; end
% 
%     % Schritt 2: gammaRaw (unverschoben) → chiIdx in azimAll (unverschoben)
%     gammaRaw_ri = gammaRaw(binIdx);
%     % [~, chiIdx] = min(abs(azimAll - gammaRaw_ri));
%     % Option-2-Korrektur: gammaRaw < -180° → +360° für azimAll-Suche
%     % (azimAll geht nur bis -179.5°, aber gammaRaw kann bis -270° gehen)
%     gammaRaw_for_azim = gammaRaw_ri;
%     if gammaRaw_for_azim < -180
%         gammaRaw_for_azim = gammaRaw_for_azim + 360;
%     end
% 
% 
%     [~, chiIdx] = min(abs(azimAll - gammaRaw_for_azim));
% 
%     % Schritt 3: valid_fraction im chi-Fenster und 2theta-Fenster
%     idxChi     = max(1, chiIdx-halfWin) : min(size(validFrac,1), chiIdx+halfWin);
%     fracAtPeak = mean(mean(validFrac(idxChi, idxTthPk)));
% 
%     rowFracOk(ri) = fracAtPeak >= peakMaskThresh;
% 
%     if fracAtPeak < peakMaskThresh
%         fprintf('    markInvalid: γ=%6.1f°  gammaRaw=%.1f°  frac=%.4f  < %.4f → orange\n', ...
%             gammaPV_ri, gammaRaw_ri, fracAtPeak, peakMaskThresh);
%     end
% end
% 
% % Betroffene Zeilen: plausible 2theta-Werte UND niedrige valid_fraction
% isAffectedRow = idxFinPv & ~rowFracOk;
% 
% fprintf('  markInvalid: Peak %d  2theta=%.3f°  Schwelle=%.4f  %d/%d Zeilen betroffen\n', ...
%     peakIdx, peakTth, peakMaskThresh, sum(isAffectedRow), sum(idxFinPv));
% 
% if ~any(isAffectedRow)
%     allMaskObjs = [findobj(h.axes, 'Tag', 'maskregion'); ...
%                    findobj(h.axes, 'Tag', 'peakmask')];
%     for mo = 1:numel(allMaskObjs)
%         uistack(allMaskObjs(mo), 'bottom');
%     end
%     return
% end
% 
% % ── Zusammenhängende Blöcke betroffener γ-Werte finden ───────────────
% affGamma   = sort(pvGamma(isAffectedRow));
% validGamma = sort(pvGamma(idxFinPv));
% if numel(validGamma) > 1
%     gammaStep = median(diff(validGamma));
% else
%     gammaStep = 2.0;
% end
% if isnan(gammaStep) || gammaStep <= 0, gammaStep = 2.0; end
% 
% if numel(affGamma) == 1
%     blkStarts = affGamma;
%     blkEnds   = affGamma;
% else
%     gaps      = diff(affGamma) > gammaStep * 2.5;
%     blkStarts = [affGamma(1);        affGamma(find(gaps)+1)];
%     blkEnds   = [affGamma(find(gaps)); affGamma(end)];
% end
% 
% % ── Orange Patches zeichnen ───────────────────────────────────────────
% for b = 1:numel(blkStarts)
%     xLeft  = blkStarts(b) - gammaStep * 0.5;
%     xRight = blkEnds(b)   + gammaStep * 0.5;
% 
%     patch(h.axes, ...
%         [xLeft xRight xRight xLeft], ...
%         [yLims(1) yLims(1) yLims(2) yLims(2)], ...
%         [1.0 0.7 0.3], ...
%         'FaceAlpha', 0.35, ...
%         'EdgeColor', [0.8 0.4 0.0], ...
%         'LineWidth', 1.2, ...
%         'LineStyle', '-', ...
%         'Tag',       'peakmask');
% 
%     % frac-Wert für diesen Block
%     idxBlock  = isAffectedRow & ...
%                 pvGamma >= blkStarts(b) - gammaStep & ...
%                 pvGamma <= blkEnds(b)   + gammaStep;
%     blockFrac = min(rowFracOk(idxBlock));   % immer false hier
% 
%     % Minimale frac_valid für Label berechnen
%     fracVals = zeros(sum(idxBlock), 1);
%     rowsInBlock = find(idxBlock);
%     for bi = 1:numel(rowsInBlock)
%         ri_b        = rowsInBlock(bi);
%         [~, binIdx] = min(abs(gammaVec - pvGamma(ri_b)));
%         if binIdx > numel(gammaRaw), continue; end
%         [~, chiIdx] = min(abs(azimAll - gammaRaw(binIdx)));
%         idxChi      = max(1,chiIdx-halfWin):min(size(validFrac,1),chiIdx+halfWin);
%         fracVals(bi) = mean(mean(validFrac(idxChi, idxTthPk)));
%     end
%     minFrac = min(fracVals(fracVals > 0));
%     if isempty(minFrac), minFrac = 0; end
% 
%     text(h.axes, (xLeft+xRight)/2, ...
%         yLims(2) - (yLims(2)-yLims(1))*0.10, ...
%         sprintf('det\n%.0f%%', minFrac*100), ...
%         'HorizontalAlignment', 'center', ...
%         'VerticalAlignment',   'top', ...
%         'FontSize', 6, ...
%         'Color',    [0.8 0.4 0.0], ...
%         'Tag',      'peakmask');
% end
% 
% % ── Alle Patches in den Hintergrund ──────────────────────────────────
% allMaskObjs = [findobj(h.axes, 'Tag', 'maskregion'); ...
%                findobj(h.axes, 'Tag', 'peakmask')];
% for mo = 1:numel(allMaskObjs)
%     uistack(allMaskObjs(mo), 'bottom');
% end
% 
% end