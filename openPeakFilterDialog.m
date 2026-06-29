function [filteredIdx, newOpts] = openPeakFilterDialog(h, peakIdx)
% OPENPEAKFILTERDIALOG  Modaler Filter-Dialog für Peak-Qualitätsfilter.
%
% Öffnet ein separates uifigure mit:
%   - Slidern für R² min, Max error [°], Min SNR
%   - Live-Vorschau des ε(γ)-Plots mit ausgegrauenten gefilterten Punkten
%   - Zählern (Gesamt / Verbleibend / Gefiltert)
%   - "Filter anwenden" und "Abbrechen" Buttons
%
% EINGABE:
%   h        – guidata-Struct der Haupt-GUI
%   peakIdx  – Index in h.FitDataMod (aktueller Slider-Wert)
%
% AUSGABE:
%   filteredIdx – logischer Vektor (true = gefiltert/löschen)
%   newOpts     – aktualisiertes trackFitOpts-Struct

filteredIdx = [];
newOpts     = h.trackFitOpts;

% =====================================================================
% Daten vorbereiten
% =====================================================================
if ~isfield(h, 'FitDataMod') || numel(h.FitDataMod) < peakIdx
    warndlg('Keine FitDataMod-Daten verfügbar.', 'Filter');
    return
end

mat = h.FitDataMod{peakIdx};
if isempty(mat) || size(mat, 1) < 2
    warndlg('Zu wenige Datenpunkte für Filter.', 'Filter');
    return
end

gamma    = mat(:, 1);
tth      = mat(:, 2);   % aktuell verwendete Peaklagen
tthErr   = mat(:, 3);

% R² aus Spalte 13 falls vorhanden
if size(mat, 2) >= 13
    pvR2 = mat(:, 13);
else
    pvR2 = nan(size(mat, 1), 1);
end

% SNR aus pvParams falls vorhanden
snrVec = nan(size(mat, 1), 1);
if isfield(h, 'dataPVParams') && numel(h.dataPVParams) >= peakIdx
    pP = h.dataPVParams{peakIdx};
    for i = 1:min(numel(pP), size(mat,1))
        if ~isempty(pP{i}) && isfield(pP{i}, 'A') && isfield(pP{i}, 'offset')
            denom = max(abs(pP{i}.offset), eps);
            snrVec(i) = pP{i}.A / denom;
        end
    end
end

nPts = size(mat, 1);

% =====================================================================
% Aktuelle Schwellwerte aus trackFitOpts
% =====================================================================
opts = h.trackFitOpts;
if ~isfield(opts, 'pvMinR2Auto'),  opts.pvMinR2Auto = 0.85; end
if ~isfield(opts, 'pvMaxErrDeg'),  opts.pvMaxErrDeg = 0.05; end
if ~isfield(opts, 'pvMinSNR'),     opts.pvMinSNR    = 3.0;  end

curR2  = opts.pvMinR2Auto;
curErr = opts.pvMaxErrDeg;
curSNR = opts.pvMinSNR;

% =====================================================================
% uifigure erstellen
% =====================================================================
fig = uifigure('Name',         'Peak-Qualitätsfilter', ...
               'Position',     [200 150 700 600], ...
               'Resize',       'off', ...
               'WindowStyle',  'modal');

% Hintergrundfarbe
fig.Color = [0.97 0.97 0.97];

% =====================================================================
% Layout: Titel
% =====================================================================
uilabel(fig, ...
    'Position',    [20 560 500 28], ...
    'Text',        sprintf('Peak-Filter  |  Peak %d  |  %d Datenpunkte', peakIdx, nPts), ...
    'FontSize',    14, ...
    'FontWeight',  'bold', ...
    'FontColor',   [0.1 0.2 0.4]);

% =====================================================================
% Slider-Panel (oben)
% =====================================================================
% --- R² min ---
uilabel(fig, 'Position', [20 520 120 20], 'Text', 'R² min', ...
    'FontSize', 11, 'FontWeight', 'bold');
slR2 = uislider(fig, ...
    'Position',    [20 510 200 3], ...
    'Limits',      [0 1], ...
    'Value',       curR2, ...
    'MajorTicks',  [0 0.5 1], ...
    'MinorTicks',  []);
efR2 = uieditfield(fig, 'numeric', ...
    'Position',    [235 502 60 22], ...
    'Value',       curR2, ...
    'Limits',      [0 1], ...
    'FontSize',    11);

