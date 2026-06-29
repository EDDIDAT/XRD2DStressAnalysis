function h = updateBgMarkers(h)
delete(findobj(h.axesPlotIntensityData, 'Tag', 'bgmarker'));
if ~isfield(h, 'BgIntervals') || isempty(h.BgIntervals), return; end

sliderVal = max(1, round(get(h.Slider, 'Value')));

% m und l aus Slider-Wert bestimmen
m_plot = 1;
if isfield(h,'dataX') && ~isempty(h.dataX)
    nBinsPerAlpha = size(h.dataY{m_plot}, 2);
    l_plot = max(1, min(sliderVal, nBinsPerAlpha));
else
    return
end

% x-Daten des aktuellen Bins
TX = h.dataX{m_plot};
TY = h.dataY{m_plot}(:, l_plot);

nGroups = size(h.BgIntervals, 1);

hold(h.axesPlotIntensityData, 'on');

bgXplot = zeros(1, nGroups*2);
bgYplot = zeros(1, nGroups*2);

for g = 1:nGroups
    % y-Werte direkt aus Datenpunkten — konsistent mit Untergrundkorrektur
    idxL = Tools.Data.DataSetOperations.FindNearestIndex(TX, h.BgIntervals(g,1));
    idxR = Tools.Data.DataSetOperations.FindNearestIndex(TX, h.BgIntervals(g,2));

    bgXplot(2*g-1) = TX(idxL);
    bgXplot(2*g)   = TX(idxR);
    bgYplot(2*g-1) = TY(idxL);
    bgYplot(2*g)   = TY(idxR);
end

% Untergrundlinie über gesamten Bereich
[bgXsort, sortIdx] = sort(bgXplot);
bgYsort = bgYplot(sortIdx);

xFull   = linspace(min(TX), max(TX), 500)';
yBgFull = interp1(bgXsort, bgYsort, xFull, 'linear', 'extrap');
yBgFull = max(yBgFull, 0);

% Untergrundlinie plotten
plot(h.axesPlotIntensityData, xFull, yBgFull, '--', ...
    'Color',     [0.8 0.4 0], ...
    'LineWidth', 1.2, ...
    'Tag',       'bgmarker', ...
    'Visible',   'off');

% Stützpunkte plotten
plot(h.axesPlotIntensityData, bgXsort, bgYsort, 'v', ...
    'Color',           [0.8 0.4 0], ...
    'MarkerFaceColor', [0.8 0.4 0], ...
    'MarkerSize',      8, ...
    'Tag',             'bgmarker', ...
    'Visible',         'off');