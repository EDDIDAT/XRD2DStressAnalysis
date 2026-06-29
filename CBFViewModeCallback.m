function CBFViewModeCallback(hObj, ~)
h = guidata(hObj);

if ~isfield(h,'dataset') || isempty(h.dataset)
    guidata(hObj, h); return
end

% Aktuellen Slider-Wert übernehmen
value  = max(1, round(get(h.SliderTimeSeries, 'Value')));
value  = min(value, numel(h.dataset));
ds     = h.dataset(value);

% Wellenlänge + Konversionsfunktion (identisch zu SliderCallbackTimeSeries)
use2theta_cb = isfield(h,'TimeSeriesXAxisGroup') && ...
               isvalid(h.TimeSeriesXAxisGroup) && ...
               strcmp(get(h.TimeSeriesXAxisGroup.SelectedObject,'String'),'2θ');
lambda_m_cb = [];
if use2theta_cb
    if isfield(h,'datasetLambda_m') && h.datasetLambda_m > 0
        lambda_m_cb = h.datasetLambda_m;
    elseif isfield(h,'lambda_m') && h.lambda_m > 0
        lambda_m_cb = h.lambda_m;
    end
    if isempty(lambda_m_cb), use2theta_cb = false; end
end
if use2theta_cb
    lambda_nm_cb = lambda_m_cb * 1e9;
    q2tth_cb     = @(q) 2 * rad2deg(asin(max(min(q * lambda_nm_cb / (4*pi), 1), -1)));
    xLabel_cb    = '2θ (°)';
else
    q2tth_cb  = @(q) q / 10;
    xLabel_cb = 'q (Å^{-1})';
end

titStr = sprintf('#%d  –  t = %.1f s  –  %s', ...
    ds.index, ds.time_s, datestr(ds.datetime,'HH:MM:SS'));

% ── Linkes Axes neu zeichnen ─────────────────────────────────────────
if cbfViewerShowCaked(h)

    % ── Caked-Daten lazy erzeugen, falls noch nicht vorhanden ─────────
    if ~isCakedAvailable(ds)
        col = get(h.LoadDatasetButton, 'backg');
        set(h.LoadDatasetButton, 'String', 'Erzeuge Caked Image ...', ...
            'backg', [1 .6 .6]);

        cla(h.axesTimeSeries);
        text(h.axesTimeSeries, 0.5, 0.5, ...
            sprintf('Erzeuge Caked Image für #%d ...', ds.index), ...
            'Units', 'normalized', 'HorizontalAlignment', 'center', ...
            'FontSize', 12, 'Color', [0.3 0.3 0.3]);
        drawnow;

        h  = ensureCakedSingleAvailable(h, value);
        ds = h.dataset(value);

        set(h.LoadDatasetButton, 'String', 'Load Dataset Folder', 'backg', col);
        drawnow;
    end

    if isCakedAvailable(ds)
        h.axesTimeSeries.XTickMode      = 'auto';
        h.axesTimeSeries.YTickMode      = 'auto';
        h.axesTimeSeries.XTickLabelMode = 'auto';
        h.axesTimeSeries.YTickLabelMode = 'auto';
        h = plotCakedSingle(h, value);
    else
        cla(h.axesTimeSeries);
        text(h.axesTimeSeries, 0.5, 0.5, ...
            sprintf('Kein gecaktes Bild für Messung #%d', ds.index), ...
            'Units', 'normalized', 'HorizontalAlignment', 'center', ...
            'FontSize', 11, 'Color', [0.5 0.5 0.5]);
    end

