function h = runBinning(h, outCell)

% Rückwärtskompatibilität: einzelnes out → in Cell verpacken
if ~iscell(outCell)
    outCell = {outCell};
end

chiMin          = str2double(get(h.trackChiRangeMinEdit, 'String'));
chiMax          = str2double(get(h.trackChiRangeMaxEdit, 'String'));
trackChiBin     = max(1, round(str2double(get(h.trackChiBinEdit,     'String'))));
trackChiAvgBins = max(0, round(str2double(get(h.trackChiAvgBinsEdit, 'String'))));
smoothPts       = max(1, round(str2double(get(h.smoothPointsEdit,    'String'))));
baselineModeList = get(h.baselineModePopup, 'String');
baselineMode     = baselineModeList{get(h.baselineModePopup, 'Value')};

if isfield(h, 'trackFitOpts')
    opts = h.trackFitOpts;
else
    opts = struct();
end
opts.profileChiRange = [chiMin chiMax];
opts.trackChiRange   = [chiMin chiMax];
opts.trackChiBin     = trackChiBin;
opts.trackChiAvgBins = trackChiAvgBins;
opts.centroidKBins   = 12;
opts.smoothPoints    = smoothPts;
opts.baselineMode    = baselineMode;

nAlpha = numel(outCell);

for k = 1:nAlpha

    % ── Binning ───────────────────────────────────────────────────────
    try
        B = pyfai_extract_binned_tracking_data(outCell{k}, opts);
    catch ME
        errordlg(sprintf('Binning failed für alpha %d:\n%s', k, ME.message), ...
            'Binning Error');
        return
    end

    h.dataX{k}             = double(B.radial(:));
    h.IntensityProfiles{k} = double(B.track.rawProfiles);

    % Gamma-Werte speichern
    gamma_raw           = double(B.gamma_deg(:))';
    % ── NEU: chi > 90° auf negativen Bereich umrechnen ───────────────────
    % chi = +121° → chi - 360° = -239° → gleicher physikalischer Winkel
    % Erweitert den nutzbaren γ-Bereich um Daten von Bild 2
    gamma_raw(gamma_raw > 90) = gamma_raw(gamma_raw > 90) - 360;

    h.BinnedGamma{k}    = gamma_raw + 90;
    h.BinnedGammaRaw{k} = gamma_raw;

    % pyfaiOut pro Gruppe speichern
    h.pyfaiOutPerAlpha{k} = outCell{k};

    % ── Validitätsmaske ───────────────────────────────────────────────
    % Strategie: Bin ist ungültig wenn er INSGESAMT kein Signal hat.
    % Partielle Abschattung bei kleinen 2theta ist KEIN Ausschlussgrund,
    % solange im Peak-Bereich (höhere 2theta) Signal vorhanden ist.
    out_k   = outCell{k};
    azimAll = double(out_k.azimuthal(:));   % [npt_azim x 1], unverschoben
    nBins   = numel(gamma_raw);
    halfWin = trackChiAvgBins;
    nAzim   = numel(azimAll);

    % chi-Indizes: gamma_raw direkt gegen azimAll suchen
    % chiIdxUsed = zeros(1, nBins);
    % for bn = 1:nBins
    %     [~, chiIdxUsed(bn)] = min(abs(azimAll - gamma_raw(bn)));
    % end
    % chi-Indizes: gamma_raw direkt gegen azimAll suchen
    chiIdxUsed = zeros(1, nBins);
    for bn = 1:nBins
        gr = gamma_raw(bn);
        if gr < -180, gr = gr + 360; end
        if gr >  180, gr = gr - 360; end
        [~, chiIdxUsed(bn)] = min(abs(azimAll - gr));
    end

    if isfield(out_k, 'I') && ~isempty(out_k.I) && ...
       isfield(out_k, 'radial') && ~isempty(out_k.radial)

        I_mat     = double(out_k.I);         % [npt_azim x npt_rad]
        radialAll = double(out_k.radial(:)); % [npt_rad x 1]

        % Referenzprofil: Median über ALLE chi-Bins
        % Zeigt wo der Detektor grundsätzlich Signal liefert
        I_ref        = median(I_mat, 1, 'omitnan');   % [1 x npt_rad]
        globalMedian = median(I_ref(I_ref > 0), 'omitnan');

        if isnan(globalMedian) || globalMedian <= 0
            fprintf('  Alpha %d: globalMedian=0 — alle Bins gültig.\n', k);
            validBin = true(1, nBins);
        else
            % Schwellenwert: Bin hat Signal wenn sein Median
            % > 1% des globalen Medians
            intensThresh = 0.01 * globalMedian;

            fprintf('    globalMedian=%.0f  intensThresh=%.0f\n', ...
                globalMedian, intensThresh);

            validBin = false(1, nBins);
            for bn = 1:nBins
                chiIdx   = chiIdxUsed(bn);
                idxRange = max(1, chiIdx-halfWin) : min(nAzim, chiIdx+halfWin);

                % Gemitteltes Intensitätsprofil dieses Bins
                I_row = mean(I_mat(idxRange, :), 1, 'omitnan');

                % Median NUR über Kanäle mit positivem Signal
                posVals   = I_row(I_row > 0);
                binMedian = median(posVals, 'omitnan');

                if isnan(binMedian)
                    validBin(bn) = false;
                else
                    validBin(bn) = binMedian >= intensThresh;
                end

                binMed_disp = binMedian;
                if isnan(binMed_disp), binMed_disp = 0; end
                fprintf('    γ=%6.1f°  chiIdx=%d  azim=%6.1f°  binMedian=%10.0f  → %s\n', ...
                    gamma_raw(bn), chiIdx, azimAll(chiIdx), ...
                    binMed_disp, mat2str(validBin(bn)));
            end
        end

    elseif isfield(out_k, 'valid_fraction') && ~isempty(out_k.valid_fraction)
        % Fallback: valid_fraction global
        fprintf('  Alpha %d: kein I-Feld — Fallback auf valid_fraction\n', k);
        validFraction = double(out_k.valid_fraction);
        validBin = false(1, nBins);
        for bn = 1:nBins
            chiIdx   = chiIdxUsed(bn);
            idxRange = max(1, chiIdx-halfWin) : min(nAzim, chiIdx+halfWin);
            validBin(bn) = mean(mean(validFraction(idxRange, :))) >= 0.10;
        end

    else
        fprintf('  Alpha %d: keine Maske — alle Bins gültig.\n', k);
        validBin = true(1, nBins);
    end

    h.BinnedGammaValid{k} = validBin;

    % ── Debug-Ausgabe ─────────────────────────────────────────────────
    fprintf('  Alpha-Gruppe %d: %d/%d Bins valide\n', k, sum(validBin), nBins);
    if any(~validBin)
        fprintf('  Ungültige γ-Bins (raw): ');
        fprintf('%.1f°  ', gamma_raw(~validBin));
        fprintf('\n');
        changes = diff([true, validBin, true]);
        inv_st  = find(changes == -1);
        inv_end = find(changes ==  1) - 1;
        fprintf('  Ungültige Bereiche (verschoben +90°):\n');
        for ii = 1:numel(inv_st)
            fprintf('    γ=%.1f° .. %.1f°\n', ...
                h.BinnedGamma{k}(inv_st(ii)), ...
                h.BinnedGamma{k}(inv_end(ii)));
        end
    end

