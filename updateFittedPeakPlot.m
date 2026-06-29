function h = updateFittedPeakPlot(h, peakIdx, binIdx)
% UPDATEFITTEDPEAKPLOT  Aktualisiert h.axesFittedPeaks.
%
%   peakIdx = Index in FitDataMod / dataXcorr (welcher Peak)
%   binIdx  = Index in dataXcorr/BinnedGamma  (welcher gamma-Bin)
%
% binIdx ist IMMER ein Index in dataXcorr (Länge = numel(BinnedGamma)),
% NICHT in FitDataMod. Das Mapping auf FitDataMod erfolgt intern über γ.

% ── Grundlegende Sicherheitsprüfungen ────────────────────────────────
if ~isfield(h,'dataXcorr') || isempty(h.dataXcorr), return; end
if ~isfield(h,'FitDataMod') || isempty(h.FitDataMod), return; end

% nAlpha  = numel(h.dataXcorr);
% safeIdx = max(1, min(peakIdx, nAlpha));
% 
% dc = h.dataXcorr{safeIdx};
% dr = h.dataYcorr{safeIdx};
% fr = h.fitresultexport{safeIdx};
% 
% if isempty(dc), return; end
% 
% % ── safeVal: binIdx auf dataXcorr-Bereich begrenzen ──────────────────
% % binIdx ist ein Index in dataXcorr (nicht FitDataMod)
% safeVal = max(1, min(binIdx, numel(dc)));
% 
% % Nächsten gültigen (nicht leeren) Bin suchen ab safeVal
% if isempty(dc{safeVal}) || isempty(dr{safeVal})
%     nextValid = [];
%     for ii = safeVal:numel(dc)
%         if ~isempty(dc{ii}) && ~isempty(dr{ii})
%             nextValid = ii; break;
%         end
%     end
%     if isempty(nextValid)
%         for ii = safeVal-1:-1:1
%             if ~isempty(dc{ii}) && ~isempty(dr{ii})
%                 nextValid = ii; break;
%             end
%         end
%     end
%     if isempty(nextValid)
%         cla(h.axesFittedPeaks);
%         return
%     end
%     safeVal = nextValid;
% end
% 
% x = dc{safeVal};
% y = dr{safeVal};
% if isempty(x) || isempty(y), return; end
% 
% % ── γ-Wert des aktuellen dataXcorr-Bins bestimmen ────────────────────
% if isfield(h,'BinnedGamma') && numel(h.BinnedGamma) >= safeIdx && ...
%    numel(h.BinnedGamma{safeIdx}) >= safeVal
%     gammaOfBin = h.BinnedGamma{safeIdx}(safeVal);
% else
%     gammaOfBin = NaN;
% end

nAlpha  = numel(h.dataXcorr);
safeIdx = max(1, min(peakIdx, nAlpha));

dc = h.dataXcorr{safeIdx};
dr = h.dataYcorr{safeIdx};
fr = h.fitresultexport{safeIdx};

if isempty(dc), return; end

% ── safeVal: binIdx auf dataXcorr-Bereich begrenzen ──────────────────
safeVal = max(1, min(binIdx, numel(dc)));

% Nächsten gültigen Bin suchen
if isempty(dc{safeVal}) || isempty(dr{safeVal})
    nextValid = [];
    for ii = safeVal:numel(dc)
        if ~isempty(dc{ii}) && ~isempty(dr{ii})
            nextValid = ii; break;
        end
    end
    if isempty(nextValid)
        for ii = safeVal-1:-1:1
            if ~isempty(dc{ii}) && ~isempty(dr{ii})
                nextValid = ii; break;
            end
        end
    end
    if isempty(nextValid)
        cla(h.axesFittedPeaks);
        return
    end
    safeVal = nextValid;
end

x = dc{safeVal};
y = dr{safeVal};
if isempty(x) || isempty(y), return; end

