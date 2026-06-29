function h = applyDetectorMaskToFitData(hObj, ~)
h = guidata(hObj);

% =====================================================================
% Eingabeprüfung
% =====================================================================
if ~isfield(h, 'FitDataMod') || isempty(h.FitDataMod)
    errordlg('Keine Fitdaten vorhanden. Bitte zuerst Peaks fitten.', 'Fehler');
    return
end

if ~isfield(h, 'pyfaiOutPerAlpha') || isempty(h.pyfaiOutPerAlpha)
    errordlg('Keine pyFAI-Daten vorhanden.', 'Fehler');
    return
end

% =====================================================================
% Parameter aus GUI lesen
% =====================================================================
if isfield(h, 'peakMaskThreshEdit') && isvalid(h.peakMaskThreshEdit)
    peakMaskThresh = str2double(get(h.peakMaskThreshEdit, 'String'));
    if isnan(peakMaskThresh) || peakMaskThresh <= 0 || peakMaskThresh > 1
        peakMaskThresh = 0.99;
    end
else
    peakMaskThresh = 0.99;
end

if isfield(h, 'peakMaskTthWinEdit') && isvalid(h.peakMaskTthWinEdit)
    tthWin = str2double(get(h.peakMaskTthWinEdit, 'String'));
    if isnan(tthWin) || tthWin <= 0
        tthWin = 0.5;
    end
else
    tthWin = 0.5;
end

halfWin      = 2;
nPeaks       = size(h.FitDataMod, 1);
totalRemoved = 0;

