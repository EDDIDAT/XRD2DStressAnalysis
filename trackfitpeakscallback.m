function trackfitpeakscallback(hObj, ~)
h = guidata(hObj);

% --- Voraussetzungen prüfen ---
if ~isfield(h, 'pyfaiOut') || isempty(h.pyfaiOut)
    errordlg('Bitte zuerst PONI-Files laden (pyFAI-Output fehlt).', 'Kein pyFAI-Output');
    return
end
if ~isfield(h, 'UserPeaks') || isempty(h.UserPeaks)
    errordlg('Bitte zuerst Peaks definieren (Define peaks).', 'Keine Peaks definiert');
    return
end

% --- opts aufbauen ---
if isfield(h, 'trackFitOpts')
    opts = h.trackFitOpts;
else
    opts = openTrackFitSettings();
    h.trackFitOpts = opts;
end

chiMin = str2double(get(h.trackChiRangeMinEdit, 'String'));
chiMax = str2double(get(h.trackChiRangeMaxEdit, 'String'));
opts.profileChiRange = [chiMin chiMax];
opts.trackChiRange   = [chiMin chiMax];
opts.trackChiBin     = max(1, round(str2double(get(h.trackChiBinEdit,     'String'))));
opts.trackChiAvgBins = max(0, round(str2double(get(h.trackChiAvgBinsEdit, 'String'))));
opts.smoothPoints    = max(1, round(str2double(get(h.smoothPointsEdit,    'String'))));

if isfield(opts, 'centroidKBins')
    centroidKBins = opts.centroidKBins;
else
    centroidKBins = 12;
end

baselineModeList  = get(h.baselineModePopup, 'String');
opts.baselineMode = baselineModeList{get(h.baselineModePopup, 'Value')};
opts.baselineWin  = 51;
opts.useLog       = false;
opts.doPlot       = false;
opts.plotFits     = false;

col = get(hObj, 'backg');
set(hObj, 'String', 'Tracking peaks ...', 'backg', [1 .6 .6]);
pause(0.01);

% --- Rohprofile + gamma-Achse via pyfai_peak_tracking_compare_methods ---
nPeaks = numel(h.UserPeaks);
[uniqueAlpha, ~, ~] = unique(h.alpha);
nAlpha = numel(uniqueAlpha);
out    = h.pyfaiOut;

allRes = cell(nPeaks, 1);
for p = 1:nPeaks
    peakGuess = h.UserPeaks(p);
    set(hObj, 'String', sprintf('Tracking peak %d/%d ...', p, nPeaks));
    drawnow;
    try
        allRes{p} = pyfai_peak_tracking_compare_methods(out, peakGuess, opts);
    catch ME
        warning('[trackfit] Peak %d (%.4f°) fehlgeschlagen: %s', p, peakGuess, ME.message);
        allRes{p} = [];
    end
end

h.trackFitResults = allRes;

% =====================================================================
% Datenstruktur aufbauen
% Peaklagen kommen ausschliesslich aus:
%   fitPseudoVoigt → Spalten 9+10  (Standard in Sp. 2+3)
%   fitCentroid    → Spalten 11+12
%   R²             → Spalte 13
% =====================================================================
FitDataMod         = cell(nPeaks * nAlpha, 1);
FitDataModCentroid = cell(nPeaks * nAlpha, 1);
fitresultexport    = cell(nPeaks * nAlpha, 1);
dataXcorr          = cell(nPeaks * nAlpha, 1);
dataYcorr          = cell(nPeaks * nAlpha, 1);
fitMethodUsed      = cell(nPeaks * nAlpha, 1);
dataCentroidMu     = cell(nPeaks * nAlpha, 1);
dataGaussFit       = cell(nPeaks * nAlpha, 1);
dataPVParams       = cell(nPeaks * nAlpha, 1);
dataPVErrors       = cell(nPeaks * nAlpha, 1);
dataPVFitY         = cell(nPeaks * nAlpha, 1);
dataPVSuccess      = cell(nPeaks * nAlpha, 1);
datacentFitParams  = cell(nPeaks * nAlpha, 1);
datacentFitErrors  = cell(nPeaks * nAlpha, 1);
datacentFitY       = cell(nPeaks * nAlpha, 1);
datacentFitSuccess = cell(nPeaks * nAlpha, 1);
dataPVFitMat       = cell(nPeaks * nAlpha, 1);
datacentFitMat     = cell(nPeaks * nAlpha, 1);

