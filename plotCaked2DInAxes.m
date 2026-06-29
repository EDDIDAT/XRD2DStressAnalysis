function plotCaked2DInAxes(ax, out, opts)
% PLOTCAKED2DINAXES  Zeichnet das gecakte 2D-Bild in eine bestehende uiaxes.
%   ax   – Ziel-uiaxes Handle
%   out  – pyfai output struct (Felder: I, radial, azimuthal)
%   opts – gleiche Optionen wie plot_pyfai_multigeom_2d

if nargin < 3, opts = struct(); end
opts = applyLocalDefaults(opts, struct( ...
    'showAxis',    'tth', ...
    'useLog',      true,  ...
    'logStrength', 1,     ...
    'climPct',     [10 90], ...
    'saveTif',     false, ...
    'tifPath',     'pyfai_caked2D.tif', ...
    'resolution',  300    ...
));

I   = double(out.I);
tth = double(out.radial(:));
chi = double(out.azimuthal(:));

nRad = numel(tth);
nChi = numel(chi);

if isequal(size(I), [nChi, nRad])
    I = I.';
elseif ~isequal(size(I), [nRad, nChi])
    warning('plotCaked2DInAxes: I hat unerwartete Größe.');
    return
end

% y-Achse
if strcmpi(opts.showAxis, 'tth')
    y    = tth;
    ylab = '2\theta (deg)';
else
    warning('plotCaked2DInAxes: showAxis=q nicht implementiert für uiaxes.');
    return
end

% Log-Skalierung
Iplot = I;
if opts.useLog
    Iplot = log10(1 + opts.logStrength .* max(Iplot, 0));
end

% NEU: Normierung auf Median des Rohbildes
if isfield(opts, 'rawMedian') && ~isempty(opts.rawMedian) && opts.rawMedian > 0
    % Median des gecakten Bildes berechnen (nur gültige Pixel)
    medCaked = median(Iplot(isfinite(Iplot) & Iplot > 0), 'all');
    if medCaked > 0
        Iplot = Iplot * (opts.rawMedian / medCaked);
    end
end

% Farb-Limits
v = Iplot(isfinite(Iplot));
if ~isempty(v)
    clims = prctile(v, opts.climPct);
else
    clims = [min(Iplot(:)) max(Iplot(:))];
end

% NEU: Maximalen clim begrenzen damit Ringe sichtbar bleiben
% Median + n*MAD als robuste Obergrenze
% if isfield(opts, 'climMax') && ~isempty(opts.climMax)
%     clims(2) = min(clims(2), opts.climMax);
% end

% In Axes zeichnen – x = 2theta, y = chi
cla(ax);
% Alle Children explizit löschen
delete(ax.Children);
hold(ax, 'on');
imagesc(ax, y, chi, Iplot.');   % Iplot transponiert weil Achsen getauscht
ax.YDir = 'normal';
clim(ax, clims);
colorbar(ax);
ax.XLabel.String = ylab;           % 2theta auf x
ax.YLabel.String = '\chi (deg)';   % chi auf y
ax.Title.String  = 'Caked 2D Image';

% Theoretische Peaklagen einzeichnen (falls vorhanden)
if isfield(opts, 'peakPos') && ~isempty(opts.peakPos)
    hold(ax, 'on');
    for k = 1:numel(opts.peakPos)
        xline(ax, opts.peakPos(k), '--w', 'LineWidth', 1.2, ...
            'HandleVisibility', 'off');
        if isfield(opts, 'peakLabels') && numel(opts.peakLabels) >= k
            % Label am oberen Rand der chi-Achse platzieren
            chiMax = max(chi);
            chiMin = min(chi);
            labelY = chiMax - 0.05 * (chiMax - chiMin);  % 5% vom oberen Rand
        
            text(ax, opts.peakPos(k), labelY, opts.peakLabels{k}, ...
                'Color',               [1 1 0], ...   % gelb – gut sichtbar auf colormap
                'FontSize',            14, ...
                'FontWeight',          'bold', ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment',   'bottom', ...
                'Rotation',            90, ...
                'BackgroundColor',     'none');
        end
    end
    hold(ax, 'off');
end
drawnow;

% TIF exportieren
if opts.saveTif
    try
        fig_tmp = figure('Visible','off');
        ax_tmp  = copyobj(ax, fig_tmp);
        ax_tmp.Units    = 'normalized';
        ax_tmp.Position = [0.08 0.08 0.88 0.88];

        % Label für Export anpassen
        ax_tmp.XLabel.String   = '2\theta (°)';
        ax_tmp.YLabel.String   = '\chi (°)';
        ax_tmp.Title.String    = '';           % kein Titel im Export
        ax_tmp.XLabel.FontSize = 14;
        ax_tmp.YLabel.FontSize = 14;
        ax_tmp.FontSize        = 12;

        % xline-Label anpassen – alle ConstantLine-Objekte suchen
        children = ax_tmp.Children;
        for k = 1:numel(children)
            if isa(children(k), 'matlab.graphics.chart.decoration.ConstantLine')
                % Label direkt über die Label-Eigenschaft
                children(k).Label          = children(k).Label;  % beibehalten
                children(k).LabelFontSize  = 8;
                children(k).LabelHorizontalAlignment = 'left';
                children(k).LabelVerticalAlignment   = 'top';
                % Oder Label komplett entfernen:
                % children(k).Label = '';
            end
        end

        % Alle Line-Objekte in ax_tmp suchen
        allObjs = findall(ax_tmp);
        for k = 1:numel(allObjs)
            try
                if isprop(allObjs(k), 'LineWidth') && isprop(allObjs(k), 'LineStyle')
                    if strcmp(allObjs(k).LineStyle, '--')
                        allObjs(k).LineWidth = 0.4;
                    end
                end
            catch
            end
        end

         % Text-Objekte in der kopierten Axes anpassen
        textObjs = findobj(ax_tmp, 'Type', 'Text');
        for k = 1:numel(textObjs)
            textObjs(k).FontSize = 8;      % kleinere Schrift im Export
            textObjs(k).Color    = [1 1 0]; % Farbe beibehalten
        end

        exportgraphics(fig_tmp, opts.tifPath, ...
            'Resolution',  opts.resolution, ...
            'ContentType', 'image');
        close(fig_tmp);
        fprintf('Caked 2D Image gespeichert: %s\n', opts.tifPath);
    catch ME
        warning('[plotCaked2DInAxes] TIF-Export fehlgeschlagen: %s', ME.message);
    end
end

end

function opts = applyLocalDefaults(opts, def)
f = fieldnames(def);
for i = 1:numel(f)
    if ~isfield(opts, f{i}) || isempty(opts.(f{i}))
        opts.(f{i}) = def.(f{i});
    end
end
end