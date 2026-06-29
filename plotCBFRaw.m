function h = plotCBFRaw(h, value, titStr)
% Zeichnet das CBF-Rohbild für dataset(value) in h.axesTimeSeries.
% Identisches Verhalten wie CBFViewModeCallback CBF Raw-Zweig.

ds = h.dataset(value);

% Lazy laden falls noch nicht geladen
if ~ds.imgLoaded && ~isempty(ds.cbfPath)
    cla(h.axesTimeSeries);
    text(h.axesTimeSeries, 0.5, 0.5, ...
        sprintf('Lade CBF #%d ...', ds.index), ...
        'Units', 'normalized', 'HorizontalAlignment', 'center', ...
        'FontSize', 12, 'Color', [0.3 0.3 0.3]);
    drawnow;
    pythonExe = strtrim(get(h.pythonExeEdit, 'String'));
    try
        h.dataset(value).img       = loadCBF(ds.cbfPath, pythonExe);
        h.dataset(value).imgLoaded = true;
    catch ME
        warning('plotCBFRaw: %s', strrep(ME.message, '%', '%%'));
        h.dataset(value).img       = [];
        h.dataset(value).imgLoaded = true;
    end
    ds = h.dataset(value);
end

% Axes vollständig zurücksetzen
colorbar(h.axesTimeSeries, 'off');
cla(h.axesTimeSeries);
axis(h.axesTimeSeries, 'normal');
h.axesTimeSeries.DataAspectRatioMode    = 'auto';
h.axesTimeSeries.PlotBoxAspectRatioMode = 'auto';
h.axesTimeSeries.XLimMode               = 'auto';
h.axesTimeSeries.YLimMode               = 'auto';

if ~isempty(ds.img)
    imgLog = log10(1 + max(ds.img, 0));
    v      = imgLog(isfinite(imgLog) & imgLog > 0);
    clims  = prctile(v, [1 99]);
    [nRows, nCols] = size(imgLog);
    imagesc(h.axesTimeSeries, [1 nCols], [1 nRows], imgLog);
    clim(h.axesTimeSeries, clims);
    colormap(h.axesTimeSeries, 'hot');
    colorbar(h.axesTimeSeries, 'Location', 'eastoutside');
    h.axesTimeSeries.XLim          = [0.5  nCols+0.5];
    h.axesTimeSeries.YLim          = [0.5  nRows+0.5];
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

end  % plotCBFRaw