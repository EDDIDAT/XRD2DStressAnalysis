function [peakXCell, peakYCell] = getPeakPositionsAndHeightsSeparate(results)
% getPeakPositionsAndHeightsSeparate
% Extrahiert Peakpositionen (peakX) und Peakhöhen (peakY) pro Spektrum
% und speichert sie in separaten Cell-Arrays.
%
% INPUT:
%   results : Struktur aus runFitting (M x nPeaks)
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
        if isfield(R,'success') && R.success
            if isfield(R,'xfit') && isfield(R,'yfit')
                [peakY, idxMax] = max(R.yfit);   % Peakhöhe
                peakX = R.xfit(idxMax);          % Peakposition
                xVals(end+1) = peakX;            %#ok<AGROW>
                yVals(end+1) = peakY;            %#ok<AGROW>
            elseif isfield(R,'peakX') && isfield(R,'peakY')
                xVals(end+1) = R.peakX;
                yVals(end+1) = R.peakY;
            end
        end
    end

    % Sortieren nach Peakposition
    [xSorted, sortIdx] = sort(xVals);
    ySorted = yVals(sortIdx);

    % In separate Cells speichern
    peakXCell{c} = xSorted(:);
    peakYCell{c} = ySorted(:);
end
end