end % for k

% ── dataXBackup / BinSize ─────────────────────────────────────────────
h.dataXBackup = h.dataX;
h.BinSize     = trackChiBin;

% ── dataXPlot / dataYPlot aufbauen ───────────────────────────────────
dataX_expanded = cell(1, nAlpha);
for i = 1:nAlpha
    nCols = size(h.IntensityProfiles{i}, 2);
    dataX_expanded{i} = repmat(h.dataX{i}, 1, nCols);
end

h.dataXPlot       = cell2mat(dataX_expanded);
h.dataXPlotBackup = h.dataXPlot;
h.dataY           = h.IntensityProfiles;
h.dataYPlot       = cell2mat(h.IntensityProfiles);
h.dataYPlotBackup = h.dataYPlot;

% ── Slider ───────────────────────────────────────────────────────────
totalProfiles = sum(cellfun(@(x) size(x,2), h.IntensityProfiles));
set(h.Slider, 'Min', 1, 'Max', max(totalProfiles, 2), 'Value', 1);
step = 1 / max(totalProfiles-1, 1);
set(h.Slider, 'SliderStep', [step step]);

set(h.plotIntensityData, 'XData', h.dataXPlot(:,1), ...
    'YData', h.dataYPlot(:,1), 'Visible', 'on');
