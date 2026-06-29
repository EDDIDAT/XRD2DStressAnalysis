function peakParamMatrices = getPeakParamsMatrix(results)
% getPeakParamsMatrix
% Erstellt für jeden Peak eine Matrix mit den Fitparametern
% Jede Zeile = ein Spektrum, jede Spalte = ein Parameter
%
% INPUT:
%   results : Struktur aus runFitting (M x nPeaks)
% OUTPUT:
%   peakParamMatrices : 1 x nPeaks Cell-Array
%       Jede Zelle: M x nParams Matrix mit params für alle Spektren

[M, nPeaks] = size(results);
peakParamMatrices = cell(1, nPeaks);

for p = 1:nPeaks
    % Anzahl Parameter bestimmen aus erstem erfolgreichen Fit
    nParams = [];
    for c = 1:M
        if isfield(results(c,p),'params') && ~isempty(results(c,p).params)
            nParams = numel(results(c,p).params);
            break;
        end
    end
    if isempty(nParams)
        warning('Kein erfolgreicher Fit für Peak %d gefunden.', p);
        continue;
    end

    % Matrix vorbereiten: M Zeilen, nParams Spalten
    paramMatrix = NaN(M, nParams);

    for c = 1:M
        R = results(c,p);
        if isfield(R,'params') && ~isempty(R.params)
            paramMatrix(c, :) = R.params(:).';
        end
    end

    peakParamMatrices{p} = paramMatrix;
end
end
