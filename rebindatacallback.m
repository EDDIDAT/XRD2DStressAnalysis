function rebindatacallback(hObj, ~)
h = guidata(hObj);

if ~isfield(h, 'pyfaiOut') || isempty(h.pyfaiOut)
    errordlg('Bitte zuerst PONI-Files laden.', 'Kein pyFAI-Output');
    return
end

col = get(hObj, 'backg');
set(hObj, 'String', 'Rebinning ...', 'backg', [1 .6 .6]);
pause(0.01);

% ── DEC-Tabellendaten VOR Rebin sichern ──────────────────────────────
decBackup.tableDECFittedPeaks = get(h.tableDECFittedPeaks, 'Data');
decBackup.dekdataGaKalpha     = get(h.dekdataGaKalpha,     'Data');
decBackup.dekdataInKalpha     = get(h.dekdataInKalpha,     'Data');
decBackup.dekdataInKbeta      = get(h.dekdataInKbeta,      'Data');
if isfield(h, 'DEKdataMatchedPeaks')
    decBackup.DEKdataMatchedPeaks = h.DEKdataMatchedPeaks;
end
if isfield(h, 'PeakPos')
    decBackup.PeakPos       = h.PeakPos;
    decBackup.rowsAsStrings = h.rowsAsStrings;
end
% Fit-Ergebnisse sichern (falls bereits gefittet wurde)
if isfield(h, 'FitDataMod')
    decBackup.FitDataMod = h.FitDataMod;
end
if isfield(h, 'FitDataRaw')
    decBackup.FitDataRaw = h.FitDataRaw;
end
if isfield(h, 'fitresultexport')
    decBackup.fitresultexport = h.fitresultexport;
end

% ── Rebin durchführen ─────────────────────────────────────────────────

% ── caked_mask aus h.pyfaiOut übertragen falls vorhanden ─────────────
% h.pyfaiOut enthält die Alpha-spezifischen Outputs
% Die caked_mask wurde nur für den kombinierten out berechnet
% → aus dem ersten Alpha-Output oder aus gespeicherter Datei laden
for ka = 1:numel(h.pyfaiOutPerAlpha)
    if ~isfield(h.pyfaiOutPerAlpha{ka}, 'caked_mask') || ...
       isempty(h.pyfaiOutPerAlpha{ka}.caked_mask)
        % Versuche caked_mask aus MAT-Datei zu laden
        if isfield(h.pyfaiOutPerAlpha{ka}, 'matPath')
            matPath     = h.pyfaiOutPerAlpha{ka}.matPath;
            maskMatPath = strrep(matPath, '.mat', '_caked_mask.mat');
            if exist(maskMatPath, 'file')
                try
                    maskData = load(maskMatPath);
                    h.pyfaiOutPerAlpha{ka}.caked_mask     = maskData.caked_mask;
                    h.pyfaiOutPerAlpha{ka}.valid_fraction = maskData.valid_fraction;
                    fprintf('  caked_mask geladen: %s\n', maskMatPath);
                catch ME
                    warning('[Rebin] caked_mask laden: %s', strrep(ME.message, '%', '%%'));
                end
            end
        end
    end
end

h = runBinning(h, h.pyfaiOutPerAlpha);

% ── DEC-Tabellendaten NACH Rebin wiederherstellen ─────────────────────
% Nur wiederherstellen wenn die Tabelle nicht leer war
if ~isempty(decBackup.tableDECFittedPeaks) && ...
   hasNonZeroData(decBackup.tableDECFittedPeaks)
    set(h.tableDECFittedPeaks, 'Data', decBackup.tableDECFittedPeaks);
end

% DEK-Tabellen nur wiederherstellen wenn S1/S2-Werte bereits eingetragen
% waren (Spalten 5+6 nicht alle Null)
% dekFields = {'dekdataGaKalpha', 'dekdataInKalpha', 'dekdataInKbeta'};
dekTables = {'dekdataGaKalpha', 'dekdataInKalpha', 'dekdataInKbeta'};
for ti = 1:3
    bakData = decBackup.(dekTables{ti});
    if ~isempty(bakData) && size(bakData, 2) >= 6
        if iscell(bakData)
            s1s2subset = bakData(:, 5:6);
        else
            s1s2subset = num2cell(bakData(:, 5:6));
        end
        if hasNonZeroData(s1s2subset)
            set(h.(dekTables{ti}), 'Data', bakData);
        end
    end
end

if isfield(decBackup, 'DEKdataMatchedPeaks')
    h.DEKdataMatchedPeaks = decBackup.DEKdataMatchedPeaks;
end

% Fit-Ergebnisse wiederherstellen
if isfield(decBackup, 'FitDataMod')
    h.FitDataMod = decBackup.FitDataMod;
end
if isfield(decBackup, 'FitDataRaw')
    h.FitDataRaw = decBackup.FitDataRaw;
end
if isfield(decBackup, 'fitresultexport')
    h.fitresultexport = decBackup.fitresultexport;
end

set(hObj, 'String', 'Rebin Data', 'backg', col);
guidata(hObj, h);
end