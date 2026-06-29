function h = resetAxesForCBFRaw(h)
cla(h.axesTimeSeries);
axis(h.axesTimeSeries, 'normal');
h.axesTimeSeries.DataAspectRatioMode    = 'auto';
h.axesTimeSeries.PlotBoxAspectRatioMode = 'auto';
h.axesTimeSeries.XLimMode               = 'auto';
h.axesTimeSeries.YLimMode               = 'auto';
h.axesTimeSeries.YDir                   = 'reverse';
colorbar(h.axesTimeSeries, 'off');

% ── Tick-Einstellungen zurücksetzen ───────────────────────────────────
h.axesTimeSeries.XTickMode      = 'auto';
h.axesTimeSeries.YTickMode      = 'auto';
h.axesTimeSeries.XTickLabelMode = 'auto';
h.axesTimeSeries.YTickLabelMode = 'auto';
end