% =====================================================================
% Hauptschleife über alle Peaks
% =====================================================================
for peakIdx = 1:nPeaks

    % ── Alpha-Gruppe bestimmen ────────────────────────────────────────
    if isfield(h, 'DEKdataMatchedPeaks') && ...
       size(h.DEKdataMatchedPeaks,1) >= peakIdx
        alphaVal = h.DEKdataMatchedPeaks(peakIdx, 7);
        if isfield(h, 'uniqueAlpha')
            [~, alphaGrpIdx] = min(abs(h.uniqueAlpha - alphaVal));
        else
            alphaGrpIdx = 1;
        end
    else
        alphaGrpIdx = 1;
    end

    % ── pyFAI-Daten laden ─────────────────────────────────────────────
    out_k = h.pyfaiOutPerAlpha{alphaGrpIdx};
    if ~isfield(out_k, 'caked_mask') || isempty(out_k.caked_mask)
        fprintf('Peak %d: keine caked_mask — übersprungen\n', peakIdx);
        continue
    end

    % valid_fraction bevorzugen, Fallback auf caked_mask
    if isfield(out_k, 'valid_fraction') && ~isempty(out_k.valid_fraction)
        validFrac = double(out_k.valid_fraction);
    else
        validFrac = double(out_k.caked_mask);
    end

    radialAll = double(out_k.radial(:));
    azimAll   = double(out_k.azimuthal(:));

    % ── BinnedGamma-Felder prüfen ─────────────────────────────────────
    if ~isfield(h, 'BinnedGammaRaw')   || numel(h.BinnedGammaRaw)   < alphaGrpIdx || ...
       ~isfield(h, 'BinnedGamma')      || numel(h.BinnedGamma)      < alphaGrpIdx || ...
       ~isfield(h, 'BinnedGammaValid') || numel(h.BinnedGammaValid) < alphaGrpIdx
        fprintf('Peak %d: BinnedGamma-Felder fehlen — übersprungen\n', peakIdx);
        continue
    end

    gammaRaw  = h.BinnedGammaRaw{alphaGrpIdx};
    gammaVec  = h.BinnedGamma{alphaGrpIdx};
    nBins     = numel(gammaRaw);

    if numel(gammaVec) ~= nBins
        fprintf('Peak %d: gammaRaw/gammaVec Längenfehler — übersprungen\n', peakIdx);
        continue
    end

    % ── FitDataMod für diesen Peak ────────────────────────────────────
    pv = h.FitDataMod{peakIdx};
    [yCol, ~, idxFinPv] = getPlausibleCol(pv);

    if ~any(idxFinPv)
        fprintf('Peak %d: keine plausiblen 2theta-Werte — übersprungen\n', peakIdx);
        continue
    end

    peakTth = median(pv(idxFinPv, yCol));
    pvGamma = pv(:, 1);
    nRows   = size(pv, 1);

    fprintf('\nPeak %d (2θ=%.3f°):\n', peakIdx, peakTth);

    % ── 2theta-Fenster ────────────────────────────────────────────────
    idxTthPk = find(radialAll >= peakTth - tthWin & ...
                    radialAll <= peakTth + tthWin);
    if isempty(idxTthPk)
        [~, idxTthPk] = min(abs(radialAll - peakTth));
    end

    % =====================================================================
    % rowMaskFrac: direkt pro FitDataMod-Zeile berechnen
    % Mapping: pvGamma(ri) → gammaVec-Index → gammaRaw → azimAll
    % =====================================================================
    rowMaskFrac = ones(nRows, 1);

    for ri = 1:nRows
        gammaPV_ri = pvGamma(ri);

        % gammaVec (verschoben) → Index → gammaRaw (unverschoben)
        [~, binIdx] = min(abs(gammaVec - gammaPV_ri));
        if binIdx > numel(gammaRaw), continue; end

        % azimAll-Suche mit unverschobenem gammaRaw
        % [~, chiIdx] = min(abs(azimAll - gammaRaw(binIdx)));
        gammaRaw_azim = gammaRaw(binIdx);
        if gammaRaw_azim < -180
            gammaRaw_azim = gammaRaw_azim + 360;
        elseif gammaRaw_azim > 180
            gammaRaw_azim = gammaRaw_azim - 360;
        end
        [~, chiIdx] = min(abs(azimAll - gammaRaw_azim));
        idxChi      = max(1, chiIdx - halfWin) : ...
                      min(numel(azimAll), chiIdx + halfWin);

        fracAtPeak     = validFrac(idxChi, idxTthPk);
        rowMaskFrac(ri) = min(fracAtPeak(:));
    end

    fprintf('  rowMaskFrac: min=%.4f  max=%.4f  mean=%.4f\n', ...
        min(rowMaskFrac), max(rowMaskFrac), mean(rowMaskFrac));

    % ── Adaptiver Schwellenwert ───────────────────────────────────────
    lowFrac = rowMaskFrac(rowMaskFrac < 0.95);
    if ~isempty(lowFrac) && any(lowFrac < 0.5)
        adaptThresh = 0.95;
    elseif ~isempty(lowFrac)
        adaptThresh = min(peakMaskThresh, ...
                          mean(lowFrac) + 2*std(lowFrac) + 0.05);
    else
        adaptThresh = peakMaskThresh;
    end
    fprintf('  Schwellenwert: %.4f (adaptiv: %.4f)\n', ...
        peakMaskThresh, adaptThresh);

    % ── Betroffene Zeilen bestimmen ───────────────────────────────────
    % Nur plausible Zeilen UND niedrigem MaskFrac
    isAffectedRow = idxFinPv & (rowMaskFrac < adaptThresh);

    fprintf('  Betroffene Zeilen: %d\n', sum(isAffectedRow));
    if any(isAffectedRow)
        fprintf('  γ-Werte: ');
        fprintf('%.1f°  ', pvGamma(isAffectedRow));
        fprintf('\n');
    end

    % =====================================================================
    % Betroffene Zeilen in FitDataMod auf NaN setzen
    % =====================================================================
    nRemoved = 0;
    affectedRows = find(isAffectedRow);

    for ri = 1:numel(affectedRows)
        rowIdx   = affectedRows(ri);
        nColsFDM = size(h.FitDataMod{peakIdx}, 2);

        h.FitDataMod{peakIdx}(rowIdx, 2:3) = NaN;
        if nColsFDM >= 10
            h.FitDataMod{peakIdx}(rowIdx, 9:10)  = NaN;
        end
        if nColsFDM >= 12
            h.FitDataMod{peakIdx}(rowIdx, 11:12) = NaN;
        end

        nRemoved = nRemoved + 1;
        fprintf('  Zeile %d (γ=%.2f°): entfernt\n', rowIdx, pvGamma(rowIdx));
    end

    % pv lokal aktualisieren
    pv = h.FitDataMod{peakIdx};

    totalRemoved = totalRemoved + nRemoved;
    fprintf('  → %d Zeilen entfernt\n', nRemoved);

    % ── Hilfsdatenstrukturen synchronisieren ─────────────────────────────
    safeIdx = max(1, min(peakIdx, numel(h.dataXcorr)));
    
    for cellField = {'dataXcorr', 'dataYcorr', 'fitresultexport', ...
                     'dataPVFitY', 'datacentFitParams', 'datacentFitY'}
        fn = cellField{1};
        if isfield(h, fn) && numel(h.(fn)) >= safeIdx && ...
           ~isempty(h.(fn){safeIdx})
            nArr     = numel(h.(fn){safeIdx});
            validDel = affectedRows(affectedRows <= nArr);
            if ~isempty(validDel)
                h.(fn){safeIdx}(validDel) = {[]};
            end
        end
    end
    
    % dataPVFitMat / datacentFitMat synchronisieren
    if ~isempty(affectedRows)
        for matField = {'dataPVFitMat', 'datacentFitMat', 'FitDataModCentroid'}
            fn = matField{1};
            if isfield(h, fn) && numel(h.(fn)) >= peakIdx && ...
               ~isempty(h.(fn){peakIdx}) && ...
               size(h.(fn){peakIdx}, 1) >= max(affectedRows)
                h.(fn){peakIdx}(affectedRows, 2:3) = NaN;
            end
        end
    end
    
    % validBinIdxs aktualisieren
    if isfield(h, 'dataXcorr') && numel(h.dataXcorr) >= safeIdx
        dc        = h.dataXcorr{safeIdx};
        validIdxs = find(~cellfun(@isempty, dc));
        h.validBinIdxs{peakIdx} = validIdxs;
        nValid = numel(validIdxs);
        fprintf('  validBinIdxs aktualisiert: %d gültige Bins\n', nValid);
    end
