function [acceptFilter, sigmaThresh, windowSize] = showOutlierFilterDialog(h, FitDataMod, DEK, filterOpts)
% Zeigt einen Dialog zur Überprüfung des Ausreißerfilters vor dem Stressfit
%
% Returns:
%   acceptFilter  - true = gefilterte Daten verwenden
%   sigmaThresh   - ggf. vom User angepasster Schwellenwert
%   windowSize    - ggf. vom User angepasste Fenstergröße

nPeaks      = size(FitDataMod, 1);
sigmaThresh = filterOpts.sigmaThresh;
windowSize  = filterOpts.windowSize;

% ── Dialog-Figur erstellen ────────────────────────────────────────────
fig = figure('Name', 'Ausreißerfilter — Vorschau vor Stressfit', ...
    'NumberTitle', 'off', ...
    'Units',       'normalized', ...
    'Position',    [0.05 0.05 0.90 0.88], ...
    'CloseRequestFcn', @onClose);

% ── Layout: Steuerbereich oben, Plots darunter ───────────────────────
% Steuerbereich
uicontrol(fig, 'Style','text', 'Units','normalized', ...
    'Position', [0.01 0.945 0.12 0.030], ...
    'String', 'Sigma-Schwelle:', ...
    'HorizontalAlignment', 'left', 'FontSize', 10);

edSigma = uicontrol(fig, 'Style','edit', 'Units','normalized', ...
    'Position', [0.13 0.947 0.06 0.030], ...
    'String', num2str(sigmaThresh), ...
    'FontSize', 10, 'Tag', 'edSigma');

uicontrol(fig, 'Style','text', 'Units','normalized', ...
    'Position', [0.21 0.945 0.10 0.030], ...
    'String', 'Fenstergröße:', ...
    'HorizontalAlignment', 'left', 'FontSize', 10);

edWindow = uicontrol(fig, 'Style','edit', 'Units','normalized', ...
    'Position', [0.31 0.947 0.05 0.030], ...
    'String', num2str(windowSize), ...
    'FontSize', 10, 'Tag', 'edWindow');

btnUpdate = uicontrol(fig, 'Style','pushbutton', 'Units','normalized', ...
    'Position', [0.38 0.945 0.12 0.034], ...
    'String', '↻ Vorschau aktualisieren', ...
    'FontSize', 10, ...
    'Callback', @onUpdate);

% Info-Text
txtInfo = uicontrol(fig, 'Style','text', 'Units','normalized', ...
    'Position', [0.52 0.945 0.28 0.030], ...
    'String', '', ...
    'HorizontalAlignment', 'left', ...
    'FontSize', 9, 'ForegroundColor', [0.6 0.1 0.1]);

% Entscheidungs-Buttons
btnAccept = uicontrol(fig, 'Style','pushbutton', 'Units','normalized', ...
    'Position', [0.82 0.943 0.08 0.038], ...
    'String', '✓ Filter anwenden', ...
    'FontSize', 10, 'FontWeight', 'bold', ...
    'BackgroundColor', [0.2 0.7 0.3], ...
    'Callback', @onAccept);

btnReject = uicontrol(fig, 'Style','pushbutton', 'Units','normalized', ...
    'Position', [0.91 0.943 0.08 0.038], ...
    'String', '✗ Ohne Filter', ...
    'FontSize', 10, ...
    'BackgroundColor', [0.85 0.85 0.85], ...
    'Callback', @onReject);

% ── Axes für jeden Peak erstellen ────────────────────────────────────
nCols = min(nPeaks, 3);
nRows = ceil(nPeaks / nCols);

axArr = gobjects(nPeaks, 1);
for pk = 1:nPeaks
    row = ceil(pk / nCols);
    col = mod(pk-1, nCols) + 1;

    axW  = 0.30;
    axH  = 0.85 / nRows - 0.04;
    axX  = (col-1) * (axW + 0.03) + 0.03;
    axY  = 0.92 - row * (axH + 0.04);

    axArr(pk) = axes('Parent', fig, ...
        'Units',    'normalized', ...
        'Position', [axX, axY, axW, axH]);
    box(axArr(pk), 'on');
    grid(axArr(pk), 'on');
    xlabel(axArr(pk), '\gamma [°]', 'FontSize', 9);
    ylabel(axArr(pk), '2\theta [°]', 'FontSize', 9);
end

% ── Ergebnis-Variablen ────────────────────────────────────────────────
result.accepted     = false;
result.sigmaThresh  = sigmaThresh;
result.windowSize   = windowSize;
result.done         = false;

% Ersten Plot zeichnen
drawPreviews();