cellIdx = 1;

for p = 1:nPeaks
    res = allRes{p};

    for a = 1:nAlpha
        alphaVal = uniqueAlpha(a);

        if isempty(res)
            FitDataMod{cellIdx}         = zeros(0, 13);
            FitDataModCentroid{cellIdx} = zeros(0, 13);
            fitresultexport{cellIdx}    = {};
            dataXcorr{cellIdx}          = {};
            dataYcorr{cellIdx}          = {};
            fitMethodUsed{cellIdx}      = logical([]);
            dataCentroidMu{cellIdx}     = {};
            dataGaussFit{cellIdx}       = {};
            dataPVParams{cellIdx}       = {};
            dataPVErrors{cellIdx}       = {};
            dataPVFitY{cellIdx}         = {};
            dataPVSuccess{cellIdx}      = logical([]);
            datacentFitParams{cellIdx}  = {};
            datacentFitErrors{cellIdx}  = {};
            datacentFitY{cellIdx}       = {};
            datacentFitSuccess{cellIdx} = logical([]);
            cellIdx = cellIdx + 1;
            continue
        end

        % valid aus Centroid-Tracking (robuster als pVoigt-Tracking)
        valid  = res.centroid.valid;
        gamma  = res.gamma_deg(valid) + 90;
        amp    = res.centroid.amp(valid);
        nValid = sum(valid);

        fitStoreValid = res.fitStore(valid);

        % Alle numerischen Felder auf double konvertieren
        for i = 1:numel(fitStoreValid)
            fn = fieldnames(fitStoreValid(i));
            for f = 1:numel(fn)
                v = fitStoreValid(i).(fn{f});
                if isnumeric(v) && ~isa(v, 'double')
                    fitStoreValid(i).(fn{f}) = double(v);
                end
            end
        end

        xCorrCell    = cell(nValid, 1);
        yCorrCell    = cell(nValid, 1);
        fitResCell   = cell(nValid, 1);
        usedPvoigt   = false(nValid, 1);
        centroidMu   = cell(nValid, 1);
        gaussResCell = cell(nValid, 1);

        pvParams  = cell(nValid, 1);
        pvErrors  = cell(nValid, 1);
        pvFitY    = cell(nValid, 1);
        pvSuccess = false(nValid, 1);
        pvFwhm    = nan(nValid, 1);
        pvEta     = nan(nValid, 1);
        pvR2      = nan(nValid, 1);

        centFitParams  = cell(nValid, 1);
        centFitErrors  = cell(nValid, 1);
        centFitY       = cell(nValid, 1);
        centFitSuccess = false(nValid, 1);

        for i = 1:nValid
            fs = fitStoreValid(i);

            xCorrCell{i} = fs.r;
            yCorrCell{i} = fs.yproc;

            % Startwert
            if isfield(fs,'x_centroid') && ~isempty(fs.x_centroid) && isfinite(fs.x_centroid)
                centroidMu{i} = fs.x_centroid;
                x0_for_fits   = fs.x_centroid;
            elseif isfield(fs,'x_pvoigt') && ~isempty(fs.x_pvoigt) && isfinite(fs.x_pvoigt)
                centroidMu{i} = fs.x_pvoigt;
                x0_for_fits   = fs.x_pvoigt;
            else
                centroidMu{i} = NaN;
                x0_for_fits   = median(fs.r);
            end

            % Gauss aus Tracking (nur Visualisierung)
            if isfield(fs,'xfit_gauss') && ~isempty(fs.xfit_gauss)
                xg = fs.xfit_gauss; yg = fs.yfit_gauss;
                gaussResCell{i} = @(xdata) interp1(xg, yg, xdata, 'linear', 0);
            else
                gaussResCell{i} = @(xdata) zeros(size(xdata));
            end

            % =========================================================
            % fitPseudoVoigt – Spalten 9+10
            % =========================================================
            try
                [pvParams{i}, pvErrors{i}, yfit_pv, pvR2(i)] = ...
                    fitPseudoVoigt(fs.r, fs.yproc, x0_for_fits);
                xpv = fs.r(:); ypv = yfit_pv(:);
                pvFitY{i}     = @(xdata) interp1(xpv, ypv, xdata, 'linear', 'extrap');
                pvSuccess(i)  = true;
                fitResCell{i} = pvFitY{i};
                usedPvoigt(i) = true;
                if isfield(pvParams{i}, 'fwhm') && isfinite(pvParams{i}.fwhm)
                    pvFwhm(i) = pvParams{i}.fwhm;
                end
                if isfield(pvParams{i}, 'eta') && isfinite(pvParams{i}.eta)
                    pvEta(i) = pvParams{i}.eta;
                end
            catch ME
                warning('[trackfit] fitPseudoVoigt Bin %d: %s', i, ME.message);
                pvParams{i}   = [];  pvErrors{i}  = [];
                pvFitY{i}     = [];  pvSuccess(i) = false;
                fitResCell{i} = @(xdata) zeros(size(xdata));
                usedPvoigt(i) = false;
            end

            % =========================================================
            % fitCentroid – Spalten 11+12
            % =========================================================
            try
                cOpts.kBins        = centroidKBins;
                cOpts.baselineMode = 'minval';
                cOpts.nBootstrap   = 200;
                cOpts.smoothPoints = opts.smoothPoints;
                cOpts.verbose      = false;

                [centFitParams{i}, centFitErrors{i}, ycent] = ...
                    fitCentroid(fs.r, fs.yproc, x0_for_fits, cOpts);
                xc = fs.r(:); yc = ycent(:);
                centFitY{i}       = @(xdata) interp1(xc, yc, xdata, 'linear', 'extrap');
                centFitSuccess(i) = true;
            catch ME
                warning('[trackfit] fitCentroid Bin %d: %s', i, ME.message);
                centFitParams{i}  = [];  centFitErrors{i}  = [];
                centFitY{i}       = [];  centFitSuccess(i) = false;
            end
        end

        % Nur Bins behalten wo mindestens ein Fit erfolgreich
        idxKeep = pvSuccess | centFitSuccess;
        gamma          = gamma(idxKeep);
        amp            = amp(idxKeep);
        usedPvoigt     = usedPvoigt(idxKeep);
        xCorrCell      = xCorrCell(idxKeep);
        yCorrCell      = yCorrCell(idxKeep);
        fitResCell     = fitResCell(idxKeep);
        nKept          = sum(idxKeep);
        centroidMu     = centroidMu(idxKeep);
        gaussResCell   = gaussResCell(idxKeep);
        pvParams       = pvParams(idxKeep);
        pvErrors       = pvErrors(idxKeep);
        pvFitY         = pvFitY(idxKeep);
        pvSuccess      = pvSuccess(idxKeep);
        pvFwhm         = pvFwhm(idxKeep);
        pvEta          = pvEta(idxKeep);
        pvR2           = pvR2(idxKeep);
        centFitParams  = centFitParams(idxKeep);
        centFitErrors  = centFitErrors(idxKeep);
        centFitY       = centFitY(idxKeep);
        centFitSuccess = centFitSuccess(idxKeep);

        % x0 aus fitPseudoVoigt (Sp. 9+10)
        x0_fitPV    = nan(nKept, 1);
        x0err_fitPV = nan(nKept, 1);
        for i = 1:nKept
            if pvSuccess(i) && ~isempty(pvParams{i})
                x0_fitPV(i)    = pvParams{i}.x0;
                x0err_fitPV(i) = pvErrors{i}.x0;
            end
        end

        % x0 aus fitCentroid (Sp. 11+12)
        x0_centFit    = nan(nKept, 1);
        x0err_centFit = nan(nKept, 1);
        for i = 1:nKept
            if centFitSuccess(i) && ~isempty(centFitParams{i})
                x0_centFit(i)    = centFitParams{i}.x0;
                x0err_centFit(i) = centFitErrors{i}.x0;
            end
        end

        % Haupt-Matrix aufbauen (Sp. 2+3 = fitPseudoVoigt als Standard)
        mat = [gamma, x0_fitPV, x0err_fitPV, amp, pvFwhm, pvEta, ...
               repmat(alphaVal, nKept, 1), (1:nKept)', ...
               x0_fitPV, x0err_fitPV, ...    % Sp. 9+10
               x0_centFit, x0err_centFit, ...% Sp. 11+12
               pvR2];                        % Sp. 13

        % =====================================================================
        % R²-Filter mit Centroid-Fallback
        % MUSS vor matPVFit/matCentFit-Aufbau stehen damit NaN-Werte
        % in beide Matrizen übernommen werden
        % =====================================================================
        minR2 = 0.85;
        if isfield(opts, 'pvMinR2Auto') && isfinite(opts.pvMinR2Auto) && opts.pvMinR2Auto > 0
            minR2 = opts.pvMinR2Auto;
        end

        nFallback = 0;
        nFiltered = 0;

        for i = 1:nKept
            r2_pv   = pvR2(i);
            pv_ok   = isfinite(r2_pv) && r2_pv >= minR2;
            cent_ok = isfinite(x0_centFit(i));

            if ~pv_ok
                if cent_ok
                    % Centroid als Fallback: Sp. 9+10 mit Centroid-Werten füllen
                    mat(i, 9)  = x0_centFit(i);
                    mat(i, 10) = x0err_centFit(i);
                    mat(i, 2)  = x0_centFit(i);
                    mat(i, 3)  = x0err_centFit(i);
                    nFallback  = nFallback + 1;
                else
                    % Weder pVoigt noch Centroid verwertbar – alles NaN
                    mat(i, 2:3)   = NaN;
                    mat(i, 9:10)  = NaN;
                    mat(i, 11:12) = NaN;   % Centroid ebenfalls löschen
                    nFiltered = nFiltered + 1;
                end
            end
        end

        if nFallback > 0 || nFiltered > 0
            fprintf('  [R²-Filter Peak %d, alpha=%.0f] %d Centroid-Fallback, %d gefiltert (R² < %.2f)\n', ...
                p, alphaVal, nFallback, nFiltered, minR2);
        end

        % =====================================================================
        % Matrizen aufbauen – NACH dem R²-Filter damit NaN-Werte übernommen
        % =====================================================================

        % FitDataMod: Sp. 2+3 = fitPseudoVoigt (mit Centroid-Fallback)
        matPvoigt = mat;
        matPvoigt(~isfinite(mat(:,2)), 2:3) = NaN;

        % FitDataModCentroid: Sp. 2+3 = fitCentroid
        matCentroid      = mat;
        matCentroid(:,2) = mat(:,11);
        matCentroid(:,3) = mat(:,12);
        matCentroid(~isfinite(mat(:,11)), 2:3) = NaN;

        % matPVFit: explizite fitPseudoVoigt-Matrix
        matPVFit = mat;
        matPVFit(:,2) = mat(:,9);
        matPVFit(:,3) = mat(:,10);
        matPVFit(~isfinite(mat(:,9)), 2:3) = NaN;

        % matCentFit: explizite fitCentroid-Matrix
        matCentFit = mat;
        matCentFit(:,2) = mat(:,11);
        matCentFit(:,3) = mat(:,12);
        matCentFit(~isfinite(mat(:,11)), 2:3) = NaN;

        FitDataMod{cellIdx}         = matPvoigt;
        FitDataModCentroid{cellIdx} = matCentroid;
        fitresultexport{cellIdx}    = fitResCell;
        dataXcorr{cellIdx}          = xCorrCell;
        dataYcorr{cellIdx}          = yCorrCell;
        fitMethodUsed{cellIdx}      = usedPvoigt;
        dataCentroidMu{cellIdx}     = centroidMu;
        dataGaussFit{cellIdx}       = gaussResCell;
        dataPVParams{cellIdx}       = pvParams;
        dataPVErrors{cellIdx}       = pvErrors;
        dataPVFitY{cellIdx}         = pvFitY;
        dataPVSuccess{cellIdx}      = pvSuccess;
        datacentFitParams{cellIdx}  = centFitParams;
        datacentFitErrors{cellIdx}  = centFitErrors;
        datacentFitY{cellIdx}       = centFitY;
        datacentFitSuccess{cellIdx} = centFitSuccess;
        dataPVFitMat{cellIdx}       = matPVFit;
        datacentFitMat{cellIdx}     = matCentFit;
        cellIdx = cellIdx + 1;
    end
