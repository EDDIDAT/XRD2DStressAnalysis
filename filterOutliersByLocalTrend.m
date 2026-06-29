function [cleanData, outlierMask] = filterOutliersByLocalTrend(gamma, tth, tthErr, opts)

if nargin < 4, opts = struct(); end

windowSize   = getFieldOrDefault(opts, 'windowSize',   7);
sigmaThresh  = getFieldOrDefault(opts, 'sigmaThresh',  3.0);
minNeighbors = getFieldOrDefault(opts, 'minNeighbors', 3);
useErrWeight = getFieldOrDefault(opts, 'useErrWeight', true);

N           = numel(tth);
outlierMask = false(N, 1);
halfWin     = floor(windowSize / 2);

finiteMask = isfinite(tth) & isfinite(tthErr) & (tth ~= 0) & (tthErr > 0);

for iter = 1:2
    validMask = finiteMask & ~outlierMask;

    for i = 1:N
        if ~finiteMask(i), continue; end

        idxWin   = max(1, i-halfWin) : min(N, i+halfWin);
        idxWin   = idxWin(idxWin ~= i);
        validWin = idxWin(validMask(idxWin));

        if numel(validWin) < minNeighbors
            continue
        end

        tthNeighbors = tth(validWin);
        localMedian  = median(tthNeighbors);
        localMAD     = median(abs(tthNeighbors - localMedian));
        localSigma   = max(localMAD * 1.4826, 1e-6);

        deviation = abs(tth(i) - localMedian) / localSigma;

        if useErrWeight && isfinite(tthErr(i)) && tthErr(i) > 0
            isOutlier = (deviation > sigmaThresh) && ...
                        (abs(tth(i) - localMedian) > 5 * tthErr(i));
        else
            isOutlier = deviation > sigmaThresh;
        end

        outlierMask(i) = isOutlier;
    end
end

cleanData.gamma    = gamma(~outlierMask & finiteMask);
cleanData.tth      = tth(~outlierMask & finiteMask);
cleanData.tthErr   = tthErr(~outlierMask & finiteMask);
cleanData.nRemoved = sum(outlierMask & finiteMask);
end

function v = getFieldOrDefault(s, f, d)
if isfield(s, f), v = s.(f); else, v = d; end
end