else
    % CBF Raw
    h = resetAxesForCBFRaw(h);
    if ~h.dataset(value).imgLoaded && ~isempty(h.dataset(value).cbfPath)
        cla(h.axesTimeSeries);
        text(h.axesTimeSeries, 0.5, 0.5, ...
            sprintf('Lade CBF #%d ...', ds.index), ...
            'Units', 'normalized', 'HorizontalAlignment', 'center', ...
            'FontSize', 12, 'Color', [0.3 0.3 0.3]);
        drawnow;
        pythonExe = strtrim(get(h.pythonExeEdit, 'String'));
        try
            h.dataset(value).img       = loadCBF(h.dataset(value).cbfPath, pythonExe);
            h.dataset(value).imgLoaded = true;
        catch ME
            warning('CBFViewModeCallback: %s', strrep(ME.message,'%', '%%'));
            h.dataset(value).img       = [];
            h.dataset(value).imgLoaded = true;
        end
        ds = h.dataset(value);
    end

    cla(h.axesTimeSeries);
    if ~isempty(ds.img)
        imgLog = log10(1 + max(ds.img, 0));
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
            sprintf('CBF konnte nicht geladen werden (#%d)', ds.index), ...
            'Units', 'normalized', 'HorizontalAlignment', 'center', ...
            'FontSize', 11, 'Color', [0.5 0.5 0.5]);
    end
end

% ── Rechtes Axes: 1D-Profil (unverändert) ────────────────────────────
cla(h.axesTimeProfile);
if ~isempty(ds.q) && ~isempty(ds.I)
    hold(h.axesTimeProfile, 'on');
    plot(h.axesTimeProfile, q2tth_cb(ds.q), ds.I, '-', ...
        'Color', [0.094 0.373 0.647], 'LineWidth', 1.0);
    h.axesTimeProfile.XLabel.String = xLabel_cb;
    h.axesTimeProfile.YLabel.String = 'Intensität';
    h.axesTimeProfile.XLim = [min(q2tth_cb(ds.q)) max(q2tth_cb(ds.q))];
    h.axesTimeProfile.YLim = [0  max(ds.I)*1.05];
    h.axesTimeProfile.Title.String = ['Profil  ' titStr];
end

guidata(hObj, h);
end