end

% --- Leere Zellen entfernen ---
keepMask               = ~cellfun(@(x) isempty(x) || size(x,1)==0, FitDataMod);
h.FitDataMod           = FitDataMod(keepMask);
h.FitDataModCentroid   = FitDataModCentroid(keepMask);
h.fitresultexport      = fitresultexport(keepMask);
h.dataXcorr            = dataXcorr(keepMask);
h.dataYcorr            = dataYcorr(keepMask);
h.fitMethodUsed        = fitMethodUsed(keepMask);
h.dataCentroidMu       = dataCentroidMu(keepMask);
h.dataGaussFit         = dataGaussFit(keepMask);
h.dataPVParams         = dataPVParams(keepMask);
h.dataPVErrors         = dataPVErrors(keepMask);
h.dataPVFitY           = dataPVFitY(keepMask);
h.dataPVSuccess        = dataPVSuccess(keepMask);
h.datacentFitParams    = datacentFitParams(keepMask);
h.datacentFitErrors    = datacentFitErrors(keepMask);
h.datacentFitY         = datacentFitY(keepMask);
h.datacentFitSuccess   = datacentFitSuccess(keepMask);
h.dataPVFitMat         = dataPVFitMat(keepMask);
h.datacentFitMat       = datacentFitMat(keepMask);

