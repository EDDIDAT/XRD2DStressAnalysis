function h = updateHeaterPlot(h)
% UPDATEHEATERPLOT  Zeichnet den Heizer-Plot unter Waterfall/Heatmap.
% Zeitachse aus log_all.txt und CSV werden über datetime synchronisiert.

if ~isfield(h, 'heaterData') || isempty(h.heaterData), return; end
if ~isfield(h, 'dataset')    || isempty(h.dataset),    return; end

hd  = h.heaterData;
ax  = h.axesHeater;

% Gewählte Spalte aus Popup
colOpts = get(h.HeaterColPopup, 'String');
colIdx  = get(h.HeaterColPopup, 'Value');
if isempty(colOpts) || colIdx > numel(colOpts), return; end
colName  = colOpts{colIdx};
colField = matlab.lang.makeValidName(colName);

if ~isfield(hd, colField), return; end

% Zeit-Vektor der CSV in Minuten (relativ zur ersten XRD-Messung)
t_csv = hd.time_min;
y_csv = hd.(colField);

% XRD-Zeitpunkte für Markierungen (senkrechte Linien)
t_xrd = [h.dataset.time_s]' / 60;

% ── Plot ────────────────────────────────────────────────────────────
cla(ax);
hold(ax, 'on');

% CSV-Kurve
p1 = plot(ax, t_csv, y_csv, '-', ...
    'Color', [0.85 0.15 0.10], 'LineWidth', 1.5, ...
    'DisplayName', colName);

% XRD-Messpunkte als graue Punkte auf der Kurve
t_xrd_valid = t_xrd(t_xrd >= min(t_csv) & t_xrd <= max(t_csv));
if ~isempty(t_xrd_valid)
    y_xrd = interp1(t_csv, y_csv, t_xrd_valid, 'linear');
    p2 = plot(ax, t_xrd_valid, y_xrd, 'o', ...
        'MarkerSize', 3, ...
        'MarkerFaceColor', [0.3 0.3 0.3], ...
        'MarkerEdgeColor', [0.3 0.3 0.3], ...
        'LineStyle',  'none', ...
        'DisplayName', 'XRD-Messzeitpunkte');
end

% T_max berechnen
[~, idxMax] = max(y_csv);
h.tmax_min  = t_csv(idxMax);
h.tmax_val  = y_csv(idxMax);

% T_max-Marker
p3 = plot(ax, h.tmax_min, h.tmax_val, 'v', ...
    'MarkerSize',      9, ...
    'MarkerFaceColor', [0.9 0.1 0.1], ...
    'MarkerEdgeColor', [0.5 0.0 0.0], ...
    'LineStyle',       'none', ...
    'DisplayName',     sprintf('T_{max} = %.0f°C  (t = %.1f min)', ...
                               h.tmax_val, h.tmax_min));

hold(ax, 'off');

% ── Achsen-Formatierung ───────────────────────────────────────────────
ax.XLabel.String = 'Zeit (min)';
ax.YLabel.String = sprintf('%s (°C)', colName);
ax.Title.String  = '';
box(ax, 'on');

% X-Achse auf Datenbereich
xMin = min(t_csv);
xMax = max(t_csv);
if isfinite(xMin) && xMax > xMin
    ax.XLim = [xMin xMax];
end

% Y-Achse: saubere 100°-Schritte
yMin_raw = min(y_csv);
yMax_raw = max(y_csv);
if isfinite(yMin_raw) && isfinite(yMax_raw) && yMax_raw > yMin_raw
    yLo = floor(yMin_raw / 100) * 100;    % auf 100 abrunden
    yHi = ceil(yMax_raw  / 100) * 100;    % auf 100 aufrunden
    % mindestens 1 Stufe Puffer oben
    if yHi <= yMax_raw, yHi = yHi + 100; end
    ax.YLim  = [yLo  yHi];
    ax.YTick = yLo:100:yHi;
end
ax.YTickLabelRotation = 0;

% ── Legende ──────────────────────────────────────────────────────────
lgd = legend(ax, 'Location', 'northwest', 'FontSize', 7);
lgd.Box = 'on';

% T_max-Linie in Heatmap aktualisieren
h = updateTmaxLine(h);

% ── X-Achsen-Synchronisation + horizontale Ausrichtung ──────────────
if isfield(h, 'axesTimeSeries') && isvalid(h.axesTimeSeries)
    try
        selectedMode = get(h.TimeSeriesModeGroup.SelectedObject, 'String');
        if ismember(selectedMode, {'Waterfall', 'Heatmap'})
            % XLim synchronisieren
            ax.XLim = h.axesTimeSeries.XLim;

            % ── Horizontale Ausrichtung ───────────────────────────────
            % axesTimeSeries liegt im Tab (h.plottab8), axesHeater in
            % h.myfig. Wir lesen die tatsächliche innere Plot-Position
            % von axesTimeSeries aus (in Tab-Koordinaten) und rechnen
            % sie in myfig-Koordinaten um.
            %
            % Tab-Position in myfig:  x=RX, y=0.13, w=MW, h=0.84
            % (aus dem Haupt-GUI-Code: RX=LW+GAP=0.236, MW=0.515)
            RX_fig = 0.236;   % linker Rand des Tab-Bereichs in myfig
            MW_fig = 0.515;   % Breite des Tab-Bereichs in myfig

            % X_OFFSET: Feinkorrektur für horizontale Ausrichtung.
            % Positiv = nach rechts, Negativ = nach links.
            % Anpassen bis linke Achsenkante mit Heatmap fluchtet.
            X_OFFSET = -0.0005;

            % Innere Position der Heatmap-Axes auslesen (Tab-relativ)
            drawnow;   % MATLAB Position berechnen lassen
            posTS = h.axesTimeSeries.Position;  % [x y w h] in Tab-Koordinaten

            % Umrechnung Tab-relativ → myfig-absolut
            inner_x_fig     = RX_fig + posTS(1) * MW_fig + X_OFFSET;
            inner_right_fig = RX_fig + (posTS(1) + posTS(3)) * MW_fig + X_OFFSET;
            inner_w_fig     = inner_right_fig - inner_x_fig;

            % axesHeater anpassen
            posH    = ax.Position;
            posH(1) = inner_x_fig;
            posH(3) = inner_w_fig;
            ax.Position = posH;
        end
    catch
    end
end
end  % updateHeaterPlot