% ── Warten bis User entschieden hat ──────────────────────────────────
waitfor(fig, 'UserData', 'done');

% Ergebnis auslesen
if ishandle(fig)
    ud = get(fig, 'UserData');
    if isstruct(ud)
        acceptFilter = ud.accepted;
        sigmaThresh  = ud.sigmaThresh;
        windowSize   = ud.windowSize;
    else
        acceptFilter = false;
    end
    close(fig);
else
    acceptFilter = false;
end

% =====================================================================
% Nested Functions
% =====================================================================

    function drawPreviews()
        sigVal = str2double(get(edSigma,  'String'));
        winVal = round(str2double(get(edWindow, 'String')));
        if isnan(sigVal) || sigVal <= 0, sigVal = 3.0; end
        if isnan(winVal) || winVal < 3,  winVal = 7;   end
        if mod(winVal, 2) == 0, winVal = winVal + 1; end

        totalRemoved = 0;
        totalPoints  = 0;

        for p = 1:nPeaks
            cla(axArr(p));
            hold(axArr(p), 'on');

            mat      = FitDataMod{p};
            gamma_p  = mat(:, 1);
            tth_p    = mat(:, 2);
            tthErr_p = mat(:, 3);

            fOpts.windowSize   = winVal;
            fOpts.sigmaThresh  = sigVal;
            fOpts.useErrWeight = true;

            finiteMask = isfinite(tth_p) & isfinite(tthErr_p) & ...
                         (tth_p ~= 0) & (tthErr_p > 0);

            [~, outlMask] = filterOutliersByLocalTrend(...
                gamma_p, tth_p, tthErr_p, fOpts);

            keepMask = finiteMask & ~outlMask;
            remMask  = finiteMask &  outlMask;

            totalPoints  = totalPoints  + sum(finiteMask);
            totalRemoved = totalRemoved + sum(remMask);

            % Alle gültigen Punkte (blau)
            errorbar(axArr(p), gamma_p(keepMask), tth_p(keepMask), ...
                tthErr_p(keepMask), 's', ...
                'Color',           [0.094 0.373 0.647], ...
                'MarkerFaceColor', [0.094 0.373 0.647], ...
                'MarkerSize', 4, 'LineWidth', 0.8);

            % Ausreißer (rot, größer)
            if any(remMask)
                errorbar(axArr(p), gamma_p(remMask), tth_p(remMask), ...
                    tthErr_p(remMask), 'v', ...
                    'Color',           [0.85 0.15 0.15], ...
                    'MarkerFaceColor', [0.85 0.15 0.15], ...
                    'MarkerSize', 7, 'LineWidth', 1.0);
            end

            % hkl-Label aus DEK
            if size(DEK, 1) >= p && any(DEK(p, 1:3) ~= 0)
                hklStr = sprintf('%d%d%d', DEK(p,1), DEK(p,2), DEK(p,3));
                alphaVal = DEK(p, 7);
                titleStr = sprintf('Peak %d  |  hkl=%s  |  α=%.1f°  |  %d entfernt', ...
                    p, hklStr, alphaVal, sum(remMask));
            else
                titleStr = sprintf('Peak %d  |  %d Punkte entfernt', ...
                    p, sum(remMask));
            end
            title(axArr(p), titleStr, 'FontSize', 9);

            % Y-Achse automatisch auf gültige Punkte skalieren
            if any(keepMask)
                yVals  = tth_p(keepMask);
                yRange = max(max(yVals) - min(yVals), 0.01);
                axArr(p).YLim = [min(yVals) - yRange*0.15, ...
                                 max(yVals) + yRange*0.15];
            end
            axArr(p).XLim = [-90 10];
        end

        % Info-Text aktualisieren
        set(txtInfo, 'String', sprintf(...
            'Gesamt: %d/%d Punkte als Ausreißer markiert (%.1f%%)', ...
            totalRemoved, totalPoints, ...
            100*totalRemoved/max(totalPoints,1)));
    end

    function onUpdate(~, ~)
        drawPreviews();
    end

    function onAccept(~, ~)
        ud.accepted    = true;
        ud.sigmaThresh = str2double(get(edSigma,  'String'));
        ud.windowSize  = round(str2double(get(edWindow, 'String')));
        set(fig, 'UserData', ud);
    end

    function onReject(~, ~)
        ud.accepted    = false;
        ud.sigmaThresh = str2double(get(edSigma,  'String'));
        ud.windowSize  = round(str2double(get(edWindow, 'String')));
        set(fig, 'UserData', ud);
    end

    function onClose(~, ~)
        ud.accepted = false;
        ud.done     = true;
        set(fig, 'UserData', ud);
    end

end