if isempty(h.FitDataMod)
    set(hObj, 'String', 'Track & Fit Peaks', 'backg', col);
    errordlg('Kein Peak konnte gefittet werden. Parameter prüfen.', 'Kein Ergebnis');
    return
end

% validBinIdxs initialisieren (alle Bins gültig nach frischem Track&Fit)
for k = 1:numel(h.FitDataMod)
    dc = h.dataXcorr{k};
    h.validBinIdxs{k} = find(~cellfun(@isempty, dc));
end

% Kompatibilität
h.gaussEqnFirst = @(p_, xdata) p_(xdata);
for k = 1:numel(h.FitDataMod)
    h.idxempty{k}         = false(size(h.FitDataMod{k}, 1), 1);
    h.BinnedGammaFinal{k} = h.FitDataMod{k}(:, 1)';
end

% --- DEK Tabelle ---
if strcmp(get(h.radiobuttonwavelength.SelectedObject,'String'),'Ga K-alpha')
    DEK     = get(h.dekdataGaKalpha, 'data');
    datadek = DEK;
elseif strcmp(get(h.radiobuttonwavelength.SelectedObject,'String'),'In K-alpha')
    DEK     = get(h.dekdataInKalpha, 'data');
    datadek = DEK;
else
    DEK     = get(h.dekdataInKbeta,  'data');
    datadek = DEK;
