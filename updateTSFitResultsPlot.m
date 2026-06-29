function h = updateTSFitResultsPlot(h)
% Peak-Fit-Ergebnisse vs. Zeit in axesTSFitResults plotten
if ~isfield(h,'tsFitResults') || isempty(h.tsFitResults), return; end
r = h.tsFitResults;

% Welche Eigenschaft anzeigen?
propIdx = 1;
if isfield(h,'TSFitResultPopup') && isvalid(h.TSFitResultPopup)
    propIdx = get(h.TSFitResultPopup,'Value');
end
props   = {'peakPos','amplitude','fwhm','R2'};
ylabels = {r.xUnit, 'Amplitude (a.u.)', 'FWHM', 'R²'};
propName = props{propIdx};
yLabel   = ylabels{propIdx};

cla(h.axesTSFitResults);
hold(h.axesTSFitResults,'on');

nPeaks = size(r.peakPos,2);
colors = lines(nPeaks);
hasTemp = any(isfinite(r.temperature));
xVec    = r.time_min;   % immer Zeit auf X

for pk = 1:nPeaks
    yVec   = r.(propName)(:, pk);
    yErr   = [];
    if strcmp(propName,'peakPos'), yErr = r.peakPosErr(:,pk); end

    idxFin = isfinite(yVec) & isfinite(xVec);
    if ~any(idxFin), continue; end

    if ~isempty(yErr)
        errorbar(h.axesTSFitResults, xVec(idxFin), yVec(idxFin), ...
            abs(yErr(idxFin)), 's-', ...
            'Color', colors(pk,:), 'MarkerFaceColor', colors(pk,:), ...
            'MarkerSize', 3, 'LineWidth', 0.8, ...
            'DisplayName', sprintf('Peak %d', pk));
    else
        plot(h.axesTSFitResults, xVec(idxFin), yVec(idxFin), 's-', ...
            'Color', colors(pk,:), 'MarkerFaceColor', colors(pk,:), ...
            'MarkerSize', 3, 'LineWidth', 0.8, ...
            'DisplayName', sprintf('Peak %d', pk));
    end

    % Falls Temperatur vorhanden: zweite X-Achse (yyaxis nicht in uiaxes)
    % → Temperatur als grauer Hintergrundlinie anzeigen
    if hasTemp && pk == 1
        yyT = r.temperature;
        yN  = (yyT - min(yyT(isfinite(yyT))));
        yR  = max(yN);
        if yR > 0
            yN = yN / yR;
            % Skalieren auf Y-Achsenbereich der Peakdaten
            yDataFin = yVec(idxFin);
            yScale   = max(yDataFin) - min(yDataFin);
            if yScale > 0
                yTscaled = min(yDataFin) + yN * yScale;
                plot(h.axesTSFitResults, xVec, yTscaled, '-', ...
                    'Color',[0.8 0.8 0.8], 'LineWidth',0.7, ...
                    'DisplayName','T (skaliert)');
            end
        end
    end
end

h.axesTSFitResults.XLabel.String = 'Zeit (min)';
h.axesTSFitResults.YLabel.String = yLabel;
h.axesTSFitResults.Title.String  = 'Time Series Peak-Fit';
if nPeaks > 1
    legend(h.axesTSFitResults,'Location','best','FontSize',7);
end
box(h.axesTSFitResults,'on');
grid(h.axesTSFitResults,'on');