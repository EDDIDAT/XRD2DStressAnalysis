function [peakXCell, peakYCell] = getPeakXYSeparate(results)
% getPeakXYSeparate
% Extrahiert peakX und peakY aus results-Struktur
% Speichert für jedes Spektrum in separate Cell-Arrays
%
% INPUT:
%   results : Struktur (M x nPeaks) mit Feldern:
%             startValue, peakX, peakY, index
% OUTPUT:
%   peakXCell : M x 1 Cell, jede Zelle = sortierte Peakpositionen
%   peakYCell : M x 1 Cell, jede Zelle = Peakhöhen passend zu peakX

[M, nPeaks] = size(results);
peakXCell = cell(M,1);
peakYCell = cell(M,1);

for c = 1:M
    xVals = [];
    yVals = [];

    for p = 1:nPeaks
        R = results(c,p);
        if ~isnan(R.peakX) && ~isnan(R.peakY)
            xVals(end+1) = R.peakX; %#ok<AGROW>
            yVals(end+1) = R.peakY; %#ok<AGROW>
        end
    end

    % Sortieren nach Peakposition
    [xSorted, sortIdx] = sort(xVals);
    ySorted = yVals(sortIdx);

    peakXCell{c} = xSorted(:);
    peakYCell{c} = ySorted(:);
end
end
