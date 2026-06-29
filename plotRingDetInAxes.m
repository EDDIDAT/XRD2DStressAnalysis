function plotRingDetInAxes(ax, ringDet, opts)
% PLOTRINGDETINAXES  Zeigt das Pixel-Ringbild in einer uiaxes und
%                   zeichnet theoretische Debye-Scherrer-Ringe ein.
%
%   ax      – Ziel-uiaxes Handle
%   ringDet – struct mit: ring_mean, x_centers_mm, y_centers_mm
%   opts    – struct mit optionalen Feldern:
%               useLog      : true (default)
%               logStrength : 1 (default)
%               climPct     : [1 99] (default)
%               peakPos     : Vektor mit 2theta-Werten [deg]
%               peakLabels  : Cell-Array mit hkl-Strings
%               sdd_mm      : Proben-Detektor-Abstand [mm]
%               center_x_mm : Strahlmitte x [mm]
%               center_y_mm : Strahlmitte y [mm]

if nargin < 3, opts = struct(); end
if ~isfield(opts,'useLog'),      opts.useLog      = true;  end
if ~isfield(opts,'logStrength'), opts.logStrength = 1;     end
if ~isfield(opts,'climPct'),     opts.climPct     = [1 99];end
if ~isfield(opts,'useGeometricRings'), opts.useGeometricRings = false; end

% ---- Bild vorbereiten ----
img = double(ringDet.ring_mean);

if opts.useLog
    img = log10(1 + opts.logStrength .* max(img, 0));
end

v = img(isfinite(img) & img > 0);
if isempty(v)
    clims = [0 1];
else
    clims = prctile(v, opts.climPct);
end
if clims(1) >= clims(2)
    clims(2) = clims(1) + 1;
end


% ---- Theoretische Ringe einzeichnen ----
hasPeaks  = isfield(opts,'peakPos')     && ~isempty(opts.peakPos);
hasSDD    = isfield(opts,'sdd_mm')      && ~isempty(opts.sdd_mm) && isfinite(opts.sdd_mm);
hasCenter = isfield(opts,'center_x_mm') && ~isempty(opts.center_x_mm) && ...
            isfield(opts,'center_y_mm') && ~isempty(opts.center_y_mm);

% ---- Bild zeichnen ----
cla(ax);
hold(ax, 'on');

imagesc(ax, ringDet.x_centers_mm, ringDet.y_centers_mm, img);
ax.YDir          = 'reverse'; % normal
clim(ax, clims);
colorbar(ax);
colormap(ax, 'hot');
ax.XLabel.String = 'x_{lab} (mm)';
ax.YLabel.String = 'y_{lab} (mm)';
ax.Title.String  = 'Ring Image – Pixel Space';

% Schwarzer Hintergrund
ax.Color         = [0 0 0];
ax.GridColor     = [0.3 0.3 0.3];
ax.XColor        = [0 0 0];
ax.YColor        = [0 0 0];
ax.Title.Color   = [0 0 0];
ax.XLabel.Color  = [0 0 0];
ax.YLabel.Color  = [0 0 0];

% Achsenlimits: Kreise vollständig anzeigen
% Maximaler Ringradius aus peakPos und SDD berechnen
if hasPeaks && hasSDD
    % Achsenlimits: nur Bereich mit Detektordaten
    ax.XLim = [min(ringDet.x_centers_mm) max(ringDet.x_centers_mm)];
    ax.YLim = [min(ringDet.y_centers_mm) max(ringDet.y_centers_mm)];
else
    axis(ax, 'equal', 'tight');
end

% ---- Theoretische Ringe aus Pixelpositionen ----
if isfield(opts, 'ringPeakData') && ~isempty(opts.ringPeakData) && ...
   hasPeaks && ~opts.useGeometricRings

    for p = 1:numel(opts.peakPos)
        tth_str = sprintf('peak_%.4f', opts.peakPos(p));
        tth_str = strrep(tth_str, '.', 'p');
        xKey    = [tth_str '_x'];
        yKey    = [tth_str '_y'];

        if isfield(opts.ringPeakData, xKey) && isfield(opts.ringPeakData, yKey)
            xRing = double(opts.ringPeakData.(xKey));
            yRing = double(opts.ringPeakData.(yKey));

            % Sortieren für saubere Liniendarstellung
            [xSorted, sortIdx] = sort(xRing);
            ySorted = yRing(sortIdx);
            
            % Ausdünnen
            step = max(1, round(numel(xSorted) / 200));
            plot(ax, xSorted(1:step:end), ySorted(1:step:end), '--', ...
                'Color',            [0 0 1], ...
                'LineWidth',        1.8, ...
                'HandleVisibility', 'off');

            % Label
            if isfield(opts,'peakLabels') && numel(opts.peakLabels) >= p
                % Label: rechts von der Bildmitte, oberhalb des Rings
                xLim = ax.XLim;
                yLim = ax.YLim;
                
                % x-Position: 75% des sichtbaren Bereichs (rechts von Mitte)
                xLabel = xLim(1) + 0.8 * (xLim(2) - xLim(1));
                
                % Nächsten Ring-Punkt zu dieser x-Position suchen
                % Label-Position
                [~, iLabel] = min(abs(xRing - xLabel));
                yLabel  = yRing(iLabel);
                yOffset = yLabel - 3;   % immer -3, kein Vorzeichen-Flip
                
                if xLabel >= xLim(1) && xLabel <= xLim(2) && ...
                   yOffset >= yLim(1) && yOffset <= yLim(2)
                    text(ax, xLabel, yOffset, opts.peakLabels{p}, ...
                        'Color',               [1 1 0], ...
                        'FontSize',            14, ...
                        'FontWeight',          'bold', ...
                        'HorizontalAlignment', 'left', ...
                        'VerticalAlignment',   'bottom', ...
                        'BackgroundColor',     [0 0 0 0.5], ...
                        'EdgeColor',           'none', ...
                        'Margin',              2);
                end
            end
        end
    end

elseif hasPeaks && hasSDD && hasCenter
    % Fallback: geometrische Näherung
    cx = opts.center_x_mm;
    cy = opts.center_y_mm;
    L  = opts.sdd_mm;
    theta_circle = linspace(0, 2*pi, 720);

    for p = 1:numel(opts.peakPos)
        tth_rad = deg2rad(opts.peakPos(p));
        r_mm    = L * tan(tth_rad);
        xc = cx + r_mm * cos(theta_circle);
        yc = cy + r_mm * sin(theta_circle);
        plot(ax, xc, yc, '--', 'Color', [1 1 0], 'LineWidth', 1.2, ...
            'HandleVisibility', 'off');
        if isfield(opts,'peakLabels') && numel(opts.peakLabels) >= p
            text(ax, cx + r_mm, cy, opts.peakLabels{p}, ...
                'Color', [1 1 0], 'FontSize', 8, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
        end
    end
end

hold(ax, 'off');
drawnow;

end