end

PeakPosData = cell2mat(cellfun(@(x) nanmean(x,1), h.FitDataMod, 'UniformOutput', false));

for k = 1:size(PeakPosData, 1)
    if isnan(PeakPosData(k,2))
        if size(PeakPosData,2) >= 9  && isfinite(PeakPosData(k,9))
            PeakPosData(k,2) = PeakPosData(k,9);
        end
        if isnan(PeakPosData(k,2)) && size(PeakPosData,2) >= 11 && isfinite(PeakPosData(k,11))
            PeakPosData(k,2) = PeakPosData(k,11);
        end
    end
end
for k = find(isnan(PeakPosData(:,7)))'
    mat = h.FitDataMod{k};
    if ~isempty(mat) && size(mat,2) >= 7
        PeakPosData(k,7) = nanmean(mat(:,7));
    end
end

if size(PeakPosData,2) < 2
    set(hObj,'String','Fit Peaks','backg',col);
    errordlg('FitDataMod hat unerwartetes Format.','Fehler');
    return
end

Peaks     = PeakPosData(:,2);
PeaksTheo = DEK(:,4);

idxPeakHit = false(numel(Peaks), numel(PeaksTheo));
for k = 1:numel(PeaksTheo)
    idxPeakHit(:,k) = ismembertol(Peaks, PeaksTheo(k), 0.02);
end

DEKdataMatchedPeaks = zeros(size(PeakPosData,1), 6);
for k = 1:numel(PeaksTheo)
    DEKdataMatchedPeaks = DEKdataMatchedPeaks + idxPeakHit(:,k) .* DEK(k,:);
end
DEKdataMatchedPeaks(:,7) = PeakPosData(:,7);
h.DEKdataMatchedPeaks    = DEKdataMatchedPeaks;

set(h.tableDECFittedPeaks, 'Data', ...
    [Peaks DEKdataMatchedPeaks(:,4) DEKdataMatchedPeaks(:,1:3) DEKdataMatchedPeaks(:,5:7)])

% Dropdown E-theo
peakTheoList = cellfun(@(v) sprintf('%.4f',v), num2cell(datadek(:,4)), 'UniformOutput', false);
peakTheoList = peakTheoList(:)';
cf_fmt = get(h.tableDECFittedPeaks, 'ColumnFormat');
cf_fmt{2} = peakTheoList;
set(h.tableDECFittedPeaks, 'ColumnFormat', cf_fmt);