end

fprintf('\nGesamt: %d Zeilen entfernt\n', totalRemoved);

% =====================================================================
% Plot aktualisieren
% =====================================================================
value = round(get(h.Slider, 'Value'));
value = max(1, min(value, size(h.FitDataMod, 1)));

pv_plot = h.FitDataMod{value};
[yColP, yErrColP, idxFinP] = getPlausibleCol(pv_plot);

if any(idxFinP)
    set(h.plotdata, ...
        'XData',          pv_plot(idxFinP, 1), ...
        'YData',          pv_plot(idxFinP, yColP), ...
        'YNegativeDelta', abs(pv_plot(idxFinP, yErrColP)), ...
        'YPositiveDelta', abs(pv_plot(idxFinP, yErrColP)), ...
        'Visible', 'on');

    yVals  = pv_plot(idxFinP, yColP);
    yErrs  = abs(pv_plot(idxFinP, yErrColP));
    yRange = max(max(yVals+yErrs) - min(yVals-yErrs), 0.02);
    h.axes.YLimMode = 'manual';
    h.axes.YLim     = [min(yVals-yErrs) - yRange*0.25, ...
                       max(yVals+yErrs) + yRange*0.25];
else
    set(h.plotdata, 'XData', NaN, 'YData', NaN, ...
        'YNegativeDelta', NaN, 'YPositiveDelta', NaN, 'Visible', 'off');
    h.axes.YLimMode = 'auto';
end

% SliderFittedPeaks anpassen
safeVal = max(1, min(value, numel(h.dataXcorr)));
if isfield(h, 'validBinIdxs') && numel(h.validBinIdxs) >= value && ...
   ~isempty(h.validBinIdxs{value})
    nValid = numel(h.validBinIdxs{value});
else
    nValid = sum(idxFinP);
end
nValid = max(nValid, 1);
set(h.SliderFittedPeaks, ...
    'Min',        1, ...
    'Max',        max(nValid, 2), ...
    'Value',      1, ...
    'SliderStep', [1/max(nValid-1,1)  1/max(nValid-1,1)]);

% Ersten gültigen Bin anzeigen
firstBinIdx = 1;
if isfield(h, 'BinnedGamma') && ~isempty(h.BinnedGamma) && ...
   isfield(h, 'validBinIdxs') && numel(h.validBinIdxs) >= value && ...
   ~isempty(h.validBinIdxs{value})
    firstBinIdx = h.validBinIdxs{value}(1);
end

h = updateFittedPeakPlot(h, safeVal, firstBinIdx);
h = markInvalidGammaRegions(h, value);

guidata(hObj, h);

uiwait(msgbox(sprintf('Fertig: %d Zeilen aus Detektormaske entfernt.', ...
    totalRemoved), 'Maske angewendet', 'modal'));
end