function h = updateTimeSeriesPlot(h)
% Zentraler Plot-Dispatcher für den Time-Series-Tab.
% Wird von loaddatasetcallback, TimeSeriesModeCallback und
% TimeSeriesYAxisCallback aufgerufen.

if ~isfield(h, 'dataset') || isempty(h.dataset), return; end
dataset = h.dataset;
N       = numel(dataset);

% ── X-Achsen-Modus bestimmen (q oder 2theta) ─────────────────────────
% Wellenlänge: bevorzugt aus h.lambda_m, Fallback aus erstem PONI-Header
use2theta = isfield(h, 'TimeSeriesXAxisGroup') && ...
            isvalid(h.TimeSeriesXAxisGroup) && ...
            strcmp(get(h.TimeSeriesXAxisGroup.SelectedObject, 'String'), '2θ');

lambda_m = [];
if use2theta
    % Priorität 1: h.datasetLambda_m (aus PONI-Header — dieselbe λ wie pyFAI
    %              verwendet hat um q zu berechnen → konsistente 2θ-Anzeige)
    if isfield(h, 'datasetLambda_m') && ~isempty(h.datasetLambda_m) ...
           && h.datasetLambda_m > 0
        lambda_m = h.datasetLambda_m;
    % Priorität 2: h.lambda_m (aus "Create Sample")
    elseif isfield(h, 'lambda_m') && ~isempty(h.lambda_m) && h.lambda_m > 0
        lambda_m = h.lambda_m;
    % Priorität 3: erstes gültiges PONI im Dataset durchsuchen
    else
        for ds_idx = 1:N
            p = dataset(ds_idx).poni;
            if isstruct(p) && numel(fieldnames(p)) > 0 && ...
               isfield(p, 'wavelength') && isnumeric(p.wavelength) && ...
               p.wavelength > 0
                lambda_m = p.wavelength;
                break;
            end
        end
    end
    if isempty(lambda_m) || lambda_m <= 0
        warning('updateTimeSeriesPlot: Wellenlänge nicht gefunden, verwende q-Achse.');
        use2theta = false;
    end
end

% Konversionsfunktion:
%   2theta-Modus: q [nm^-1] → 2theta [°]
%   q-Modus:      q [nm^-1] → q [Å^-1]  (÷ 10)
if use2theta
    lambda_nm  = lambda_m * 1e9;
    q2tth      = @(q) 2 * rad2deg(asin(max(min( q * lambda_nm / (4*pi), 1), -1)));
    xLabel_str = '2θ (°)';
else
    q2tth      = @(q) q / 10;            % nm^-1 → Å^-1
    xLabel_str = 'q (Å^{-1})';
end

% ── Y-Achse für Heatmap/Waterfall bestimmen ──────────────────────────
axisOptions = get(h.TimeSeriesYAxisPopup, 'String');
axisIdx     = get(h.TimeSeriesYAxisPopup, 'Value');
axisField   = axisOptions{axisIdx};

