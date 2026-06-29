function h = updateFitSumOverlay(h, binIdx, idxPeaks)

delete(findobj(h.axesPlotIntensityData, 'Tag', 'fitsumoverlay'));
if ~isfield(h,'fitresultexport') || isempty(h.fitresultexport), return; end

if nargin < 3 || isempty(idxPeaks)
    idxPeaks = 1:size(h.FitDataMod, 1);
end

[m_plot, localBin] = globalSliderToGroupBin(binIdx, h.dataY);

if ~isfield(h,'dataXcorrBg') || numel(h.dataXcorrBg) < m_plot
    return
end

nBinsAvail = numel(h.dataXcorrBg{m_plot});
localBin   = max(1, min(localBin, nBinsAvail));

if isfield(h,'BinnedGamma') && numel(h.BinnedGamma) >= m_plot && ...
   localBin <= numel(h.BinnedGamma{m_plot})
    gammaCurrent = h.BinnedGamma{m_plot}(localBin);
else
    gammaCurrent = NaN;
end

if isnan(gammaCurrent), return; end

nPeaks     = numel(idxPeaks);
compColors = lines(size(h.FitDataMod, 1));

if numel(h.dataXcorrBg{m_plot}) < localBin || ...
   isempty(h.dataXcorrBg{m_plot}{localBin})
    return
end
xSpecCorr = h.dataXcorrBg{m_plot}{localBin};
ySpecCorr = h.dataYcorrBg{m_plot}{localBin};

hold(h.axesPlotIntensityData, 'on');

for pkLoop = 1:nPeaks
    pk = idxPeaks(pkLoop);

    if ~isfield(h,'FitDataMod') || numel(h.FitDataMod) < pk
        continue
    end
    mat      = h.FitDataMod{pk};
    gammaFit = mat(:, 1);

    if numel(gammaFit) >= 2
        stepSize = median(abs(diff(sort(gammaFit))));
        gammaTol = max(stepSize * 1.5, 3.0);
    else
        gammaTol = 3.0;
    end

    [minDist, fdmRow] = min(abs(gammaFit - gammaCurrent));
    if minDist > gammaTol, continue; end

    % gammaTarget = gammaFit(fdmRow);
    % 
    % if isfield(h,'DEKdataMatchedPeaks') && ...
    %    size(h.DEKdataMatchedPeaks,1) >= pk
    %     alphaVal_uf = h.DEKdataMatchedPeaks(pk, 7);
    %     if isfield(h,'uniqueAlpha')
    %         [~, alphaGrpIdx_uf] = min(abs(h.uniqueAlpha - alphaVal_uf));
    %     else
    %         alphaGrpIdx_uf = 1;
    %     end
    % else
    %     alphaGrpIdx_uf = 1;
    % end
    % 
    % bg = h.BinnedGamma{alphaGrpIdx_uf};
    % [~, bgIdx] = min(abs(bg - gammaTarget));

    bgIdx = fdmRow;

    if ~isfield(h,'dataPVFitY') || numel(h.dataPVFitY) < pk || ...
       isempty(h.dataPVFitY{pk})
        continue
    end

    pvFY = h.dataPVFitY{pk};
    if bgIdx > numel(pvFY) || isempty(pvFY{bgIdx}) || ...
       ~isa(pvFY{bgIdx}, 'function_handle')
        continue
    end

    if isfield(h,'BgRegions') && numel(h.BgRegions) >= pk && ...
       ~isempty(h.BgRegions{pk})
        xLeft  = h.BgRegions{pk}(1);
        xRight = h.BgRegions{pk}(2);
    else
        xLeft  = min(xSpecCorr);
        xRight = max(xSpecCorr);
    end

    idxRange = xSpecCorr >= xLeft & xSpecCorr <= xRight;
    if sum(idxRange) < 3, continue; end

    xRange = xSpecCorr(idxRange);
    yFit   = pvFY{bgIdx}(xRange);

    if isempty(yFit) || ~any(isfinite(yFit) & yFit > 0), continue; end

    % Lokale SNR-Prüfung
    ySpecLocal   = ySpecCorr(idxRange);
    specPeak     = max(ySpecLocal);
    specBaseline = min(ySpecLocal);
    snrLocal     = (specPeak - specBaseline) / max(specBaseline, 1);
    fitMax       = max(yFit);

    if snrLocal < 0.5 || fitMax < 0.05 * specPeak
        continue
    end

    plot(h.axesPlotIntensityData, xRange, yFit, '-', ...
        'Color',     compColors(pk,:), ...
        'LineWidth', 2.0, ...
        'Tag',       'fitsumoverlay');
end

h.axesPlotIntensityData.YLimMode = 'auto';
end