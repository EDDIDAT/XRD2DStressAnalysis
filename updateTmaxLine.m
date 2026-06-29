function h = updateTmaxLine(h)
% UPDATETMAXLINE  Zeigt/versteckt gestrichelte T_max-Linie in der Heatmap.

% Alte Linie entfernen falls vorhanden
if isfield(h, 'hTmaxLine') && ~isempty(h.hTmaxLine)
    try
        delete(h.hTmaxLine(isvalid(h.hTmaxLine)));
    catch
    end
    h.hTmaxLine = [];
end

% Checkbox-Status prüfen
if ~isfield(h, 'cbTmaxLine') || ~isvalid(h.cbTmaxLine), return; end
if get(h.cbTmaxLine, 'Value') == 0, return; end

% T_max verfügbar?
if ~isfield(h, 'tmax_min') || isempty(h.tmax_min), return; end
if ~isfield(h, 'axesTimeSeries') || ~isvalid(h.axesTimeSeries), return; end

% Aktueller Modus: nur bei Heatmap und Waterfall sinnvoll
selectedMode = get(h.TimeSeriesModeGroup.SelectedObject, 'String');
if ~ismember(selectedMode, {'Heatmap', 'Waterfall'}), return; end

% Linie zeichnen
hold(h.axesTimeSeries, 'on');
yLim = h.axesTimeSeries.YLim;
h.hTmaxLine = plot(h.axesTimeSeries, ...
    [h.tmax_min h.tmax_min], yLim, ...
    '--', 'Color', [1 1 1], 'LineWidth', 1.5);

% Label direkt an der Linie
text(h.axesTimeSeries, h.tmax_min, yLim(2), ...
    sprintf(' T_{max} = %.0f°C t = %.1f min', h.tmax_val, h.tmax_min), ...
    'Color', [1 1 1], 'FontSize', 8, ...
    'VerticalAlignment', 'top', 'HorizontalAlignment', 'left');
hold(h.axesTimeSeries, 'off');
end  % updateTmaxLine