switch axisField
    case 'Zeit (min)'
        yAxis  = [dataset.time_s]' / 60;
        yLabel = 'Zeit (min)';
    case 'Index'
        yAxis  = double([dataset.index]');
        yLabel = 'Messnummer';
    otherwise
        if startsWith(axisField, 'Heater: ') && ...
           isfield(h, 'heaterData') && ~isempty(h.heaterData)
            % Heizprotokoll-Spalte auf XRD-Zeitpunkte interpolieren
            colName = axisField(9:end);   % 'Heater: ' abschneiden
            try
                xrd_t_min = [dataset.time_s]' / 60;
                yAxis  = interp1(h.heaterData.time_min, ...
                                 h.heaterData.(matlab.lang.makeValidName(colName)), ...
                                 xrd_t_min, 'linear', 'extrap');
                yLabel = colName;
            catch
                yAxis  = (1:N)';
                yLabel = axisField;
            end
        else
            % Motorposition aus meta
            try
                yAxis = arrayfun(@(d) d.meta.(axisField), dataset)';
            catch
                yAxis = (1:N)';
            end
            yLabel = strrep(axisField, '_', ' ');
        end
end

% ── Modus ────────────────────────────────────────────────────────────
selectedMode = get(h.TimeSeriesModeGroup.SelectedObject, 'String');

switch selectedMode

    % ------------------------------------------------------------------
    case 'Waterfall'
        h = applyTimeSeriesLayout(h, 'full');
        cla(h.axesTimeSeries);
        axis(h.axesTimeSeries, 'normal');
        h.axesTimeSeries.YDir                   = 'normal';
        h.axesTimeSeries.DataAspectRatioMode     = 'auto';
        h.axesTimeSeries.PlotBoxAspectRatioMode  = 'auto';
        h.axesTimeSeries.XLimMode                = 'auto';
        h.axesTimeSeries.YLimMode                = 'auto';
        hold(h.axesTimeSeries, 'on');
    
        % Sicherstellen, dass Profil-Daten vorhanden
        hasData = ~cellfun(@isempty, {dataset.I});
        if ~any(hasData)
            text(h.axesTimeSeries, 0.5, 0.5, 'Keine 1D-Profildaten geladen', ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                'FontSize', 11, 'Color', [0.5 0.5 0.5]);
            return
        end
    
        % ── Subsampling: max. ~100 Linien zeichnen ────────────────────────
        idxAll      = find(hasData);
        maxLines    = 100;
        stepN       = max(1, ceil(numel(idxAll) / maxLines));
        idxPlot     = idxAll(1:stepN:end);
        nLinesShown = numel(idxPlot);
    
        % Offset = 15 % des globalen Intensitäts-Maximalwerts
        allI_vals = cellfun(@max, {dataset(hasData).I});
        offset    = 0.15 * max(allI_vals);
        if offset == 0, offset = 1; end
    
        cmap   = parula(nLinesShown);
        count  = 0;
        xMin   =  Inf;
        xMax   = -Inf;
        yMin   =  Inf;
        yMax   = -Inf;
        for ii = 1:nLinesShown
            i = idxPlot(ii);
            if isempty(dataset(i).I), continue; end
            [q_ex, I_ex] = applyExcludeZone(h, dataset(i).q, dataset(i).I);
            xData = q2tth(q_ex);
            yData = I_ex + count*offset;
            plot(h.axesTimeSeries, xData, yData, ...
                '-', 'Color', cmap(ii,:), 'LineWidth', 0.7);
            xMin = min(xMin, min(xData));
            xMax = max(xMax, max(xData));
            yMin = min(yMin, min(yData));
            yMax = max(yMax, max(yData));
            count = count + 1;
        end
        hold(h.axesTimeSeries, 'off');
    
        % Achsen exakt auf Datenbereich → kein weißer Rand
        if isfinite(xMin) && xMax > xMin
            h.axesTimeSeries.XLim = [xMin xMax];
        end
        if isfinite(yMin) && yMax > yMin
            h.axesTimeSeries.YLim = [yMin yMax];
        end
    
        h.axesTimeSeries.XLabel.String = xLabel_str;
        h.axesTimeSeries.YLabel.String = 'Intensität + Offset';
        h.axesTimeSeries.Title.String  = ...
            sprintf('Waterfall  –  %d von %d Profilen (jedes %d.)', ...
            nLinesShown, sum(hasData), stepN);
    
        % Colorbar als Zeit-Achse
        colormap(h.axesTimeSeries, parula);
        cb = colorbar(h.axesTimeSeries, 'Location', 'eastoutside');
        cb.Label.String = yLabel;
        if max(yAxis) > min(yAxis)
            clim(h.axesTimeSeries, [min(yAxis) max(yAxis)]);
        end
    
        % Heater-Plot + T_max-Linie + Phasenlinien aktualisieren
        h = updateHeaterPlot(h);
        h = updateTmaxLine(h);
        h = updatePhaseLines(h);
    % case 'Waterfall'
    %     h = applyTimeSeriesLayout(h, 'full');
    %     cla(h.axesTimeSeries);
    %     axis(h.axesTimeSeries, 'normal');
    %     h.axesTimeSeries.YDir                   = 'normal';
    %     h.axesTimeSeries.DataAspectRatioMode     = 'auto';
    %     h.axesTimeSeries.PlotBoxAspectRatioMode  = 'auto';
    %     h.axesTimeSeries.XLimMode                = 'auto';
    %     h.axesTimeSeries.YLimMode                = 'auto';
    %     hold(h.axesTimeSeries, 'on');
    % 
    %     % Sicherstellen, dass Profil-Daten vorhanden
    %     hasData = ~cellfun(@isempty, {dataset.I});
    %     if ~any(hasData)
    %         text(h.axesTimeSeries, 0.5, 0.5, 'Keine 1D-Profildaten geladen', ...
    %             'Units', 'normalized', 'HorizontalAlignment', 'center', ...
    %             'FontSize', 11, 'Color', [0.5 0.5 0.5]);
    %         return
    %     end
    % 
    %     % Offset = 15 % des globalen Intensitäts-Maximalwerts
    %     allI_vals = cellfun(@max, {dataset(hasData).I});
    %     offset    = 0.15 * max(allI_vals);
    %     if offset == 0, offset = 1; end
    % 
    %     cmap   = parula(N);
    %     count  = 0;
    %     xMin   =  Inf;   % für Achsengrenzen
    %     xMax   = -Inf;
    %     yMin   =  Inf;
    %     yMax   = -Inf;
    %     for i = 1:N
    %         if isempty(dataset(i).I), continue; end
    %         [q_ex, I_ex] = applyExcludeZone(h, dataset(i).q, dataset(i).I);
    %         xData = q2tth(q_ex);
    %         yData = I_ex + count*offset;
    %         plot(h.axesTimeSeries, xData, yData, ...
    %             '-', 'Color', cmap(i,:), 'LineWidth', 0.7);
    %         xMin = min(xMin, min(xData));
    %         xMax = max(xMax, max(xData));
    %         yMin = min(yMin, min(yData));
    %         yMax = max(yMax, max(yData));
    %         count = count + 1;
    %     end
    %     hold(h.axesTimeSeries, 'off');
    % 
    %     % Achsen exakt auf Datenbereich → kein weißer Rand
    %     if isfinite(xMin) && xMax > xMin
    %         h.axesTimeSeries.XLim = [xMin xMax];
    %     end
    %     if isfinite(yMin) && yMax > yMin
    %         h.axesTimeSeries.YLim = [yMin yMax];
    %     end
    % 
    %     h.axesTimeSeries.XLabel.String = xLabel_str;
    %     h.axesTimeSeries.YLabel.String = 'Intensität + Offset';
    %     h.axesTimeSeries.Title.String  = ...
    %         sprintf('Waterfall  –  %d Profile', sum(hasData));
    % 
    %     % Colorbar als Zeit-Achse
    %     colormap(h.axesTimeSeries, parula);
    %     cb = colorbar(h.axesTimeSeries, 'Location', 'eastoutside');
    %     cb.Label.String = yLabel;
    %     if max(yAxis) > min(yAxis)
    %         clim(h.axesTimeSeries, [min(yAxis) max(yAxis)]);
    %     end
    % 
    %     % Heater-Plot + T_max-Linie + Phasenlinien aktualisieren
    %     h = updateHeaterPlot(h);
    %     h = updateTmaxLine(h);
    %     h = updatePhaseLines(h);
    % 
    % % ------------------------------------------------------------------
    case 'Heatmap'
        h = applyTimeSeriesLayout(h, 'full');
        cla(h.axesTimeSeries);
        axis(h.axesTimeSeries, 'normal');
        h.axesTimeSeries.YDir                   = 'normal';
        h.axesTimeSeries.DataAspectRatioMode     = 'auto';
        h.axesTimeSeries.PlotBoxAspectRatioMode  = 'auto';
        h.axesTimeSeries.XLimMode                = 'auto';
        h.axesTimeSeries.YLimMode                = 'auto';

        hasData = ~cellfun(@isempty, {dataset.I});
        if ~any(hasData)
            text(h.axesTimeSeries, 0.5, 0.5, 'Keine 1D-Profildaten geladen', ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                'FontSize', 11, 'Color', [0.5 0.5 0.5]);
            return
        end

        % Intensitätsmatrix aufbauen
        % Layout: X-Achse = Zeit (min), Y-Achse = 2theta/q
        %   → I_mat: Zeilen = Messungen (Zeit), Spalten = q/2theta
        %   → imagesc bekommt transponierte Matrix: I_mat'
        %      damit Zeilen im Bild = q/2theta, Spalten = Zeit
        q_ref  = dataset(find(hasData,1)).q;
        tth_ref = q2tth(q_ref);            % q oder 2theta je nach Schalter
        idxOK  = find(hasData);
        I_mat  = zeros(numel(idxOK), numel(q_ref));
        tVals  = zeros(numel(idxOK), 1);   % Zeit-Achse (X)
        for ii = 1:numel(idxOK)
            i = idxOK(ii);
            [~, I_ex]   = applyExcludeZone(h, dataset(i).q, dataset(i).I);
            I_mat(ii,:) = I_ex(:)';
            tVals(ii)   = yAxis(i);        % Zeit in min (oder Motor etc.)
        end

        % ── Kontrast-Optimierung ─────────────────────────────────────────
        % Strategie: robuste Percentil-basierte clim, OHNE globales log
        % wenn die Daten bereits normiert sind (max ~ 1-100).
        % Wähle automatisch zwischen linearer und log-Skalierung.

        I_pos = max(I_mat, 0);
        I_max = max(I_pos(:));
        I_nonzero = I_pos(I_pos > 0);

        % Kontrast-Percentil aus Slider lesen
        upperPct = 98;
        if isfield(h, 'HeatmapContrastSlider') && isvalid(h.HeatmapContrastSlider)
            upperPct = round(get(h.HeatmapContrastSlider, 'Value'));
        end

        if isempty(I_nonzero)
            I_plot    = I_pos;
            climLabel = 'I';
            clims     = [0 1];
        else
            I_plot    = log10(1 + I_pos);
            climLabel = 'log(I) [a. u.]';
            I_log_nz  = log10(1 + I_nonzero);
            clims     = prctile(I_log_nz, [2 upperPct]);
        end

        % Sicherstellen dass clims ein echtes Intervall ist
        if ~isfinite(clims(1)) || ~isfinite(clims(2)) || clims(1) >= clims(2)
            clims = [min(I_plot(:))  max(I_plot(:))];
        end
        if clims(1) >= clims(2)
            clims = [0 1];
        end

        % pcolor: nichtlineare Y-Achse (2theta) korrekt darstellen
        [T_grid, Y_grid] = meshgrid(tVals, tth_ref);
        pcolor(h.axesTimeSeries, T_grid, Y_grid, I_plot');
        shading(h.axesTimeSeries, 'flat');
        clim(h.axesTimeSeries, clims);
        set(h.axesTimeSeries, 'YDir', 'normal');
        colormap(h.axesTimeSeries, 'parula');

        % Achsen einschränken
        if isfield(h, 'tsTRange') && ~isempty(h.tsTRange)
            h.axesTimeSeries.XLim = h.tsTRange;
        else
            h.axesTimeSeries.XLim = [min(tVals) max(tVals)];
        end
        if isfield(h, 'tsXRange') && ~isempty(h.tsXRange)
            h.axesTimeSeries.YLim = h.tsXRange;
        else
            h.axesTimeSeries.YLim = [min(tth_ref) max(tth_ref)];
        end

        cb = colorbar(h.axesTimeSeries, 'Location', 'eastoutside');
        cb.Label.String = climLabel;
        % X = Zeit, Y = 2theta/q
        h.axesTimeSeries.XLabel.String = yLabel;      % z.B. 'Zeit (min)'
        h.axesTimeSeries.YLabel.String = xLabel_str;  % z.B. '2θ (°)'
        if use2theta
            titleYStr = '2θ';
        else
            titleYStr = 'q (Å^{-1})';
        end
        h.axesTimeSeries.Title.String = ...
            sprintf('Heatmap I(%s, %s)  –  %d Profile', titleYStr, yLabel, numel(idxOK));

        % Heater-Plot + T_max-Linie + Phasenlinien aktualisieren
        h = updateHeaterPlot(h);
        h = updateTmaxLine(h);
        h = updatePhaseLines(h);

        % Gespeicherte Peak-Positionen als horizontale Linien anzeigen
        if isfield(h, 'tsUserPeaks') && ~isempty(h.tsUserPeaks)
            hold(h.axesTimeSeries, 'on');
            for pk = 1:numel(h.tsUserPeaks)
                yline(h.axesTimeSeries, h.tsUserPeaks(pk), 'r-', ...
                    sprintf('%.2f', h.tsUserPeaks(pk)), 'LineWidth', 1.2, ...
                    'LabelHorizontalAlignment', 'left', 'FontSize', 8);
            end
        end

        % Peak-Tracks auf Heatmap anzeigen (wenn Fit-Ergebnisse vorhanden)
        if isfield(h,'tsFitResults') && ~isempty(h.tsFitResults) && ...
           strcmp(selectedMode, 'Heatmap')
            r      = h.tsFitResults;
            colors_ht = lines(size(r.peakPos,2));
            hold(h.axesTimeSeries,'on');
            for pk = 1:size(r.peakPos,2)
                idxFin = isfinite(r.peakPos(:,pk));
                if ~any(idxFin), continue; end
                % Y-Achse der Heatmap = Zeit oder Index → aus yVec bestimmen
                % (muss mit dem Y-Vektor des imagesc übereinstimmen)
                plot(h.axesTimeSeries, r.time_min(idxFin), r.peakPos(idxFin,pk), ...
                    'o-', 'Color', colors_ht(pk,:), 'MarkerSize', 3, ...
                    'LineWidth', 1.2, 'MarkerFaceColor', colors_ht(pk,:));
            end
        end

    % ------------------------------------------------------------------
    case {'Single Profile', 'CBF Viewer'}
        % Slider-Wert auf 1 setzen und erstes Element direkt plotten.
        % KEIN Aufruf von SliderCallbackTimeSeries — lokale Funktionen
        % können andere lokale Funktionen nicht aufrufen.
        % Stattdessen: gemeinsamen Plot-Code direkt hier ausführen.
        set(h.SliderTimeSeries, 'Value', 1);
        ds = dataset(1);

        % Info-Text aktualisieren
        if isfield(h, 'TimeSeriesInfoText') && isvalid(h.TimeSeriesInfoText)
            set(h.TimeSeriesInfoText, 'String', ...
                sprintf('#%d  t=%.1fs  %s', ds.index, ds.time_s, ...
                datestr(ds.datetime, 'HH:MM:SS')));
        end

        if strcmp(selectedMode, 'Single Profile')
            h = applyTimeSeriesLayout(h, 'bottom');
            axis(h.axesTimeProfile, 'normal');
            h.axesTimeProfile.YDir                   = 'normal';
            h.axesTimeProfile.DataAspectRatioMode    = 'auto';
            h.axesTimeProfile.PlotBoxAspectRatioMode = 'auto';
            h.axesTimeProfile.XLimMode               = 'auto';
            h.axesTimeProfile.YLimMode               = 'auto';
            % 1D-Profil plotten
            if ~isempty(ds.q) && ~isempty(ds.I)
                cla(h.axesTimeProfile);
                hold(h.axesTimeProfile, 'on');
                plot(h.axesTimeProfile, q2tth(ds.q), ds.I, '-', ...
                    'Color', [0.094 0.373 0.647], 'LineWidth', 1.0);
                h.axesTimeProfile.XLabel.String = xLabel_str;
                h.axesTimeProfile.YLabel.String = 'Intensität';
                h.axesTimeProfile.Title.String  = ...
                    sprintf('Profil #%d  –  t = %.1f s  –  %s', ...
                    ds.index, ds.time_s, datestr(ds.datetime,'HH:MM:SS'));
            
                % ── x-Bereich anwenden falls gesetzt
                if isfield(h, 'tsXRange') && ~isempty(h.tsXRange)
                    h.axesTimeProfile.XLim = h.tsXRange;
                else
                    h.axesTimeProfile.XLimMode = 'auto';
                end
                h.axesTimeProfile.YLimMode = 'auto';

                % ── BG-Grenzen (verschiebbar) und Peak-Marker einzeichnen ─
                if isfield(h, 'tsBgIntervals') && ~isempty(h.tsBgIntervals)
                    makeDraggableBGLines(h.axesTimeProfile, h.tsBgIntervals, h.myfig);
                end
                if isfield(h, 'tsUserPeaks') && ~isempty(h.tsUserPeaks)
                    makeDraggablePeakLines(h.axesTimeProfile, h.tsUserPeaks, h.myfig);
                end
            end
            % Oberes Axes ist unsichtbar (Layout 'bottom')

        else  % CBF Viewer
            h = applyTimeSeriesLayout(h, 'split');
        
            if cbfViewerShowCaked(h)

                % ── Caked-Daten lazy erzeugen, falls noch nicht vorhanden ──
                if ~isCakedAvailable(dataset(1))
                    col = get(h.LoadDatasetButton, 'backg');
                    set(h.LoadDatasetButton, 'String', 'Erzeuge Caked Image ...', ...
                        'backg', [1 .6 .6]);
                    cla(h.axesTimeSeries);
                    text(h.axesTimeSeries, 0.5, 0.5, ...
                        sprintf('Erzeuge Caked Image für #%d ...', dataset(1).index), ...
                        'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                        'FontSize', 12, 'Color', [0.3 0.3 0.3]);
                    drawnow;

                    h       = ensureCakedSingleAvailable(h, 1);
                    dataset = h.dataset;   % aktualisiertes dataset erneut holen
                    ds      = dataset(1);

                    set(h.LoadDatasetButton, 'String', 'Load Dataset Folder', 'backg', col);
                    drawnow;
                end

                if isCakedAvailable(dataset(1))
                    % Ticks vom vorherigen CBF-Bild löschen
                    h.axesTimeSeries.XTickMode      = 'auto';
                    h.axesTimeSeries.YTickMode      = 'auto';
                    h.axesTimeSeries.XTickLabelMode = 'auto';
                    h.axesTimeSeries.YTickLabelMode = 'auto';
                    h = plotCakedSingle(h, 1);
                else
                    hasCBFAny = any(~cellfun(@isempty, {dataset.cbfPath}));
                    if hasCBFAny
                        msg = sprintf(['Keine PONI-Datei im Ordner gefunden.\n' ...
                                       'PONI ablegen und Dataset neu laden\n' ...
                                       'um Caked Images zu erzeugen.']);
                    else
                        msg = 'Keine CBF-Dateien vorhanden';
                    end
                    cla(h.axesTimeSeries);
                    text(h.axesTimeSeries, 0.5, 0.5, msg, ...
                        'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                        'FontSize', 11, 'Color', [0.4 0.4 0.4]);
                    h.axesTimeSeries.Title.String  = 'Caked Image';
                    h.axesTimeSeries.XLabel.String = '';
                    h.axesTimeSeries.YLabel.String = '';
                end
            else
                % CBF Raw — erstes Bild direkt laden
                titStr = sprintf('#%d  –  t = %.1f s  –  %s', ...
                    ds.index, ds.time_s, datestr(ds.datetime, 'HH:MM:SS'));
        
                if ~h.dataset(1).imgLoaded && ~isempty(h.dataset(1).cbfPath)
                    cla(h.axesTimeSeries);
                    text(h.axesTimeSeries, 0.5, 0.5, ...
                        sprintf('Lade CBF #%d ...', ds.index), ...
                        'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                        'FontSize', 12, 'Color', [0.3 0.3 0.3]);
                    drawnow;
                    pythonExe_up = strtrim(get(h.pythonExeEdit, 'String'));
                    try
                        h.dataset(1).img       = loadCBF(h.dataset(1).cbfPath, pythonExe_up);
                        h.dataset(1).imgLoaded = true;
                    catch ME
                        warning('updateTimeSeriesPlot CBF: %s', strrep(ME.message, '%', '%%'));
                        h.dataset(1).img       = [];
                        h.dataset(1).imgLoaded = true;
                    end
                    ds = h.dataset(1);
                end
        
                h = resetAxesForCBFRaw(h);
                if ~isempty(h.dataset(1).img)
                    imgLog = log10(1 + max(h.dataset(1).img, 0));
                    v      = imgLog(isfinite(imgLog) & imgLog > 0);
                    clims  = prctile(v, [1 99]);
                    imagesc(h.axesTimeSeries, imgLog);
                    clim(h.axesTimeSeries, clims);
                    colormap(h.axesTimeSeries, 'hot');
                    colorbar(h.axesTimeSeries);
                    axis(h.axesTimeSeries, 'image');
                    h.axesTimeSeries.YDir          = 'reverse';
                    h.axesTimeSeries.XLabel.String = 'x (px)';
                    h.axesTimeSeries.YLabel.String = 'y (px)';
                    h.axesTimeSeries.Title.String  = ['CBF Raw  ' titStr];
                else
                    text(h.axesTimeSeries, 0.5, 0.5, ...
                        'CBF konnte nicht geladen werden', ...
                        'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                        'FontSize', 11, 'Color', [0.5 0.5 0.5]);
                end
            end
        
            % Rechtes Axes: erstes 1D-Profil
            cla(h.axesTimeProfile);
            if ~isempty(ds.q) && ~isempty(ds.I)
                hold(h.axesTimeProfile, 'on');
                plot(h.axesTimeProfile, q2tth(ds.q), ds.I, '-', ...
                    'Color', [0.094 0.373 0.647], 'LineWidth', 1.0);
                h.axesTimeProfile.XLabel.String = xLabel_str;
                h.axesTimeProfile.YLabel.String = 'Intensität';
                h.axesTimeProfile.XLim = [min(q2tth(ds.q)) max(q2tth(ds.q))];
                h.axesTimeProfile.YLim = [0  max(ds.I)*1.05];
                h.axesTimeProfile.Title.String = ...
                    sprintf('Profil #%d  t=%.1f s', ds.index, ds.time_s);
            end
        end
        return
end
end  % updateTimeSeriesPlot