% --- Max error ---
uilabel(fig, 'Position', [320 520 160 20], 'Text', 'Max. Fehler [°]', ...
    'FontSize', 11, 'FontWeight', 'bold');
slErr = uislider(fig, ...
    'Position',    [320 510 200 3], ...
    'Limits',      [0.001 0.5], ...
    'Value',       curErr, ...
    'MajorTicks',  [0.001 0.1 0.25 0.5], ...
    'MinorTicks',  []);
efErr = uieditfield(fig, 'numeric', ...
    'Position',    [535 502 60 22], ...
    'Value',       curErr, ...
    'Limits',      [0.001 0.5], ...
    'FontSize',    11);

% --- Min SNR ---
uilabel(fig, 'Position', [20 468 120 20], 'Text', 'Min. SNR', ...
    'FontSize', 11, 'FontWeight', 'bold');
slSNR = uislider(fig, ...
    'Position',    [20 458 200 3], ...
    'Limits',      [0 20], ...
    'Value',       curSNR, ...
    'MajorTicks',  [0 5 10 15 20], ...
    'MinorTicks',  []);
efSNR = uieditfield(fig, 'numeric', ...
    'Position',    [235 450 60 22], ...
    'Value',       curSNR, ...
    'Limits',      [0 20], ...
    'FontSize',    11);

% =====================================================================
% Zähler-Labels
% =====================================================================
uilabel(fig, 'Position', [20 415 80 20],  'Text', 'Gesamt:', ...
    'FontSize', 11, 'FontColor', [0.3 0.3 0.3]);
lblTotal = uilabel(fig, 'Position', [100 415 60 20], ...
    'Text', num2str(nPts), 'FontSize', 11, 'FontWeight', 'bold');

uilabel(fig, 'Position', [200 415 90 20], 'Text', 'Verbleibend:', ...
    'FontSize', 11, 'FontColor', [0.1 0.4 0.7]);
lblKeep = uilabel(fig, 'Position', [295 415 60 20], ...
    'Text', num2str(nPts), 'FontSize', 11, 'FontWeight', 'bold', ...
    'FontColor', [0.1 0.4 0.7]);

uilabel(fig, 'Position', [390 415 70 20], 'Text', 'Gefiltert:', ...
    'FontSize', 11, 'FontColor', [0.7 0.1 0.1]);
lblFilt = uilabel(fig, 'Position', [465 415 60 20], ...
    'Text', '0', 'FontSize', 11, 'FontWeight', 'bold', ...
    'FontColor', [0.7 0.1 0.1]);

% =====================================================================
% Axes für ε(γ)-Vorschau
% =====================================================================
ax = uiaxes(fig, 'Position', [20 100 660 300]);
ax.XLabel.String = [char(947), ' [°]'];
ax.YLabel.String = ['2', char(952), ' [°]'];
ax.Title.String  = ['Peak-Lagen-Vorschau  (grau = gefiltert)'];
ax.FontSize      = 10;
grid(ax, 'on');
box(ax, 'on');
hold(ax, 'on');

% Initialer Plot
idxFin = isfinite(tth);
hKeep = errorbar(ax, gamma(idxFin), tth(idxFin), tthErr(idxFin), ...
    's', 'Color', [0.15 0.45 0.75], ...
    'MarkerFaceColor', [0.15 0.45 0.75], ...
    'MarkerSize', 5, 'DisplayName', 'Gültig');
hFilt = errorbar(ax, nan, nan, nan, ...
    's', 'Color', [0.75 0.75 0.75], ...
    'MarkerFaceColor', [0.85 0.85 0.85], ...
    'MarkerSize', 5, 'DisplayName', 'Gefiltert');
legend(ax, 'Location', 'best', 'FontSize', 9);

% =====================================================================
% Buttons
% =====================================================================
btnApply = uibutton(fig, ...
    'Position',  [480 20 100 36], ...
    'Text',      'Filter anwenden', ...
    'FontSize',  11, ...
    'FontWeight','bold', ...
    'BackgroundColor', [0.15 0.45 0.75], ...
    'FontColor',       [1 1 1]);

btnCancel = uibutton(fig, ...
    'Position',  [370 20 100 36], ...
    'Text',      'Abbrechen', ...
    'FontSize',  11);

