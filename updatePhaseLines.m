function h = updatePhaseLines(h)
% UPDATEPHASELINES  Zeichnet theoretische Reflexlinien in Heatmap/Waterfall
% und Single Profile. Bis zu 3 Phasen, je nach Checkbox-Status.

if ~isfield(h, 'phaseData') || ~isfield(h, 'axesTimeSeries'), return; end

% Alte Linien löschen
if isfield(h, 'hPhaseLines')
    for ph = 1:numel(h.hPhaseLines)
        try
            delete(h.hPhaseLines{ph}(isvalid(h.hPhaseLines{ph})));
        catch; end
    end
end
h.hPhaseLines = cell(3,1);

if isfield(h, 'hPhaseLinesProfile')
    for ph = 1:numel(h.hPhaseLinesProfile)
        try
            delete(h.hPhaseLinesProfile{ph}(isvalid(h.hPhaseLinesProfile{ph})));
        catch; end
    end
end
h.hPhaseLinesProfile = cell(3,1);

% Aktueller Modus + X-Achsen-Modus
selectedMode = get(h.TimeSeriesModeGroup.SelectedObject, 'String');
use2theta    = isfield(h, 'TimeSeriesXAxisGroup') && ...
               isvalid(h.TimeSeriesXAxisGroup) && ...
               strcmp(get(h.TimeSeriesXAxisGroup.SelectedObject,'String'),'2θ');

for ph = 1:3
    % Checkbox-Status
    if ~isfield(h,'cbPhase') || ~isvalid(h.cbPhase(ph)), continue; end
    if get(h.cbPhase(ph), 'Value') == 0, continue; end
    if isempty(h.phaseData{ph}), continue; end

    pd    = h.phaseData{ph};
    col   = h.phaseColors{ph};

    % X-Position der Reflexe je nach Modus
    if use2theta
        xPos = pd.tth;
        xUnit = '2θ';
    else
        if ~isempty(pd.q_ang)
            xPos = pd.q_ang;
        else
            xPos = pd.q_nm / 10;
        end
        xUnit = 'q';
    end

    % ── Heatmap: horizontale Linien bei q/2θ auf der Y-Achse ───────────
    if strcmp(selectedMode, 'Heatmap') && isvalid(h.axesTimeSeries)
        yLim  = h.axesTimeSeries.YLim;
        xLim  = h.axesTimeSeries.XLim;
        % Nur Reflexe innerhalb der Y-Achse zeichnen
        xPosInRange = xPos(xPos >= yLim(1) & xPos <= yLim(2));
        hold(h.axesTimeSeries, 'on');
        lines = gobjects(numel(xPosInRange), 1);
        for r = 1:numel(xPosInRange)
            lines(r) = plot(h.axesTimeSeries, ...
                xLim, [xPosInRange(r) xPosInRange(r)], ...
                '--', 'Color', [col 0.8], 'LineWidth', 1.0);
        end
        hold(h.axesTimeSeries, 'off');
        h.hPhaseLines{ph} = lines;
    end

    % ── Waterfall: vertikale Linien bei q/2θ auf der X-Achse ─────────
    if strcmp(selectedMode, 'Waterfall') && isvalid(h.axesTimeSeries)
        xLim  = h.axesTimeSeries.XLim;
        yLim2 = h.axesTimeSeries.YLim;
        xPosInRange = xPos(xPos >= xLim(1) & xPos <= xLim(2));
        hold(h.axesTimeSeries, 'on');
        lines = gobjects(numel(xPosInRange), 1);
        for r = 1:numel(xPosInRange)
            lines(r) = plot(h.axesTimeSeries, ...
                [xPosInRange(r) xPosInRange(r)], yLim2, ...
                '--', 'Color', [col 0.8], 'LineWidth', 1.0);
        end
        hold(h.axesTimeSeries, 'off');
        h.hPhaseLines{ph} = lines;
    end

    % ── Single Profile / CBF Viewer: vertikale Linien ────────────────
    if ismember(selectedMode, {'Single Profile', 'CBF Viewer'}) && ...
       isfield(h,'axesTimeProfile') && isvalid(h.axesTimeProfile)
        % X-Achsenbereich VOR dem Zeichnen merken und danach wiederherstellen
        xlim_before = h.axesTimeProfile.XLim;
        hold(h.axesTimeProfile, 'on');
        lines_p = gobjects(numel(xPos), 1);
        for r = 1:numel(xPos)
            lines_p(r) = xline(h.axesTimeProfile, xPos(r), ...
                '--', 'Color', col, 'LineWidth', 0.9);
        end
        hold(h.axesTimeProfile, 'off');
        % X-Achse auf originalen Bereich zurücksetzen
        h.axesTimeProfile.XLim = xlim_before;
        h.hPhaseLinesProfile{ph} = lines_p;
    end
end
end  % updatePhaseLines