set(h.axesPlotIntensityData, 'XLimMode', 'auto');

% ── Theoretische Peaks ───────────────────────────────────────────────
if isfield(h, 'PeaksTheo')
    for k = 1:size(h.PeaksTheo, 2)
        PeakPostmp = mean(h.PeaksTheo{k}.Peaks(:, 5:6), 2)';
        idx        = (PeakPostmp >= round(min(h.dataX{1}))) & ...
                     (PeakPostmp <= round(max(h.dataX{1})));
        PeakPos{k} = PeakPostmp(idx);
        hkl{k}     = h.PeaksTheo{k}.Peaks(idx, 1:3);
        for i = 1:size(hkl{k}, 1)
            rowsAsStrings{k}{i} = strtrim(sprintf('%g %g %g', hkl{k}(i,:)));
        end
        hkltabledata{k} = [hkl{k} PeakPos{k}' zeros(length(PeakPos{k}), 2)];
    end
    h.PeakPos       = PeakPos;
    h.rowsAsStrings = rowsAsStrings;

    if isfield(h, 'plotpeakstheo'), delete(h.plotpeakstheo); end
    h.plotpeakstheo = xline(h.axesPlotIntensityData, ...
        h.PeakPos{1}, '--r', h.rowsAsStrings{1}, ...
        'LabelVerticalAlignment',   'middle', ...
        'LabelHorizontalAlignment', 'left');

    dekHandles = {h.dekdataGaKalpha, h.dekdataInKalpha, h.dekdataInKbeta};
    for ti = 1:3
        currentData = get(dekHandles{ti}, 'Data');
        hasS1S2 = false;
        if ~isempty(currentData) && size(currentData, 2) >= 6
            if iscell(currentData)
                for ri = 1:size(currentData, 1)
                    for ci = 5:6
                        val = currentData{ri, ci};
                        if isnumeric(val) && isscalar(val) && ...
                           isfinite(val) && val ~= 0
                            hasS1S2 = true; break
                        end
                    end
                    if hasS1S2, break; end
                end
            elseif isnumeric(currentData)
                s1s2    = currentData(:, 5:6);
                hasS1S2 = any(s1s2(:) ~= 0 & isfinite(s1s2(:)));
            end
        end
        if ~hasS1S2
            set(dekHandles{ti}, 'data', hkltabledata{ti});
        end
    end
end

% ── Zusammenfassung ───────────────────────────────────────────────────
fprintf('\n── Binning Ergebnis ─────────────────────────────────────\n');
fprintf('Chi-Bereich:     [%.1f°, %.1f°]\n', chiMin, chiMax);
fprintf('trackChiBin:     %d\n', trackChiBin);
fprintf('trackChiAvgBins: %d\n', trackChiAvgBins);
fprintf('\n');

for k = 1:nAlpha
    gamma = h.BinnedGamma{k};
    fprintf('Alpha-Gruppe %d:\n', k);
    fprintf('  Anzahl γ-Bins:  %d\n',   numel(gamma));
    fprintf('  γ-Bereich:      [%.2f°, %.2f°]\n', min(gamma), max(gamma));
    fprintf('  γ-Schrittweite: %.3f° (Mittel)\n', mean(diff(sort(gamma))));
    fprintf('  γ-Schrittweite: %.3f° (min) / %.3f° (max)\n', ...
        min(diff(sort(gamma))), max(diff(sort(gamma))));
    fprintf('  Valide Bins:    %d/%d\n', ...
        sum(h.BinnedGammaValid{k}), numel(h.BinnedGammaValid{k}));
end
fprintf('────────────────────────────────────────────────────────\n\n');

h.plottab.SelectedTab = h.plottab4;

fprintf('Binning abgeschlossen: %d Alpha-Gruppe(n), %d Profile gesamt, chi=[%.0f, %.0f]°\n', ...
    nAlpha, totalProfiles, chiMin, chiMax);
end