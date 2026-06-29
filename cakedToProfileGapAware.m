function I_1D = cakedToProfileGapAware(result, minValidFraction)
if nargin < 2, minValidFraction = 0; end

nRad = size(result.sum_signal, 2);
I_1D = NaN(1, nRad);

for col = 1:nRad
    countCol  = result.count(:, col);
    signalCol = result.sum_signal(:, col);

    % Gültig: count > 0 UND sum_signal nicht exakt 0 (echte Lücken-Randpixel ausschließen)
    plausible = (countCol > 0) & (signalCol > 0);

    if any(plausible)
        I_1D(col) = mean(signalCol(plausible));
    end
end

if minValidFraction > 0
    nValidPerCol = sum(result.count > 0 & result.sum_signal > 0, 1);
    maxValidCount = max(nValidPerCol);
    I_1D(nValidPerCol < minValidFraction * maxValidCount) = NaN;
end
end