% =====================================================================
% Hilfsfunktion: Filter berechnen und Plot aktualisieren
% =====================================================================
    function mask = computeMask(r2Min, errMax, snrMin)
        mask = false(nPts, 1);
        for ii = 1:nPts
            badR2  = isfinite(pvR2(ii))  && pvR2(ii)  < r2Min;
            badErr = isfinite(tthErr(ii)) && tthErr(ii) > errMax;
            badSNR = isfinite(snrVec(ii)) && snrVec(ii) < snrMin;
            mask(ii) = badR2 || badErr || badSNR;
        end
        % Nur Zeilen mit gültiger Peaklage berücksichtigen
        mask(~isfinite(tth)) = false;
    end

    function updatePreview()
        r2Min  = slR2.Value;
        errMax = slErr.Value;
        snrMin = slSNR.Value;

        mask = computeMask(r2Min, errMax, snrMin);

        idxGood = isfinite(tth) & ~mask;
        idxBad  = isfinite(tth) &  mask;

        nKeep = sum(idxGood);
        nFiltN = sum(idxBad);

        lblKeep.Text = num2str(nKeep);
        lblFilt.Text = num2str(nFiltN);
        lblTotal.Text = num2str(nPts);

        % Farbe je nach Filterquote
        if nFiltN / max(nPts,1) > 0.3
            lblFilt.FontColor = [0.7 0.1 0.1];
        else
            lblFilt.FontColor = [0.6 0.3 0.0];
        end

        % Plot aktualisieren
        if any(idxGood)
            set(hKeep, 'XData', gamma(idxGood), ...
                       'YData', tth(idxGood), ...
                       'YNegativeDelta', tthErr(idxGood), ...
                       'YPositiveDelta', tthErr(idxGood));
        else
            set(hKeep, 'XData', nan, 'YData', nan, ...
                       'YNegativeDelta', 0, 'YPositiveDelta', 0);
        end
        if any(idxBad)
            set(hFilt, 'XData', gamma(idxBad), ...
                       'YData', tth(idxBad), ...
                       'YNegativeDelta', tthErr(idxBad), ...
                       'YPositiveDelta', tthErr(idxBad));
        else
            set(hFilt, 'XData', nan, 'YData', nan, ...
                       'YNegativeDelta', 0, 'YPositiveDelta', 0);
        end
        drawnow;
    end

% =====================================================================
% Callbacks: Slider ↔ EditField synchronisieren + Preview updaten
% =====================================================================
slR2.ValueChangedFcn  = @(src,~) syncAndUpdate(src, efR2,  slR2);
efR2.ValueChangedFcn  = @(src,~) syncAndUpdate(src, efR2,  slR2);
slErr.ValueChangedFcn = @(src,~) syncAndUpdate(src, efErr, slErr);
efErr.ValueChangedFcn = @(src,~) syncAndUpdate(src, efErr, slErr);
slSNR.ValueChangedFcn = @(src,~) syncAndUpdate(src, efSNR, slSNR);
efSNR.ValueChangedFcn = @(src,~) syncAndUpdate(src, efSNR, slSNR);

    function syncAndUpdate(src, ef, sl)
        v = src.Value;
        ef.Value = v;
        sl.Value = v;
        updatePreview();
    end

% =====================================================================
% Button-Callbacks
% =====================================================================
btnApply.ButtonPushedFcn = @(~,~) applyFilter();
btnCancel.ButtonPushedFcn = @(~,~) cancelFilter();

    function applyFilter()
        mask = computeMask(slR2.Value, slErr.Value, slSNR.Value);
        if ~any(mask)
            uialert(fig, 'Keine Punkte werden durch den aktuellen Filter entfernt.', ...
                'Hinweis', 'Icon', 'info');
            return
        end
        choice = uiconfirm(fig, ...
            sprintf('%d von %d Punkten werden gelöscht. Fortfahren?', ...
                sum(mask), nPts), ...
            'Filter anwenden', ...
            'Options',     {'Ja, löschen', 'Abbrechen'}, ...
            'DefaultOption', 'Ja, löschen', ...
            'CancelOption',  'Abbrechen', ...
            'Icon', 'warning');
        if strcmp(choice, 'Ja, löschen')
            filteredIdx        = mask;
            newOpts.pvMinR2Auto = slR2.Value;
            newOpts.pvMaxErrDeg = slErr.Value;
            newOpts.pvMinSNR    = slSNR.Value;
            close(fig);
        end
    end

    function cancelFilter()
        filteredIdx = [];
        close(fig);
    end

% Initialen Preview zeichnen
updatePreview();

% =====================================================================
% Modaler Warteblock
% =====================================================================
uiwait(fig);

end