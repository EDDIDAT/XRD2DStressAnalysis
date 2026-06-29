function h = applyTSResultsLayout(h, showResults)
if isfield(h,'axesTSFitResults') && isvalid(h.axesTSFitResults)
    if showResults
        h.axesTSFitResults.Visible = 'on';
    else
        h.axesTSFitResults.Visible = 'off';
    end
end

% function h = applyTSResultsLayout(h, showResults)
% % Passt die Layout-Positionen im Time Series Tab an, wenn Ergebnis-Axes sichtbar
% if showResults
%     % Haupt-Axes etwas kleiner, Ergebnis-Axes unten einblenden
%     set(h.axesTimeSeries,   'Position',[0.01 0.230 0.97 0.605]);
%     set(h.axesTSFitResults, 'Position',[0.01 0.040 0.97 0.185]);
%     h.axesTSFitResults.Visible = 'on';
% else
%     set(h.axesTimeSeries,   'Position',[0.01 0.040 0.97 0.795]);
%     h.axesTSFitResults.Visible = 'off';
% end