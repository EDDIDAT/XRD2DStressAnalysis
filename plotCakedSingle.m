function h = plotCakedSingle(h, ds_idx)
ds = h.dataset(ds_idx);
if ~isCakedAvailable(ds)
    cla(h.axesTimeSeries);
    text(h.axesTimeSeries, 0.5, 0.5, ...
        sprintf('Kein gecaktes Bild für Messung #%d', ds.index), ...
        'Units', 'normalized', 'HorizontalAlignment', 'center', ...
        'FontSize', 11, 'Color', [0.5 0.5 0.5]);
    return
end

I_caked = ds.caked.I;
radial  = ds.caked.radial;
azim    = ds.caked.azimuthal;

% Log-Skalierung mit robuster clim
I_pos = max(I_caked, 0);
I_log = log10(1 + I_pos);
v     = I_log(isfinite(I_log) & I_log > 0);
if isempty(v)
    clims = [0 1];
else
    clims = prctile(v, [1 99]);
end
if ~isfinite(clims(1)) || ~isfinite(clims(2)) || clims(1) >= clims(2)
    clims = [0 max(I_log(:))];
end
if clims(1) >= clims(2)
    clims = [0 1];
end

% ── Axes-Zustand zurücksetzen (identisch zu resetAxesForCBFRaw) ───────
colorbar(h.axesTimeSeries, 'off');
cla(h.axesTimeSeries);
% Alle Axes-Einstellungen zurücksetzen
axis(h.axesTimeSeries, 'normal');
h.axesTimeSeries.XTickMode      = 'auto';
h.axesTimeSeries.YTickMode      = 'auto';
h.axesTimeSeries.XTickLabelMode = 'auto';
h.axesTimeSeries.YTickLabelMode = 'auto';
h.axesTimeSeries.DataAspectRatioMode    = 'auto';
h.axesTimeSeries.PlotBoxAspectRatioMode = 'auto';
h.axesTimeSeries.XLimMode               = 'auto';
h.axesTimeSeries.YLimMode               = 'auto';
h.axesTimeSeries.YDir                   = 'normal';

% % ── Bild zeichnen ─────────────────────────────────────────────────────
% imagesc(h.axesTimeSeries, radial, azim, I_log);
% clim(h.axesTimeSeries, clims);
% colormap(h.axesTimeSeries, 'hot');
% colorbar(h.axesTimeSeries);
% 
% % ── Seitenverhältnis: Axes füllt den verfügbaren Platz ───────────────
% axis(h.axesTimeSeries, 'normal');
% h.axesTimeSeries.DataAspectRatioMode    = 'auto';
% h.axesTimeSeries.PlotBoxAspectRatioMode = 'auto';
% h.axesTimeSeries.XLim = [min(radial) max(radial)];
% h.axesTimeSeries.YLim = [min(azim)   max(azim)];
% h.axesTimeSeries.YDir = 'normal';
% 
% h.axesTimeSeries.XLabel.String = '2\theta (°)';
% h.axesTimeSeries.YLabel.String = '\chi (°)';
% h.axesTimeSeries.Title.String  = sprintf( ...
%     'Caked  #%d  –  t = %.1f s  –  %s', ...
%     ds.index, ds.time_s, datestr(ds.datetime, 'HH:MM:SS'));
% 
% % ── Theoretische Peaklinien ───────────────────────────────────────────
% if isfield(h, 'PeakPos') && ~isempty(h.PeakPos) && ~isempty(h.PeakPos{1})
%     hold(h.axesTimeSeries, 'on');
%     for pk = 1:numel(h.PeakPos{1})
%         xline(h.axesTimeSeries, h.PeakPos{1}(pk), '--w', ...
%             'Alpha', 0.5, 'LineWidth', 0.8);
%     end
%     hold(h.axesTimeSeries, 'off');
% end

% ── q-Achse berechnen (radial ist in 2θ [°], umrechnen in q [Å^-1]) ──
% radial ist in 2θ [°] — in q [Å^-1] umrechnen falls Wellenlänge vorhanden
if isfield(h, 'datasetLambda_m') && ~isempty(h.datasetLambda_m) && ...
   h.datasetLambda_m > 0
    lambda_nm = h.datasetLambda_m * 1e9;
    q_axis    = (4*pi / lambda_nm) * sin(deg2rad(radial / 2)) / 10;  % Å^-1
    yAxisLabel = 'q (Å^{-1})';
    yVec       = q_axis;
else
    yVec       = radial;
    yAxisLabel = '2\theta (°)';
end

% ── Bild transponieren: χ auf X-Achse, q auf Y-Achse ─────────────────
imagesc(h.axesTimeSeries, azim, yVec, I_log');
clim(h.axesTimeSeries, clims);
colormap(h.axesTimeSeries, 'hot');
colorbar(h.axesTimeSeries);

axis(h.axesTimeSeries, 'normal');
h.axesTimeSeries.DataAspectRatioMode    = 'auto';
h.axesTimeSeries.PlotBoxAspectRatioMode = 'auto';
h.axesTimeSeries.XLim = [min(azim)  max(azim)];
h.axesTimeSeries.YLim = [min(yVec)  max(yVec)];
h.axesTimeSeries.YDir = 'normal';

h.axesTimeSeries.XLabel.String = '\chi (°)';
h.axesTimeSeries.YLabel.String = yAxisLabel;
h.axesTimeSeries.Title.String  = sprintf( ...
    'Caked  #%d  –  t = %.1f s  –  %s', ...
    ds.index, ds.time_s, datestr(ds.datetime, 'HH:MM:SS'));

% ── Theoretische Peaklinien horizontal ───────────────────────────────
if isfield(h, 'PeakPos') && ~isempty(h.PeakPos) && ~isempty(h.PeakPos{1})
    hold(h.axesTimeSeries, 'on');
    for pk = 1:numel(h.PeakPos{1})
        yline(h.axesTimeSeries, h.PeakPos{1}(pk), '--w', ...
            'Alpha', 0.5, 'LineWidth', 0.8);
    end
    hold(h.axesTimeSeries, 'off');
end

end  % plotCakedSingle