% --- Slider ---
nFit = size(h.FitDataMod, 1);
set(h.Slider, 'Min', 1, 'Max', max(nFit,2), 'Value', 1, ...
    'SliderStep', [1/max(nFit-1,1) 1/max(nFit-1,1)]);
nPts = size(h.FitDataMod{1}, 1);
set(h.SliderFittedPeaks, 'Min', 1, 'Max', max(nPts,2), 'Value', 1, ...
    'SliderStep', [1/max(nPts-1,1) 1/max(nPts-1,1)]);

% =====================================================================
% Ersten Peak plotten – nur plotdata (blau s) + plotdataCentFit (schwarz o)
% =====================================================================

% fitPseudoVoigt (dunkelblau, gefüllte Quadrate)
if ~isfield(h,'plotdata') || ~isvalid(h.plotdata)
    h.plotdata = errorbar(h.axes, 0, 0, 0, 's', ...
        'MarkerSize',      4, ...
        'MarkerFaceColor', [0.094 0.373 0.647], ...
        'MarkerEdgeColor', [0.094 0.373 0.647], ...
        'Color',           [0.094 0.373 0.647], ...
        'LineWidth',       0.8, ...
        'Visible',         'off');
end
pv    = h.FitDataMod{1};
idxPV = isfinite(pv(:,2));
if any(idxPV)
    set(h.plotdata, 'XData', pv(idxPV,1), 'YData', pv(idxPV,2), ...
        'YNegativeDelta', pv(idxPV,3), 'YPositiveDelta', pv(idxPV,3), ...
        'Visible', 'on');
else
    set(h.plotdata, 'Visible', 'off');
end

% fitCentroid (dunkelblau, offene Kreise)
if ~isfield(h,'plotdataCentFit') || ~isvalid(h.plotdataCentFit)
    h.plotdataCentFit = errorbar(h.axes, 0, 0, 0, 'o', ...
        'MarkerSize',      4.5, ...
        'MarkerFaceColor', 'none', ...
        'MarkerEdgeColor', [0.60 0.75 0.90], ...
        'Color',           [0.60 0.75 0.90], ...
        'LineWidth',       0.9, ...
        'Visible',         'off');
end

% fitCentroid nur anzeigen wenn Checkbox aktiv
if isfield(h,'cb_showCentroid') && get(h.cb_showCentroid, 'Value') == 1
    cf_p  = h.datacentFitMat{1};
    idxCF = isfinite(cf_p(:,2));
    if any(idxCF)
        set(h.plotdataCentFit, 'XData', cf_p(idxCF,1), 'YData', cf_p(idxCF,2), ...
            'YNegativeDelta', cf_p(idxCF,3), 'YPositiveDelta', cf_p(idxCF,3), ...
            'Visible', 'on');
    end
else
    set(h.plotdataCentFit, 'Visible', 'off');
end

% Filter-Button aktivieren
if isfield(h, 'FilterPeaksButton') && isvalid(h.FilterPeaksButton)
    set(h.FilterPeaksButton, 'Enable', 'on');
end

% Alte Plot-Handles aus der Legende ausblenden
for fn = {'plotdata1','plotdata2','fitcurvestress','highlightpeakdata'}
    if isfield(h, fn{1}) && isvalid(h.(fn{1}))
        set(h.(fn{1}), 'HandleVisibility', 'off');
    end
end

set(h.plotdata,       'DisplayName', 'fitPseudoVoigt');
set(h.plotdataCentFit,'DisplayName', 'fitCentroid');
legend(h.axes, 'Location', 'best', 'FontSize', 9);

h = updateFittedPeakPlot(h, 1, 1);
h.axes.YLabel.String  = ['2', char(952), ' [°]'];
h.plottab.SelectedTab = h.plottab1;

% X-Achse automatisch an Daten anpassen
pv    = h.FitDataMod{1};
xData = pv(isfinite(pv(:,1)), 1);
if ~isempty(xData)
    xMin = min(xData);
    xMax = max(xData);
    margin = max(5, (xMax - xMin) * 0.05);
    h.axes.XLim = [xMin - margin, xMax + margin];
end

set(hObj, 'String', 'Track & Fit Peaks', 'backg', col);
assignin('base', 'h', h);
assignin('base', 'trackFitResults', allRes);

guidata(hObj, h);