function filterpeakscallback(hObj, ~)
h = guidata(hObj);

if ~isfield(h, 'FitDataMod') || isempty(h.FitDataMod)
    errordlg('Bitte zuerst Track & Fit Peaks ausführen.', 'Keine Daten');
    return
end

valueSlider = round(get(h.Slider, 'Value'));

% =====================================================================
% Undo-State sichern
% =====================================================================
h.undoState.FitDataMod         = h.FitDataMod;
h.undoState.FitDataModCentroid = h.FitDataModCentroid;
h.undoState.dataPVFitMat       = h.dataPVFitMat;
h.undoState.datacentFitMat     = h.datacentFitMat;
h.undoState.fitresultexport    = h.fitresultexport;
h.undoState.dataXcorr          = h.dataXcorr;
h.undoState.dataYcorr          = h.dataYcorr;
h.undoState.valueSlider        = valueSlider;

% =====================================================================
% Filter-Dialog öffnen
% =====================================================================
[filtMask, h.trackFitOpts] = openPeakFilterDialog(h, valueSlider);

if isempty(filtMask) || ~any(filtMask)
    guidata(hObj, h);
    return
end

% =====================================================================
% Bin-Indizes VOR dem NaN-Setzen lesen (Spalte 8 = Original-Bin-Index)
% =====================================================================
binIndices = h.FitDataMod{valueSlider}(filtMask, 8);

% =====================================================================
% Gefilterte Punkte auf NaN setzen – NUR EINMAL
% =====================================================================
h.FitDataMod{valueSlider}(filtMask, 2:3)   = NaN;
h.FitDataMod{valueSlider}(filtMask, 9:10)  = NaN;
h.FitDataMod{valueSlider}(filtMask, 11:12) = NaN;

if isfield(h,'dataPVFitMat') && numel(h.dataPVFitMat) >= valueSlider
    h.dataPVFitMat{valueSlider}(filtMask, 2:3) = NaN;
end
if isfield(h,'datacentFitMat') && numel(h.datacentFitMat) >= valueSlider
    h.datacentFitMat{valueSlider}(filtMask, 2:3)   = NaN;
    h.datacentFitMat{valueSlider}(filtMask, 11:12) = NaN;
end
if isfield(h,'FitDataModCentroid') && numel(h.FitDataModCentroid) >= valueSlider
    h.FitDataModCentroid{valueSlider}(filtMask, 2:3) = NaN;
end

% =====================================================================
% dataXcorr / dataYcorr / fitresultexport über Bin-Indizes bereinigen
% WICHTIG: leere Zellen NICHT entfernen – Indexkorrespondenz erhalten
% =====================================================================
if numel(h.dataXcorr) >= valueSlider
    validBins  = numel(h.dataXcorr{valueSlider});
    idxToClear = binIndices(binIndices >= 1 & binIndices <= validBins);
    h.dataXcorr{valueSlider}(idxToClear)       = {[]};
    h.dataYcorr{valueSlider}(idxToClear)       = {[]};
    h.fitresultexport{valueSlider}(idxToClear) = {[]};
end
if isfield(h,'dataPVFitY') && numel(h.dataPVFitY) >= valueSlider
    validBins  = numel(h.dataPVFitY{valueSlider});
    idxToClear = binIndices(binIndices >= 1 & binIndices <= validBins);
    h.dataPVFitY{valueSlider}(idxToClear) = {[]};
end
if isfield(h,'datacentFitY') && numel(h.datacentFitY) >= valueSlider
    validBins  = numel(h.datacentFitY{valueSlider});
    idxToClear = binIndices(binIndices >= 1 & binIndices <= validBins);
    h.datacentFitY{valueSlider}(idxToClear) = {[]};
end
if isfield(h,'datacentFitParams') && numel(h.datacentFitParams) >= valueSlider
    validBins  = numel(h.datacentFitParams{valueSlider});
    idxToClear = binIndices(binIndices >= 1 & binIndices <= validBins);
    h.datacentFitParams{valueSlider}(idxToClear) = {[]};
end

% =====================================================================
% Undo-Button aktivieren
% =====================================================================
if isfield(h,'UndoStressButton') && isvalid(h.UndoStressButton)
    set(h.UndoStressButton, 'Enable', 'on');
end

% =====================================================================
% validBinIdxs aktualisieren – Mapping Slider → absoluter Bin-Index
% =====================================================================
dc        = h.dataXcorr{valueSlider};
validIdxs = find(~cellfun(@isempty, dc));
nValid    = numel(validIdxs);
h.validBinIdxs{valueSlider} = validIdxs;

% =====================================================================
% plotdata aktualisieren (alle Punkte inkl. NaN für korrekte Indizes)
% =====================================================================
pv = h.FitDataMod{valueSlider};
set(h.plotdata, ...
    'XData',          pv(:,1), ...
    'YData',          pv(:,2), ...
    'YNegativeDelta', abs(pv(:,3)), ...
    'YPositiveDelta', abs(pv(:,3)), ...
    'Visible', 'on');

% plotdataCentFit aktualisieren
if isfield(h,'datacentFitMat') && numel(h.datacentFitMat) >= valueSlider
    cf    = h.datacentFitMat{valueSlider};
    idxCF = isfinite(cf(:,2));
    if isfield(h,'plotdataCentFit') && isvalid(h.plotdataCentFit)
        showCent = isfield(h,'cb_showCentroid') && get(h.cb_showCentroid,'Value') == 1;
        if any(idxCF) && showCent
            set(h.plotdataCentFit, ...
                'XData',          cf(idxCF,1), ...
                'YData',          cf(idxCF,2), ...
                'YNegativeDelta', cf(idxCF,3), ...
                'YPositiveDelta', cf(idxCF,3), ...
                'Visible', 'on');
        else
            set(h.plotdataCentFit, 'Visible', 'off');
        end
    end
end

% =====================================================================
% Slider neu konfigurieren – läuft von 1..nValid
% =====================================================================
if nValid < 1
    set(h.SliderFittedPeaks, 'Min', 1, 'Max', 2, 'Value', 1, 'SliderStep', [1 1]);
    guidata(hObj, h);
    return
end

set(h.SliderFittedPeaks, ...
    'Min',        1, ...
    'Max',        max(nValid, 2), ...
    'Value',      1, ...
    'SliderStep', [1/max(nValid-1,1)  1/max(nValid-1,1)]);

% =====================================================================
% updateFittedPeakPlot mit erstem gültigen absoluten Bin-Index
% =====================================================================
firstAbsBin = validIdxs(1);
h = updateFittedPeakPlot(h, valueSlider, firstAbsBin);

% =====================================================================
% highlightpeakdata auf ersten gültigen Punkt in FitDataMod setzen
% =====================================================================
idxPV = isfinite(pv(:,2));
if any(idxPV)
    firstValidRow = find(idxPV, 1, 'first');
    set(h.highlightpeakdata, ...
        'XData',   pv(firstValidRow, 1), ...
        'YData',   pv(firstValidRow, 2), ...
        'Visible', 'on');
else
    set(h.highlightpeakdata, 'Visible', 'off');
end

fprintf('[filterpeakscallback] %d Punkte gefiltert (Peak %d)\n', ...
    sum(filtMask), valueSlider);

guidata(hObj, h);
end