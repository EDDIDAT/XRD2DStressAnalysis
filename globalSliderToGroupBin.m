function [m_grp, localBin] = globalSliderToGroupBin(sliderVal, dataY)
% Rechnet einen globalen Slider-Index in Alpha-Gruppe + lokalen Bin-Index um.
binsPerGroup = cellfun(@(y) size(y, 2), dataY);
cumBins      = [0, cumsum(binsPerGroup)];
m_grp = find(sliderVal > cumBins(1:end-1) & ...
             sliderVal <= cumBins(2:end), 1, 'first');
if isempty(m_grp)
    m_grp    = numel(dataY);
    localBin = binsPerGroup(end);
else
    localBin = sliderVal - cumBins(m_grp);
end
localBin = max(1, min(localBin, binsPerGroup(m_grp)));