% function CBFViewModeCallback(hObj, ~)
% h = guidata(hObj);
% 
% if ~isfield(h,'dataset') || isempty(h.dataset)
%     guidata(hObj, h); return
% end
% 
% % Aktuellen Slider-Wert übernehmen
% value  = max(1, round(get(h.SliderTimeSeries, 'Value')));
% value  = min(value, numel(h.dataset));
% ds     = h.dataset(value);
% 
% % Wellenlänge + Konversionsfunktion (identisch zu SliderCallbackTimeSeries)
% use2theta_cb = isfield(h,'TimeSeriesXAxisGroup') && ...
%                isvalid(h.TimeSeriesXAxisGroup) && ...
%                strcmp(get(h.TimeSeriesXAxisGroup.SelectedObject,'String'),'2θ');
% lambda_m_cb = [];
% if use2theta_cb
%     if isfield(h,'datasetLambda_m') && h.datasetLambda_m > 0
%         lambda_m_cb = h.datasetLambda_m;
%     elseif isfield(h,'lambda_m') && h.lambda_m > 0
%         lambda_m_cb = h.lambda_m;
%     end
%     if isempty(lambda_m_cb), use2theta_cb = false; end
% end
% if use2theta_cb
%     lambda_nm_cb = lambda_m_cb * 1e9;
%     q2tth_cb     = @(q) 2 * rad2deg(asin(max(min(q * lambda_nm_cb / (4*pi), 1), -1)));
%     xLabel_cb    = '2θ (°)';
% else
%     q2tth_cb  = @(q) q / 10;
%     xLabel_cb = 'q (Å^{-1})';
% end
% 
% titStr = sprintf('#%d  –  t = %.1f s  –  %s', ...
%     ds.index, ds.time_s, datestr(ds.datetime,'HH:MM:SS'));
% 
% % ── Linkes Axes neu zeichnen ─────────────────────────────────────────
% if cbfViewerShowCaked(h)
%     if isCakedAvailable(ds)
%         % Ticks zurücksetzen bevor Caked-Bild
%         h.axesTimeSeries.XTickMode      = 'auto';
%         h.axesTimeSeries.YTickMode      = 'auto';
%         h.axesTimeSeries.XTickLabelMode = 'auto';
%         h.axesTimeSeries.YTickLabelMode = 'auto';
%         h = plotCakedSingle(h, value);
%     else
%         cla(h.axesTimeSeries);
%         text(h.axesTimeSeries, 0.5, 0.5, ...
%             sprintf('Kein gecaktes Bild für Messung #%d', ds.index), ...
%             'Units', 'normalized', 'HorizontalAlignment', 'center', ...
%             'FontSize', 11, 'Color', [0.5 0.5 0.5]);
%     end
% else
%     % CBF Raw
%     h = resetAxesForCBFRaw(h);
%     if ~h.dataset(value).imgLoaded && ~isempty(h.dataset(value).cbfPath)
%         cla(h.axesTimeSeries);
%         text(h.axesTimeSeries, 0.5, 0.5, ...
%             sprintf('Lade CBF #%d ...', ds.index), ...
%             'Units', 'normalized', 'HorizontalAlignment', 'center', ...
%             'FontSize', 12, 'Color', [0.3 0.3 0.3]);
%         drawnow;
%         pythonExe = strtrim(get(h.pythonExeEdit, 'String'));
%         try
%             h.dataset(value).img       = loadCBF(h.dataset(value).cbfPath, pythonExe);
%             h.dataset(value).imgLoaded = true;
%         catch ME
%             warning('CBFViewModeCallback: %s', strrep(ME.message,'%', '%%'));
%             h.dataset(value).img       = [];
%             h.dataset(value).imgLoaded = true;
%         end
%         ds = h.dataset(value);
%     end
% 
%     cla(h.axesTimeSeries);
%     if ~isempty(ds.img)
%         imgLog = log10(1 + max(ds.img, 0));
%         v      = imgLog(isfinite(imgLog) & imgLog > 0);
%         clims  = prctile(v, [1 99]);
%         imagesc(h.axesTimeSeries, imgLog);
%         clim(h.axesTimeSeries, clims);
%         colormap(h.axesTimeSeries, 'hot');
%         colorbar(h.axesTimeSeries);
%         axis(h.axesTimeSeries, 'image');
%         h.axesTimeSeries.YDir          = 'reverse';
%         h.axesTimeSeries.XLabel.String = 'x (px)';
%         h.axesTimeSeries.YLabel.String = 'y (px)';
%         h.axesTimeSeries.Title.String  = ['CBF Raw  ' titStr];
%     else
%         text(h.axesTimeSeries, 0.5, 0.5, ...
%             sprintf('CBF konnte nicht geladen werden (#%d)', ds.index), ...
%             'Units', 'normalized', 'HorizontalAlignment', 'center', ...
%             'FontSize', 11, 'Color', [0.5 0.5 0.5]);
%     end
% end
% 
% % ── Rechtes Axes: 1D-Profil (unverändert) ────────────────────────────
% cla(h.axesTimeProfile);
% if ~isempty(ds.q) && ~isempty(ds.I)
%     hold(h.axesTimeProfile, 'on');
%     plot(h.axesTimeProfile, q2tth_cb(ds.q), ds.I, '-', ...
%         'Color', [0.094 0.373 0.647], 'LineWidth', 1.0);
%     h.axesTimeProfile.XLabel.String = xLabel_cb;
%     h.axesTimeProfile.YLabel.String = 'Intensität';
%     h.axesTimeProfile.XLim = [min(q2tth_cb(ds.q)) max(q2tth_cb(ds.q))];
%     h.axesTimeProfile.YLim = [0  max(ds.I)*1.05];
%     h.axesTimeProfile.Title.String = ['Profil  ' titStr];
% end
% 
% guidata(hObj, h);
% end