% ── Alpha-Gruppe für diesen Peak bestimmen ────────────────────────────
% BinnedGamma ist nach Alpha-Gruppen indiziert, NICHT nach Peaks
if isfield(h,'DEKdataMatchedPeaks') && ...
   size(h.DEKdataMatchedPeaks,1) >= peakIdx
    alphaVal_upfp = h.DEKdataMatchedPeaks(peakIdx, 7);
    if isfield(h,'uniqueAlpha')
        [~, alphaGrpIdx_upfp] = min(abs(h.uniqueAlpha - alphaVal_upfp));
    else
        alphaGrpIdx_upfp = 1;
    end
else
    alphaGrpIdx_upfp = 1;
end

% BinnedGamma mit korrektem Alpha-Gruppen-Index
nBinnedGamma = numel(h.BinnedGamma);
safeBGIdx    = max(1, min(alphaGrpIdx_upfp, nBinnedGamma));

% ── γ-Wert des aktuellen Bins bestimmen ──────────────────────────────
if isfield(h,'BinnedGamma') && ...
   numel(h.BinnedGamma{safeBGIdx}) >= safeVal
    gammaOfBin = h.BinnedGamma{safeBGIdx}(safeVal);
else
    gammaOfBin = NaN;
end

% ── Passende FitDataMod-Zeile über γ finden ──────────────────────────
% FitDataMod wurde komprimiert (Nullzeilen entfernt) →
% Länge kann kürzer sein als dataXcorr
fdmRow = NaN;
if isfinite(gammaOfBin) && numel(h.FitDataMod) >= peakIdx
    mat = h.FitDataMod{peakIdx};
    if ~isempty(mat)
        [~, fdmRow] = min(abs(mat(:,1) - gammaOfBin));
        % Prüfen ob der gefundene γ-Wert nah genug ist (max 1° Toleranz)
        if abs(mat(fdmRow,1) - gammaOfBin) > 1.0
            fdmRow = NaN;   % kein passender Eintrag gefunden
        end
    end
end

% ── kBins für ROI-Fenster ─────────────────────────────────────────────
k_bins = 12;
if isfield(h,'trackFitOpts') && isfield(h.trackFitOpts,'centroidKBins')
    k_bins = h.trackFitOpts.centroidKBins;
end

% ── Farben ────────────────────────────────────────────────────────────
COL_PV   = [0 0 1];   % blau  – fitPseudoVoigt
COL_CENT = [0 0 0];   % schwarz – fitCentroid

% ── Axes leeren ───────────────────────────────────────────────────────
cla(h.axesFittedPeaks);
hold(h.axesFittedPeaks, 'on');

% =========================================================
% 1. Rohdaten (schwarz)
% =========================================================
plot(h.axesFittedPeaks, x, y, 'k.', ...
    'MarkerSize',  8, ...
    'DisplayName', 'Data');

% =========================================================
% 2. fitPseudoVoigt-Kurve (blau)
% =========================================================
pvPlotted = false;

% Versuch 1: dataPVFitY (function handle)
if isfield(h,'dataPVFitY') && numel(h.dataPVFitY) >= safeIdx
    pvFY = h.dataPVFitY{safeIdx};
    pvSc = h.dataPVSuccess{safeIdx};
    if numel(pvFY) >= safeVal && numel(pvSc) >= safeVal && ...
       ~isempty(pvFY{safeVal}) && pvSc(safeVal) && ...
       isa(pvFY{safeVal}, 'function_handle')
        yPV = pvFY{safeVal}(x);
        if any(isfinite(yPV))
            plot(h.axesFittedPeaks, x, yPV, '-', ...
                'Color', COL_PV, 'LineWidth', 1.4, ...
                'DisplayName', 'fitPseudoVoigt');
            pvPlotted = true;
        end
    end
end

% Versuch 2: fitresultexport (Parameter-Vektor)
if ~pvPlotted && ~isempty(fr) && numel(fr) >= safeVal && ~isempty(fr{safeVal})
    params = fr{safeVal};
    if isnumeric(params) && mod(numel(params),4) == 0
        yPV = multiPseudoVoigt(params, x);
        if any(isfinite(yPV))
            plot(h.axesFittedPeaks, x, yPV, '-', ...
                'Color', COL_PV, 'LineWidth', 1.4, ...
                'DisplayName', 'fitPseudoVoigt');
            pvPlotted = true;
        end
    end
