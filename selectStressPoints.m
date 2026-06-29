function pointslist = selectStressPoints(ax, hData)
% SELECTSTRESSPOINTS  Interaktive Lasso-Auswahl von Datenpunkten im Stress-Plot.
%
%   pointslist = selectStressPoints(ax, hData)
%
%   Gibt Indizes in das vollständige XData/YData-Array zurück
%   (inklusive NaN-Einträge), damit die Korrespondenz zu FitDataMod
%   erhalten bleibt.
%
%   Bedienung:
%     - Linke Maustaste gedrückt halten und Lasso ziehen
%     - Maustaste loslassen → Dialog zur Bestätigung
%     - "Ja, löschen" → Punkte werden zurückgegeben
%     - "Wiederholen"  → Auswahl wiederholen
%     - "Abbrechen"    → leere Liste

pointslist = [];

xdata = get(hData, 'XData');
ydata = get(hData, 'YData');

if isempty(xdata) || isempty(ydata), return; end

xdata = xdata(:);
ydata = ydata(:);

% finIdx: Indizes der finiten Punkte im vollständigen Array
% WICHTIG: diese Indizes werden direkt als pointslist zurückgegeben
% damit sie korrekt auf FitDataMod-Zeilen mappen
finMask   = isfinite(xdata) & isfinite(ydata);
xdata_fin = xdata(finMask);
ydata_fin = ydata(finMask);
finIdx    = find(finMask);   % Indizes im vollständigen xdata-Array

if isempty(xdata_fin), return; end

fig = ancestor(ax, 'figure');

LASSO_COLOR     = [0.20 0.45 0.75];
HIGHLIGHT_COLOR = [0.85 0.10 0.10];

% State
xv          = [];
yv          = [];
lassoH      = [];
highlightH  = [];
roundResult = [];

% =====================================================================
% Hauptschleife
% =====================================================================
while true

    xv = [];  yv = [];  roundResult = [];

    % Alte Objekte bereinigen
    safeDelete(lassoH);     lassoH     = [];
    safeHide(highlightH);

    oldPointer = get(fig, 'Pointer');
    set(fig, 'Pointer', 'crosshair');

    set(fig, 'WindowButtonDownFcn',   @onButtonDown);
    set(fig, 'WindowButtonMotionFcn', '');
    set(fig, 'WindowButtonUpFcn',     '');

    uiwait(fig);

    set(fig, 'Pointer',               oldPointer);
    set(fig, 'WindowButtonDownFcn',   '');
    set(fig, 'WindowButtonMotionFcn', '');
    set(fig, 'WindowButtonUpFcn',     '');

    safeDelete(lassoH);  lassoH = [];

    % Punkte im Polygon – inside ist Index in finIdx
    if numel(xv) >= 3
        inside = inpolygon(xdata_fin, ydata_fin, xv, yv);
        % roundResult: Indizes im vollständigen xdata-Array (→ FitDataMod-Zeilen)
        roundResult = finIdx(inside);
    end

    % Highlight zeigen
    updateHighlight(roundResult);
    drawnow;

    % Dialog
    if isempty(roundResult)
        btn = questdlg('Keine Punkte ausgewählt.', ...
            'Auswahl', 'Wiederholen', 'Abbrechen', 'Wiederholen');
    else
        btn = questdlg( ...
            sprintf('%d Punkt(e) ausgewählt. Löschen?', numel(roundResult)), ...
            'Auswahl bestätigen', ...
            'Ja, löschen', 'Wiederholen', 'Abbrechen', 'Ja, löschen');
    end

    % Highlight immer entfernen
    safeHide(highlightH);
    drawnow;
    pause(0.05);
    drawnow;

    switch btn
        case 'Ja, löschen'
            pointslist = roundResult;
            return
        case 'Wiederholen'
            % weiter
        otherwise
            pointslist = [];
            return
    end

end % while

% =====================================================================
% Nested callbacks
% =====================================================================
    function onButtonDown(~, ~)
        if ~strcmp(get(fig, 'SelectionType'), 'normal'), return; end
        cp = getAxesPoint();
        if isempty(cp), return; end
        xv = cp(1);
        yv = cp(2);
        hold(ax, 'on');
        lassoH = plot(ax, xv, yv, '-', ...
            'Color', LASSO_COLOR, 'LineWidth', 1.5, ...
            'HandleVisibility', 'off');
        set(fig, 'WindowButtonMotionFcn', @onMotion);
        set(fig, 'WindowButtonUpFcn',     @onButtonUp);
    end

    function onMotion(~, ~)
        if isempty(xv), return; end
        cp = getAxesPoint();
        if isempty(cp), return; end
        xv(end+1) = cp(1); %#ok<AGROW>
        yv(end+1) = cp(2); %#ok<AGROW>
        if isvalid(lassoH)
            set(lassoH, 'XData', [xv xv(1)], 'YData', [yv yv(1)]);
        end
        if numel(xv) >= 3
            inside = inpolygon(xdata_fin, ydata_fin, [xv xv(1)], [yv yv(1)]);
            sel    = finIdx(inside);
            updateHighlight(sel);
        end
        drawnow limitrate;
    end

    function onButtonUp(~, ~)
        if numel(xv) >= 2
            xv(end+1) = xv(1); %#ok<AGROW>
            yv(end+1) = yv(1); %#ok<AGROW>
        end
        set(fig, 'WindowButtonMotionFcn', '');
        set(fig, 'WindowButtonUpFcn',     '');
        uiresume(fig);
    end

% =====================================================================
% Hilfsfunktionen
% =====================================================================

    function cp = getAxesPoint()
        cp = [];
        try
            pt = get(ax, 'CurrentPoint');
            cp = pt(1, 1:2);
        catch
        end
    end

    function updateHighlight(sel)
        if isempty(sel)
            safeHide(highlightH);
            return
        end
        if isempty(highlightH) || ~isvalid(highlightH)
            hold(ax, 'on');
            highlightH = plot(ax, xdata(sel), ydata(sel), 'o', ...
                'Color',            HIGHLIGHT_COLOR, ...
                'MarkerFaceColor',  HIGHLIGHT_COLOR, ...
                'MarkerSize',       10, ...
                'HandleVisibility', 'off');
        else
            set(highlightH, ...
                'XData',   xdata(sel), ...
                'YData',   ydata(sel), ...
                'Visible', 'on');
        end
    end

    function safeHide(h_)
        if ~isempty(h_) && isvalid(h_)
            try
                set(h_, 'XData', NaN, 'YData', NaN, 'Visible', 'off');
            catch
            end
        end
    end

    function safeDelete(h_)
        if ~isempty(h_) && isvalid(h_)
            try
                delete(h_);
            catch
            end
        end
    end

end