end

% =========================================================
% 3. fitPseudoVoigt x0-Linie (blau gepunktet)
%    Spalte 9 aus FitDataMod (über fdmRow)
% =========================================================
if isfinite(fdmRow) && numel(h.FitDataMod) >= peakIdx
    mat = h.FitDataMod{peakIdx};
    if size(mat,2) >= 9 && isfinite(mat(fdmRow,9))
        xline(h.axesFittedPeaks, mat(fdmRow,9), ':', ...
            'Color',       COL_PV, ...
            'LineWidth',   1.2, ...
            'DisplayName', 'x0 fitPseudoVoigt');
    end
end

% =========================================================
% 4+6. fitCentroid – x0-Linie + ROI-Kreise
% =========================================================
if isfield(h,'datacentFitParams') && numel(h.datacentFitParams) >= safeIdx
    cP = h.datacentFitParams{safeIdx};
    if numel(cP) >= safeVal && ~isempty(cP{safeVal}) && ...
       isfield(cP{safeVal},'x0') && isfinite(cP{safeVal}.x0)

        x0_cent = cP{safeVal}.x0;

        % x0-Linie (schwarz gestrichelt)
        xline(h.axesFittedPeaks, x0_cent, '--', ...
            'Color',       COL_CENT, ...
            'LineWidth',   1.4, ...
            'DisplayName', 'x0 fitCentroid');

        % ROI-Kreise (weiße Füllung)
        [~, iC] = min(abs(x - x0_cent));
        lo = max(1, iC - k_bins);
        hi = min(numel(x), iC + k_bins);
        plot(h.axesFittedPeaks, x(lo:hi), y(lo:hi), 'o', ...
            'Color',           COL_CENT, ...
            'MarkerFaceColor', 'w', ...
            'MarkerSize',      6, ...
            'DisplayName',     'fitCentroid ROI');
    end
end

% =========================================================
% 7. Best-Estimate-Linie (schwarz, aus FitDataMod Sp. 2)
%    Verwendet fdmRow für korrekten FitDataMod-Zugriff
% =========================================================
if isfinite(fdmRow) && numel(h.FitDataMod) >= peakIdx
    mat = h.FitDataMod{peakIdx};
    if isfinite(mat(fdmRow,2))
        xline(h.axesFittedPeaks, mat(fdmRow,2), 'k-', ...
            'LineWidth',   1.0, ...
            'DisplayName', 'Best estimate');
    end
end

% ── Achsenbeschriftung + Legende ──────────────────────────────────────
xlabel(h.axesFittedPeaks, ['2',char(952),' [°]'], 'FontSize', 12);
ylabel(h.axesFittedPeaks, 'Intensity [a.u.]',     'FontSize', 12);

% % γ-Wert als Titel anzeigen
% if isfinite(gammaOfBin)
%     title(h.axesFittedPeaks, sprintf('\\gamma = %.2f°  (Bin %d/%d)', ...
%         gammaOfBin, safeVal, numel(dc)), 'FontSize', 10);
% end
if isfinite(gammaOfBin)
    % Relativen Bin-Index berechnen:
    % Position von gammaOfBin unter den gültigen FitDataMod-Zeilen
    pv_t = h.FitDataMod{peakIdx};
    [~, ~, idxFin_t] = getPlausibleCol(pv_t);
    validRows_t = find(idxFin_t);
    nValid_t    = numel(validRows_t);

    % gammaOfBin (+90° verschoben) gegen pvGamma-Werte suchen
    pvGamma_t   = pv_t(validRows_t, 1);
    [~, relPos] = min(abs(pvGamma_t - gammaOfBin));

    title(h.axesFittedPeaks, sprintf('\\gamma = %.2f°  (Bin %d/%d)', ...
        gammaOfBin, relPos, nValid_t), 'FontSize', 10);
end

box(h.axesFittedPeaks,  'on');
grid(h.axesFittedPeaks, 'on');
legend(h.axesFittedPeaks, 'Location', 'best', 'FontSize', 8);
hold(h.axesFittedPeaks, 'off');

end